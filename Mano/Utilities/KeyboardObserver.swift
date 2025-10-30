//
//  KeyboardObserver.swift
//  Mano
//
//  Keyboard height detection for input positioning
//

import Foundation
import Combine
import UIKit

#if os(iOS)
extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }

        return Publishers.Merge(willShow, willHide)
            .eraseToAnyPublisher()
    }
}
#else
// Fallback for non-iOS platforms
extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        Just(0).eraseToAnyPublisher()
    }
}
#endif
