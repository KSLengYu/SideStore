//
//  AuthenticationViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/5/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

import SideSign

final class AuthenticationViewController: UIViewController
{
    var authenticationHandler: ((String, String, @escaping (Result<(ALTAccount, ALTAppleAPISession), Error>) -> Void) -> Void)?
    var completionHandler: (((ALTAccount, ALTAppleAPISession, String)?) -> Void)?
    
    private weak var toastView: ToastView?
    
    @IBOutlet private var appleIDTextField: UITextField!
    @IBOutlet private var passwordTextField: UITextField!
    @IBOutlet private var signInButton: UIButton!
    
    @IBOutlet private var appleIDBackgroundView: UIView!
    @IBOutlet private var passwordBackgroundView: UIView!
    
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var contentStackView: UIStackView!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // fetch anisette servers asap when loading Auth Screen (if list is empty)
        Task {
            if await AnisetteServersManager.shared.getActiveServerURLs().isEmpty {
                let sourceURL = UserDefaults.standard.menuAnisetteList
                do {
                    _ = try await AnisetteServersManager.shared.syncWithRemote(sourceURLString: sourceURL, forceRemote: true)
                    debugLog("AuthenticationViewController: Server list refresh request completed for sourceURL: \(sourceURL)")
                } catch {
                    debugLog("AuthenticationViewController: Server list refresh request Failed for sourceURL: \(sourceURL) Error: \(error)")
                }
            }
        }
        
        self.signInButton.activityIndicatorView.style = .medium
        self.signInButton.activityIndicatorView.color = .white
        
        for view in [self.appleIDBackgroundView!, self.passwordBackgroundView!, self.signInButton!]
        {
            #if !os(tvOS)
            view.clipsToBounds = true
            #endif
            view.layer.cornerRadius = 16
        }

        self.appleIDTextField.autocapitalizationType = .none
        self.appleIDTextField.autocorrectionType = .no
        self.appleIDTextField.spellCheckingType = .no
        self.appleIDTextField.smartQuotesType = .no
        self.appleIDTextField.smartDashesType = .no
        self.appleIDTextField.smartInsertDeleteType = .no
        self.appleIDTextField.keyboardType = .emailAddress
        self.appleIDTextField.textContentType = .username

        self.passwordTextField.autocapitalizationType = .none
        self.passwordTextField.autocorrectionType = .no
        self.passwordTextField.spellCheckingType = .no
        self.passwordTextField.smartQuotesType = .no
        self.passwordTextField.smartDashesType = .no
        self.passwordTextField.smartInsertDeleteType = .no
        self.passwordTextField.textContentType = .password

        #if os(tvOS)
        self.appleIDBackgroundView.backgroundColor = .clear
        self.passwordBackgroundView.backgroundColor = .clear
        self.appleIDBackgroundView.isUserInteractionEnabled = true
        self.passwordBackgroundView.isUserInteractionEnabled = true
        self.appleIDTextField.borderStyle = .roundedRect
        self.passwordTextField.borderStyle = .roundedRect
        #endif

        if UIScreen.main.isExtraCompactHeight
        {
            self.contentStackView.spacing = 20
        }
        
        self.appleIDTextField.delegate = self
        self.passwordTextField.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(AuthenticationViewController.textFieldDidChangeText(_:)), name: UITextField.textDidChangeNotification, object: self.appleIDTextField)
        NotificationCenter.default.addObserver(self, selector: #selector(AuthenticationViewController.textFieldDidChangeText(_:)), name: UITextField.textDidChangeNotification, object: self.passwordTextField)
        
        self.localizeAll()
        
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.localizeAll()
    }
    
    private func localizedString(_ key: String) -> String
    {
        let val = NSLocalizedString(key, comment: "")
        if val != key { return val }
        let authVal = Bundle.main.localizedString(forKey: key, value: "com.notfound", table: "Authentication")
        if authVal != "com.notfound" { return authVal }
        return key
    }
    
    private func localizeAll()
    {
        self.title = self.localizedString("Sign in")
        self.navigationItem.title = self.localizedString("Sign in")
        if let leftTitle = self.navigationItem.leftBarButtonItem?.title, !leftTitle.isEmpty {
            self.navigationItem.leftBarButtonItem?.title = self.localizedString(leftTitle)
        }
        if let rightTitle = self.navigationItem.rightBarButtonItem?.title, !rightTitle.isEmpty {
            self.navigationItem.rightBarButtonItem?.title = self.localizedString(rightTitle)
        }
        self.localizeViewHierarchy(self.view)
    }
    
    private func localizeViewHierarchy(_ view: UIView)
    {
        if let label = view as? UILabel, let text = label.text, !text.isEmpty {
            label.text = self.localizedString(text)
        } else if let button = view as? UIButton {
            if let title = button.title(for: .normal), !title.isEmpty {
                button.setTitle(self.localizedString(title), for: .normal)
            }
            return
        } else if let textField = view as? UITextField {
            if let placeholder = textField.placeholder, !placeholder.isEmpty {
                textField.placeholder = self.localizedString(placeholder)
            }
            return
        }
        for subview in view.subviews {
            localizeViewHierarchy(subview)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool)
    {
        super.viewDidDisappear(animated)
        
        self.signInButton.isIndicatingActivity = false
        self.toastView?.dismiss()
    }

    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleTabKey(_:))),
            UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(handleShiftTabKey(_:)))
        ]
    }

    @objc private func handleTabKey(_ command: UIKeyCommand) {
        if self.appleIDTextField.isFirstResponder {
            self.passwordTextField.becomeFirstResponder()
        } else if self.passwordTextField.isFirstResponder {
            self.appleIDTextField.becomeFirstResponder()
        }
    }

    @objc private func handleShiftTabKey(_ command: UIKeyCommand) {
        if self.passwordTextField.isFirstResponder {
            self.appleIDTextField.becomeFirstResponder()
        } else if self.appleIDTextField.isFirstResponder {
            self.passwordTextField.becomeFirstResponder()
        }
    }
}

