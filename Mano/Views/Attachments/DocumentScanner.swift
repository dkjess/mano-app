//
//  DocumentScanner.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI
import UIKit
import VisionKit
import Vision

// MARK: - Document Scanner View

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScanComplete: ([UIImage]) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var scannedImages: [UIImage] = []
            
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                scannedImages.append(image)
            }
            
            parent.onScanComplete(scannedImages)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }
    }
}

// MARK: - OCR Text Extraction

class TextExtractor {
    static func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        do {
            try requestHandler.perform([request])
            
            guard let observations = request.results else { return nil }
            
            let recognizedStrings = observations.compactMap { observation in
                return observation.topCandidates(1).first?.string
            }
            
            return recognizedStrings.joined(separator: "\n")
        } catch {
            print("Error extracting text: \(error)")
            return nil
        }
    }
    
    static func extractTextFromMultipleImages(_ images: [UIImage]) async -> [String] {
        var results: [String] = []
        
        for image in images {
            if let text = await extractText(from: image) {
                results.append(text)
            } else {
                results.append("")
            }
        }
        
        return results
    }
}

// MARK: - PDF Creator

class PDFCreator {
    static func createPDF(from images: [UIImage], title: String = "Scanned Document") -> Data? {
        let pdfMetadata = [
            kCGPDFContextCreator: "Mano",
            kCGPDFContextTitle: title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            for image in images {
                context.beginPage()
                
                // Calculate aspect ratio and fit image to page
                let imageAspectRatio = image.size.width / image.size.height
                let pageAspectRatio = pageRect.width / pageRect.height
                
                let drawRect: CGRect
                if imageAspectRatio > pageAspectRatio {
                    // Image is wider, fit to width
                    let height = pageRect.width / imageAspectRatio
                    let y = (pageRect.height - height) / 2
                    drawRect = CGRect(x: 0, y: y, width: pageRect.width, height: height)
                } else {
                    // Image is taller, fit to height
                    let width = pageRect.height * imageAspectRatio
                    let x = (pageRect.width - width) / 2
                    drawRect = CGRect(x: x, y: 0, width: width, height: pageRect.height)
                }
                
                image.draw(in: drawRect)
            }
        }
        
        return pdfData
    }
}

// MARK: - Document Scanner Integration View

struct DocumentScannerIntegration: View {
    let onScanComplete: (Attachment) -> Void
    let onCancel: () -> Void
    
    @State private var showingScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var isProcessing = false
    @State private var extractedTexts: [String] = []
    
    var body: some View {
        VStack {
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Processing scanned documents...")
                        .font(.headline)
                    
                    Text("Extracting text and creating PDF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            } else {
                Button("Start Document Scan") {
                    showingScanner = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView(
                onScanComplete: { images in
                    scannedImages = images
                    showingScanner = false
                    processScannedImages()
                },
                onCancel: {
                    showingScanner = false
                    onCancel()
                }
            )
        }
    }
    
    private func processScannedImages() {
        isProcessing = true
        
        Task {
            // Extract text from all images
            let texts = await TextExtractor.extractTextFromMultipleImages(scannedImages)
            
            // Create PDF from images
            guard let pdfData = PDFCreator.createPDF(from: scannedImages, title: "Scan_\(Date().timeIntervalSince1970)") else {
                await MainActor.run {
                    isProcessing = false
                    onCancel()
                }
                return
            }
            
            // Create attachment
            await MainActor.run {
                var attachment = Attachment(
                    type: .scan,
                    originalName: "Scan_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)).pdf",
                    fileSize: Int64(pdfData.count),
                    mimeType: "application/pdf",
                    createdAt: Date()
                )
                
                attachment.data = pdfData
                attachment.thumbnail = scannedImages.first?.preparingThumbnail(of: CGSize(width: 120, height: 120))
                attachment.ocrText = texts.joined(separator: "\n\n--- Page Break ---\n\n")
                
                var metadata = AttachmentMetadata()
                metadata.pageCount = scannedImages.count
                metadata.title = "Scanned Document"
                attachment.metadata = metadata
                
                isProcessing = false
                onScanComplete(attachment)
            }
        }
    }
}