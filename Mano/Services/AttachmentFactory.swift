//
//  AttachmentFactory.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import AVFoundation
import CoreLocation

// MARK: - Attachment Factory

class AttachmentFactory {
    static func createAttachment(from image: UIImage, type: AttachmentType = .image) -> Attachment {
        let imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        var attachment = Attachment(
            type: type,
            originalName: generateFileName(for: type),
            fileSize: Int64(imageData.count),
            mimeType: "image/jpeg",
            createdAt: Date()
        )
        attachment.image = image
        attachment.data = imageData
        attachment.thumbnail = generateThumbnail(from: image)
        attachment.metadata = extractMetadata(from: image)
        return attachment
    }
    
    static func createAttachment(from url: URL) async -> Attachment? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let type = determineType(from: url)
            
            var attachment = Attachment(
                type: type,
                originalName: url.lastPathComponent,
                fileSize: Int64(data.count),
                mimeType: url.mimeType,
                createdAt: Date()
            )
            
            attachment.url = url
            attachment.data = data
            attachment.thumbnail = await generateThumbnail(from: data, type: type, url: url)
            attachment.metadata = await extractMetadata(from: url, data: data, type: type)
            
            return attachment
        } catch {
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private static func generateFileName(for type: AttachmentType) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        switch type {
        case .image, .screenshot: return "Image_\(timestamp).jpg"
        case .video: return "Video_\(timestamp).mp4"
        case .audio, .voice: return "Audio_\(timestamp).m4a"
        case .pdf: return "Document_\(timestamp).pdf"
        case .scan: return "Scan_\(timestamp).pdf"
        default: return "File_\(timestamp)"
        }
    }
    
    private static func determineType(from url: URL) -> AttachmentType {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg", "png", "gif", "webp", "heic":
            return .image
        case "mp4", "mov", "avi", "mkv":
            return .video
        case "mp3", "m4a", "wav", "aac":
            return .audio
        case "pdf":
            return .pdf
        case "doc", "docx", "txt", "rtf":
            return .document
        default:
            return .document
        }
    }
    
    private static func generateThumbnail(from image: UIImage) -> UIImage? {
        let size = CGSize(width: 120, height: 120)
        return image.preparingThumbnail(of: size)
    }
    
    private static func generateThumbnail(from data: Data, type: AttachmentType, url: URL) async -> UIImage? {
        switch type {
        case .image:
            guard let image = UIImage(data: data) else { return nil }
            return generateThumbnail(from: image)
            
        case .video:
            return await generateVideoThumbnail(from: url)
            
        case .pdf:
            return generatePDFThumbnail(from: data)
            
        default:
            return nil
        }
    }
    
    private static func generateVideoThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
    
    private static func generatePDFThumbnail(from data: Data) -> UIImage? {
        guard let document = PDFDocument(data: data),
              let page = document.page(at: 0) else { return nil }
        
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
    
    private static func extractMetadata(from image: UIImage) -> AttachmentMetadata {
        return AttachmentMetadata(
            dimensions: image.size,
            colorProfile: "sRGB" // Simplified
        )
    }
    
    private static func extractMetadata(from url: URL, data: Data, type: AttachmentType) async -> AttachmentMetadata? {
        switch type {
        case .image:
            guard let image = UIImage(data: data) else { return nil }
            return extractMetadata(from: image)
            
        case .video:
            return await extractVideoMetadata(from: url)
            
        case .pdf:
            return extractPDFMetadata(from: data)
            
        default:
            return AttachmentMetadata()
        }
    }
    
    private static func extractVideoMetadata(from url: URL) async -> AttachmentMetadata {
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        
        var metadata = AttachmentMetadata()
        metadata.duration = duration?.seconds
        
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            let size = try? await track.load(.naturalSize)
            metadata.dimensions = size
        }
        
        return metadata
    }
    
    private static func extractPDFMetadata(from data: Data) -> AttachmentMetadata? {
        guard let document = PDFDocument(data: data) else { return nil }
        
        var metadata = AttachmentMetadata()
        metadata.pageCount = document.pageCount
        metadata.title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        metadata.author = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String
        metadata.subject = document.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String
        
        return metadata
    }
}