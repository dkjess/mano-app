//
//  Attachment.swift
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

// MARK: - Attachment Types

enum AttachmentType: String, CaseIterable, Codable {
    case image
    case video
    case audio
    case pdf
    case document
    case voice
    case screenshot
    case scan
    case url
    case contact
    case calendar
    
    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .pdf: return "doc.fill"
        case .document: return "doc.text"
        case .voice: return "mic.fill"
        case .screenshot: return "camera.viewfinder"
        case .scan: return "scanner"
        case .url: return "link"
        case .contact: return "person.crop.rectangle"
        case .calendar: return "calendar"
        }
    }
    
    var color: Color {
        switch self {
        case .image: return .green
        case .video: return .blue
        case .audio: return .purple
        case .pdf: return .red
        case .document: return .blue
        case .voice: return .orange
        case .screenshot: return .cyan
        case .scan: return .indigo
        case .url: return .blue
        case .contact: return .pink
        case .calendar: return .yellow
        }
    }
}

// MARK: - Attachment Model

struct Attachment: Identifiable, Equatable, Transferable {
    let id = UUID()
    var type: AttachmentType
    let originalName: String
    let fileSize: Int64
    let mimeType: String
    let createdAt: Date
    
    // Content variants (not persisted)
    #if canImport(UIKit)
    var image: UIImage?
    var thumbnail: UIImage?
    #endif
    var url: URL?
    var data: Data?
    var metadata: AttachmentMetadata?
    
    // Processing states
    var isUploading: Bool = false
    var uploadProgress: Double = 0.0
    var uploadError: String?
    var isProcessing: Bool = false
    var ocrText: String?
    
    static func == (lhs: Attachment, rhs: Attachment) -> Bool {
        lhs.id == rhs.id
    }
    
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.id.uuidString)
    }
}

// MARK: - Attachment Metadata

struct AttachmentMetadata: Codable {
    var dimensions: CGSize?
    var duration: TimeInterval?
    var pageCount: Int?
    var author: String?
    var title: String?
    var subject: String?
    var keywords: [String]?
    var colorProfile: String?
    var latitude: Double?
    var longitude: Double?
    var cameraSettings: CameraSettings?
    
    struct CameraSettings: Codable {
        let make: String?
        let model: String?
        let fNumber: Double?
        let exposureTime: String?
        let isoSpeed: Int?
        let focalLength: Double?
    }
}

// MARK: - URL Extensions

extension URL {
    var mimeType: String {
        if let utType = UTType(filenameExtension: pathExtension),
           let mimeType = utType.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }
}