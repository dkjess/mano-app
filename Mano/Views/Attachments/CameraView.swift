//
//  CameraView.swift
//  Mano
//
//  Created by Claude on 06/09/2025.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        controller.sourceType = .camera
        controller.allowsEditing = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.onImageCaptured(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.onImageCaptured(originalImage)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - Camera Availability Check

extension UIImagePickerController {
    static var isCameraAvailable: Bool {
        return isSourceTypeAvailable(.camera)
    }
    
    static var isFrontCameraAvailable: Bool {
        return isCameraDeviceAvailable(.front)
    }
    
    static var isRearCameraAvailable: Bool {
        return isCameraDeviceAvailable(.rear)
    }
}

#endif // canImport(UIKit)