private extension AuthenticationViewController
{
    func update()
    {
        if let _ = self.validate()
        {
            self.signInButton.isEnabled = true
            self.signInButton.alpha = 1.0
        }
        else
        {
            self.signInButton.isEnabled = false
            self.signInButton.alpha = 0.6
        }
    }
    
    func validate() -> (String, String)?
    {
        guard
            let emailAddress = self.appleIDTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !emailAddress.isEmpty,
            let password = self.passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !password.isEmpty
        else { return nil }
        
        return (emailAddress, password)
    }
}

private extension AuthenticationViewController
{
    @IBAction func authenticate()
    {
        guard let (emailAddress, password) = self.validate() else { return }
        
        self.appleIDTextField.resignFirstResponder()
        self.passwordTextField.resignFirstResponder()
        
        self.signInButton.isIndicatingActivity = true
        
        self.authenticationHandler?(emailAddress, password) { (result) in
            switch result
            {
            case .failure(DeveloperPortalError.userCancelled):
                debugLog("AuthenticationViewController: Two-factor authentication cancelled by user.")
                DispatchQueue.main.async {
                    self.signInButton.isIndicatingActivity = false
                }

            case .failure(DeveloperPortalError.accountRepairRequired):
                debugLog("AuthenticationViewController: Account repair cancelled by user.")
                DispatchQueue.main.async {
                    self.signInButton.isIndicatingActivity = false
                }

            case .failure(let error as NSError):
                debugLog("AuthenticationViewController: Authentication failed with error: \(error)")
                DispatchQueue.main.async {
                    self.signInButton.isIndicatingActivity = false
                    let showErrorToast = {
                        let errorWithTitle = error.withLocalizedTitle(NSLocalizedString("Failed to Sign In", comment: ""))
                        let toastView = ToastView(error: errorWithTitle)
                        toastView.show(in: self)
                        toastView.backgroundColor = .white
                        toastView.textLabel.textColor = .altPrimary
                        toastView.detailTextLabel.textColor = .altPrimary
                        self.toastView = toastView
                    }

                    let presentedRecovery = AuthManager.recordSignInFailureAndPresentRecoveryIfNeeded(
                        for: error,
                        in: self,
                        onRecoveryApplied: { [weak self] in
                            guard let self else { return }
                            self.passwordTextField.text = ""
                            self.update()
                        },
                        onCancel: showErrorToast
                    )

                    if !presentedRecovery {
                        showErrorToast()
                    }
                }
                
            case .success((let account, let session)):
                Task { @MainActor in
                    AuthManager.consecutiveSignInFailures = 0
                }
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        let title = NSLocalizedString("Authenticated", comment: "")
                        let image = UIImage(systemName: "checkmark.circle.fill")
                        self.signInButton.setTitle(title, for: .normal)
                        self.signInButton.setImage(image, for: .normal)
                        self.signInButton.isIndicatingActivity = false
                        self.signInButton.layoutIfNeeded()
                    }
                }
                self.completionHandler?((account, session, password))
            }
            
            DispatchQueue.main.async {
                self.scrollView.setContentOffset(CGPoint(x: 0, y: -self.view.safeAreaInsets.top), animated: true)
            }
        }
    }
    
    @IBAction func cancel(_ sender: UIBarButtonItem)
    {
        self.dismiss(animated: true) { [weak self] in
            self?.completionHandler?(nil)
        }
    }
}

extension AuthenticationViewController: UITextFieldDelegate
{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        switch textField
        {
        case self.appleIDTextField: self.passwordTextField.becomeFirstResponder()
        case self.passwordTextField: self.authenticate()
        default: break
        }
        
        self.update()
        
        return false
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        if string == "\t"
        {
            switch textField
            {
            case self.appleIDTextField: self.passwordTextField.becomeFirstResponder()
            case self.passwordTextField: self.appleIDTextField.becomeFirstResponder()
            default: break
            }
            return false
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField)
    {
        guard UIScreen.main.isExtraCompactHeight else { return }
        
        // Position all the controls within visible frame.
        var contentOffset = self.scrollView.contentOffset
        contentOffset.y = 44
        self.scrollView.setContentOffset(contentOffset, animated: true)
    }
}

extension AuthenticationViewController
{
    @objc func textFieldDidChangeText(_ notification: Notification)
    {
        self.update()
    }

    #if os(tvOS)
    @objc private func focusAppleID()
    {
        self.appleIDTextField.becomeFirstResponder()
    }
    
    @objc private func focusPassword()
    {
        self.passwordTextField.becomeFirstResponder()
    }
    #endif
}
