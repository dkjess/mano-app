//
//  AttachmentPreviewSystem.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Enhanced Attachment Preview Container

struct AttachmentPreviewContainer: View {
    @Binding var attachments: [Attachment]
    @State private var selectedAttachment: Attachment?
    @State private var showingQuickLook = false
    @State private var draggedAttachment: Attachment?
    
    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
    ]
    
    var body: some View {
        if !attachments.isEmpty {
            VStack(spacing: 0) {
                Divider()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    if attachments.count <= 3 {
                        // Horizontal layout for few items
                        HStack(spacing: 12) {
                            ForEach(attachments) { attachment in
                                EnhancedAttachmentPreview(
                                    attachment: attachment,
                                    onRemove: { removeAttachment(attachment) },
                                    onTap: { selectedAttachment = attachment }
                                )
                                .draggable(attachment) {
                                    AttachmentDragPreview(attachment: attachment)
                                }
                                .dropDestination(for: Attachment.self) { droppedAttachments, location in
                                    return handleDrop(droppedAttachments, target: attachment)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    } else {
                        // Grid layout for many items
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(attachments) { attachment in
                                EnhancedAttachmentPreview(
                                    attachment: attachment,
                                    onRemove: { removeAttachment(attachment) },
                                    onTap: { selectedAttachment = attachment },
                                    size: .compact
                                )
                                .draggable(attachment) {
                                    AttachmentDragPreview(attachment: attachment)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .frame(maxHeight: attachments.count > 3 ? 200 : 100)
                .background(.regularMaterial)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: attachments.count)
                
                // Attachment info bar
                AttachmentInfoBar(attachments: attachments)
                
                Divider()
            }
            .sheet(item: $selectedAttachment) { attachment in
                AttachmentDetailView(attachment: attachment)
            }
        }
    }
    
    private func removeAttachment(_ attachment: Attachment) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            attachments.removeAll { $0.id == attachment.id }
        }
        
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
    }
    
    private func handleDrop(_ droppedAttachments: [Attachment], target: Attachment) -> Bool {
        guard let draggedAttachment = droppedAttachments.first,
              let draggedIndex = attachments.firstIndex(where: { $0.id == draggedAttachment.id }),
              let targetIndex = attachments.firstIndex(where: { $0.id == target.id }) else {
            return false
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let removed = attachments.remove(at: draggedIndex)
            attachments.insert(removed, at: targetIndex)
        }
        
        // Haptic feedback for reorder
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        return true
    }
}

// MARK: - Enhanced Attachment Preview

struct EnhancedAttachmentPreview: View {
    let attachment: Attachment
    let onRemove: () -> Void
    let onTap: () -> Void
    let size: PreviewSize
    
    @State private var isPressed = false
    @State private var showingError = false
    
    enum PreviewSize {
        case normal, compact
        
        var dimensions: CGFloat {
            switch self {
            case .normal: return 80
            case .compact: return 60
            }
        }
    }
    
    init(attachment: Attachment, onRemove: @escaping () -> Void, onTap: @escaping () -> Void, size: PreviewSize = .normal) {
        self.attachment = attachment
        self.onRemove = onRemove
        self.onTap = onTap
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Main preview content
            Group {
                #if os(iOS)
                if let thumbnail = attachment.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.dimensions, height: size.dimensions)
                        .clipped()
                } else if let image = attachment.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.dimensions, height: size.dimensions)
                        .clipped()
                } else {
                    // Fallback icon view
                    AttachmentIconView(attachment: attachment, size: size.dimensions)
                }
                #else
                // macOS - no thumbnail support, show icon
                AttachmentIconView(attachment: attachment, size: size.dimensions)
                #endif
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            )
            
            // Overlay indicators
            VStack {
                HStack {
                    Spacer()
                    
                    // Type indicator for non-images
                    if attachment.type != .image {
                        Image(systemName: attachment.type.icon)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(attachment.type.color))
                            .shadow(radius: 2)
                    }
                }
                
                Spacer()
                
                // Progress/status indicators
                if attachment.isUploading {
                    ProgressView(value: attachment.uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.horizontal, 4)
                } else if attachment.isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Processing")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                } else if let _ = attachment.uploadError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(4)
                        .background(Circle().fill(.white))
                        .shadow(radius: 2)
                }
            }
            .padding(4)
            
            // Remove button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .background(Circle().fill(.black.opacity(0.6)))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .offset(x: 6, y: -6)
                }
                Spacer()
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0.1,
            perform: { },
            onPressingChanged: { pressing in
                isPressed = pressing
                if pressing {
                    #if os(iOS)
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    #endif
                }
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .alert("Upload Error", isPresented: $showingError) {
            Button("Retry") {
                // TODO: Implement retry logic
            }
            Button("Remove") {
                onRemove()
            }
        } message: {
            Text(attachment.uploadError ?? "Unknown error occurred")
        }
    }
}

