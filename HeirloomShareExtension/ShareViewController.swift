//
//  ShareViewController.swift
//  HeirloomShareExtension
//
//  Updated to use SwiftUI ShareExtensionView
//

import UIKit
import SwiftUI

/// Share Extension view controller that hosts SwiftUI view
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create SwiftUI view
        let shareView = ShareExtensionView(
            extensionContext: extensionContext,
            onComplete: { [weak self] success in
                self?.completeExtension(success: success)
            }
        )

        // Wrap in hosting controller
        let hostingController = UIHostingController(rootView: shareView)

        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        // Set up constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func completeExtension(success: Bool) {
        if success {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        } else {
            let error = NSError(
                domain: "com.matthanson.heirloom.shareextension",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User cancelled or error occurred"]
            )
            extensionContext?.cancelRequest(withError: error)
        }
    }
}
