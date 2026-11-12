//
//  InstructionsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/6/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

final class InstructionsViewController: UIViewController
{
    var completionHandler: (() -> Void)?
    
    var showsBottomButton: Bool = false
    
    @IBOutlet private var contentStackView: UIStackView!
    @IBOutlet private var dismissButton: UIButton!
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    #endif
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("How it Works", comment: "")
        self.navigationItem.title = NSLocalizedString("How it Works", comment: "")
        self.localizeViewHierarchy(self.view)
        
        if UIScreen.main.isExtraCompactHeight
        {
            self.contentStackView.layoutMargins.top = 0
            self.contentStackView.layoutMargins.bottom = self.contentStackView.layoutMargins.left
        }
        
        self.dismissButton.clipsToBounds = true
        self.dismissButton.layer.cornerRadius = 16
        
        if self.showsBottomButton
        {
            #if !os(tvOS)
            self.navigationItem.hidesBackButton = true
            #endif
        }
        else
        {
            self.dismissButton.isHidden = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.title = NSLocalizedString("How it Works", comment: "")
        self.navigationItem.title = NSLocalizedString("How it Works", comment: "")
        self.localizeViewHierarchy(self.view)
    }
}

private extension InstructionsViewController
{
    func localizeViewHierarchy(_ view: UIView)
    {
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            label.text = NSLocalizedString(text, comment: "")
        } else if let button = view as? UIButton {
            if let title = button.title(for: .normal), !title.isEmpty {
                button.setTitle(NSLocalizedString(title, comment: ""), for: .normal)
            }
            return
        }
        for subview in view.subviews {
            localizeViewHierarchy(subview)
        }
    }
    
    @IBAction func dismiss()
    {
        self.completionHandler?()
    }
}