// MARK: - Attachment Icon View

struct AttachmentIconView: View {
    let attachment: Attachment
    let size: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: attachment.type.icon)
                .font(.system(size: size * 0.3))
                .foregroundStyle(attachment.type.color)
            
            if size > 60 {
                Text(fileExtension)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .background(.ultraThinMaterial)
    }
    
    private var fileExtension: String {
        if let url = attachment.url {
            return url.pathExtension.uppercased()
        }
        return attachment.type.rawValue.uppercased()
    }
}

// MARK: - Attachment Info Bar

struct AttachmentInfoBar: View {
    let attachments: [Attachment]
    
    private var totalSize: Int64 {
        attachments.reduce(0) { $0 + $1.fileSize }
    }
    
    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "paperclip")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(attachments.count) attachment\(attachments.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(sizeString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            
            if attachments.contains(where: { $0.isUploading }) {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Drag Preview

struct AttachmentDragPreview: View {
    let attachment: Attachment
    
    var body: some View {
        VStack(spacing: 4) {
            #if os(iOS)
            if let thumbnail = attachment.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                AttachmentIconView(attachment: attachment, size: 60)
            }
            #else
            // macOS - no thumbnail support, show icon
            AttachmentIconView(attachment: attachment, size: 60)
            #endif
            
            Text(attachment.originalName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }
}

// MARK: - Attachment Detail View

struct AttachmentDetailView: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Large preview
                    Group {
                        #if os(iOS)
                        if let image = attachment.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                        } else {
                            AttachmentIconView(attachment: attachment, size: 120)
                        }
                        #else
                        // macOS - no UIImage support, show icon
                        AttachmentIconView(attachment: attachment, size: 120)
                        #endif
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
                    
                    // Metadata
                    AttachmentMetadataView(attachment: attachment)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(attachment.originalName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Attachment Metadata View

struct AttachmentMetadataView: View {
    let attachment: Attachment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: attachment.type.icon)
                    .foregroundStyle(attachment.type.color)
                Text(attachment.type.rawValue.capitalized)
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                MetadataRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: attachment.fileSize, countStyle: .file))
                MetadataRow(label: "Type", value: attachment.mimeType)
                MetadataRow(label: "Created", value: DateFormatter.localizedString(from: attachment.createdAt, dateStyle: .medium, timeStyle: .short))
                
                if let metadata = attachment.metadata {
                    if let dimensions = metadata.dimensions {
                        MetadataRow(label: "Dimensions", value: "\(Int(dimensions.width)) × \(Int(dimensions.height))")
                    }
                    
                    if let duration = metadata.duration {
                        MetadataRow(label: "Duration", value: formatDuration(duration))
                    }
                    
                    if let pageCount = metadata.pageCount {
                        MetadataRow(label: "Pages", value: "\(pageCount)")
                    }
                    
                    if let author = metadata.author {
                        MetadataRow(label: "Author", value: author)
                    }
                }
                
                if let ocrText = attachment.ocrText, !ocrText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extracted Text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(ocrText)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(8)
                            .background(.quaternary.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "--"
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
}