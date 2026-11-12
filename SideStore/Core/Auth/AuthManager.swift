//
//  AuthManager.swift
//  SideStore
//
//  Created by Magesh K on 1/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import Foundation
import SideSign
import CoreData

public final class AuthManager: @unchecked Sendable {
    public static let shared = AuthManager()
    
    private var portalProxy: DeveloperPortalProxyWithAuth {
        DeveloperPortalProxy.shared as! DeveloperPortalProxyWithAuth
    }
    
    private init() {}
    
    private var team: ALTTeam?
    private var session: ALTAppleAPISession?

    public var isAuthenticated: Bool {
        let hasEmail = Keychain.shared.appleIDEmailAddress != nil
        let hasPassword = Keychain.shared.appleIDPassword != nil
        let hasToken = Keychain.shared.appleIDXcodeToken != nil
        return hasEmail && (hasPassword || hasToken)
    }
    
    public var currentAppleID: String? {
        get { Keychain.shared.appleIDEmailAddress }
        set { Keychain.shared.appleIDEmailAddress = newValue }
    }
    
    public var password: String? {
        get { Keychain.shared.appleIDPassword }
        set { Keychain.shared.appleIDPassword = newValue }
    }
    
    public var adsid: String? {
        get { Keychain.shared.appleIDAdsid }
        set { Keychain.shared.appleIDAdsid = newValue }
    }
    
    public var xcodeToken: String? {
        get { Keychain.shared.appleIDXcodeToken }
        set { Keychain.shared.appleIDXcodeToken = newValue }
    }
    
    public var hasStoredPassword: Bool {
        return Keychain.shared.appleIDPassword != nil
    }
    
    public var hasStoredXcodeToken: Bool {
        return Keychain.shared.appleIDXcodeToken != nil
    }
    
    public func signOut(
        keepCertificate: Bool = false,
        keepAnisetteData: Bool = true,
        keepAnisetteHeaders: Bool = true,
        keepSideSignHeaders: Bool = true
    ) async {
        self.session = nil
        self.team = nil
        if !keepCertificate {
            debugLog("[AuthManager] Clearing signing certificate in cert manager and keychain.")
            CertificateManager.shared.clearActiveCertificate()
            debugLog("[AuthManager] Cleared signing certificate in cert manager and keychain.")

        } else {
            debugLog("[AuthManager] Preserved signing certificate in cert manager and keychain.")
        }
        debugLog("[AuthManager] Clearing account and team info in database.")
        await DatabaseManager.shared.deactivateActiveAccountAndTeam()
        debugLog("[AuthManager] Cleared account and team info in database.")

        debugLog("[AuthManager] Clearing sign-in info from keychain.")
        Keychain.shared.clearSignInInfo(keepAnisetteData: keepAnisetteData)
        debugLog("[AuthManager] Cleared sign-in info from keychain.")

        if !keepAnisetteHeaders {
            debugLog("[AuthManager] Resetting Anisette header customizations to defaults.")
            AnisetteConfigManager.shared.resetToDefaults()
        }

        if !keepSideSignHeaders {
            debugLog("[AuthManager] Resetting SideSign header customizations to defaults.")
            SideSignConfigManager.shared.resetToDefaults()
        }

        AnisetteDataManager.shared.clearCache()
    }
    
    @discardableResult
    public func getAuthenticatedSession() async throws -> ALTAppleAPISession {
        return try await TaskChainCoalescer.shared.coalesce(key: "apple_auth_session") {
            guard let adsid = self.adsid,                           // directory services id
                  let xcodeToken = self.xcodeToken else             // xcode token
            {
                debugLog("[AuthManager] No stored tokens found.")
                throw OperationError.notAuthenticated
            }
            let anisetteData = try await AnisetteProvider.fetch()   // one time pass
            let xcodeVersion = await AnisetteConfigManager.shared.resolvedXcodeVersion()
            
            let session = ALTAppleAPISession(
                dsid: adsid,
                authToken: xcodeToken,
                anisetteData: anisetteData,
                xcodeVersion: xcodeVersion
            )
            self.session = session
            return session
        }
    }

    public func getAuthenticatedTeam() async throws -> ALTTeam {
        if let team = self.team {
            return team
        }
        
        let team = try await self.resolveActiveTeam()
        self.team = team
        return team
    }

    private func resolveActiveTeam() async throws -> ALTTeam {
        try await DatabaseManager.shared.persistentContainer.performBackgroundTask { context in
            guard let dbTeam = DatabaseManager.shared.activeTeam(in: context) else {
                throw OperationError.notAuthenticated
            }
            return ALTTeam(identifier: dbTeam.identifier, name: dbTeam.name, type: dbTeam.type)
        }
    }
    
    @discardableResult
    func signIn(
        presentingViewController: UIViewController? = nil,
        skipDeviceRegistration: Bool = false,
        skipCertificateProvisioning: Bool = false,
        skipResign: Bool = false,
        skipHowTos: Bool = false
    ) async throws -> SignInResult {
        let dbBackgroundContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let signInFlowHandler = SignInFlowHandler(presentingViewController: presentingViewController)
        let context = StandaloneOperationContext(
            steps: .signIn,
            dbBackgroundContext: dbBackgroundContext
        )
        
        let signInOperation = try SignInOperation(
            context: context,
            signInHandler: signInFlowHandler,
            anisetteServerHandler: signInFlowHandler,
            skipDeviceRegistration: skipDeviceRegistration,
            skipCertificateProvisioning: skipCertificateProvisioning,
            skipResign: skipResign,
            skipHowTos: skipHowTos
        )
        let result = try await signInOperation.execute()
        self.team = result.team
        self.session = result.session
        return result
    }
    
    
    // Developer Portal Operations
    public func signIn(appleID: String, 
                       password: String, 
                       anisetteData: ALTAnisetteData, 
                       xcodeVersion: String, 
                       machinePassword: String? = nil,
                       accountRepairHandler: DeveloperPortal.AccountRepairHandler = DeveloperPortal.defaultAccountRepairHandler,
                       verificationHandler: DeveloperPortal.VerificationHandler?) async throws -> (ALTAccount, ALTAppleAPISession) 
    {
        return try await self.portalProxy.signIn(
            appleID: appleID, 
            password: password, 
            anisetteData: anisetteData, 
            xcodeVersion: xcodeVersion, 
            machinePassword: machinePassword,
            accountRepairHandler: accountRepairHandler, 
            verificationHandler: verificationHandler
        )
    }
}

fileprivate extension DatabaseManager {
    //TODO: this is not clean, but for now this should be fine, ie we should later make this proper async instead of blocking
    func deactivateActiveAccountAndTeam() async {
        guard self.isStarted else {
            debugLog("[AuthManager] DatabaseManager is not started. Skipping CoreData active account/team deactivation.")
            return
        }
        let bgContext = self.persistentContainer.newBackgroundContext()
        await bgContext.perform {
            if let account = self.activeAccount(in: bgContext) {
                account.isActiveAccount = false
            }
            if let team = self.activeTeam(in: bgContext) {
                team.isActiveTeam = false
            }
            do {
                try bgContext.save()
            } catch {
                debugLog("[AuthManager] Failed to save CoreData context when deactivating active account and team: \(error)")
            }
        }
        
        await self.viewContext.perform {
            self.viewContext.processPendingChanges()
            self.viewContext.refreshAllObjects()
        }
    }
}

public extension AuthManager {
    /// Tracks consecutive sign-in failures within the current session so the recovery alert triggers after 7 failures.
    @MainActor
    static var consecutiveSignInFailures: Int = 0

    nonisolated static func isAnisetteOrLoginRecoveryError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let details = "\(error) \(nsError.userInfo) \(nsError.localizedDescription)".lowercased()
        return nsError.code == -80045
            || nsError.code == -80046
            || nsError.code == -45061
            || nsError.code == -22421
            || details.contains("80045")
            || details.contains("80046")
            || details.contains("45061")
            || details.contains("adi.pb")
            || details.contains("anisette")
            || details.contains("provisioning failed")
    }

    @MainActor
    static func resetAnisetteAndDisableODAForRecovery() async {
        UserDefaults.standard.useOnDeviceAnisette = false
        var normalized = UserDefaults.standard.menuAnisetteURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        if normalized.isEmpty || AppConstants.Anisette.Servers.legacyAndroidADIDefaultURLs.contains(normalized) {
            UserDefaults.standard.menuAnisetteURL = AppConstants.Anisette.Servers.defaultServerURL
        }

        await AuthManager.shared.signOut(
            keepCertificate: true,
            keepAnisetteData: false,
            keepAnisetteHeaders: true
        )
        AnisetteConfigManager.shared.anisetteAdiBlob = nil
        SideSignConfigManager.shared.applyConfigToDeveloperPortal()
        consecutiveSignInFailures = 0
    }

    @MainActor
    @discardableResult
    static func recordSignInFailureAndPresentRecoveryIfNeeded(
        for error: Error,
        in viewController: UIViewController,
        onRecoveryApplied: (@MainActor () -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) -> Bool {
        consecutiveSignInFailures += 1
        guard consecutiveSignInFailures >= 7 || isAnisetteOrLoginRecoveryError(error) else {
            return false
        }

        let alert = UIAlertController(
            title: NSLocalizedString("Sign-In Recovery Recommended", comment: ""),
            message: NSLocalizedString("Multiple Apple ID sign-in failures (or an Anisette / -80045 error) were detected. Turning off On-Device Anisette, switching to a working Mac Anisette server, and resetting adi.pb usually resolves this.\n\nApply this fix now?", comment: ""),
            preferredStyle: .alert
        )

        let resetAction = UIAlertAction(
            title: NSLocalizedString("Disable ODA & Reset adi.pb", comment: ""),
            style: .destructive
        ) { [weak viewController] _ in
            Task { @MainActor in
                await resetAnisetteAndDisableODAForRecovery()
                onRecoveryApplied?()
                if let viewController {
                    ToastView(
                        text: NSLocalizedString("Anisette & adi.pb Reset", comment: ""),
                        detailText: NSLocalizedString("On-Device Anisette has been turned off and adi.pb was cleared. Please sign in again.", comment: "")
                    ).show(in: viewController)
                }
            }
        }

        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            if consecutiveSignInFailures >= 7 {
                consecutiveSignInFailures = 0
            }
            onCancel?()
        }

        alert.addAction(resetAction)
        alert.addAction(cancelAction)
        viewController.present(alert, animated: true)
        return true
    }
}
