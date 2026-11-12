//
//  SideStoreLanguageManager.swift
//  SideStore
//

import Foundation
import UIKit

@objc public final class SideStoreLanguageManager: NSObject {
    @objc public static let shared = SideStoreLanguageManager()
    
    @objc public static var defaultLanguage: String {
        if let preferred = Locale.preferredLanguages.first, preferred.hasPrefix("zh") {
            return "zh-Hans"
        }
        return "en"
    }
    
    private static func normalizeLanguage(_ raw: String?) -> String {
        switch raw {
        case "zh-Hans", "zh-CN", "zh_CN":
            return "zh-Hans"
        case "en":
            return "en"
        default:
            return defaultLanguage
        }
    }
    
    @objc public private(set) var activeLanguage: String = "zh-Hans"
    @objc public private(set) var needsRestart: Bool = false
    
    private override init() {
        super.init()
        self.activeLanguage = self.readStoredLanguage()
    }
    
    private func readStoredLanguage() -> String {
        if let lang = UserDefaults.standard.string(forKey: "SideStoreSelectedLanguage"), !lang.isEmpty {
            return Self.normalizeLanguage(lang)
        }
        if let lang = lcDefaults?.string(forKey: "SideStoreSelectedLanguage"), !lang.isEmpty {
            return Self.normalizeLanguage(lang)
        }
        if let lang = UserDefaults.standard.string(forKey: "LCUserLanguage"), !lang.isEmpty {
            return Self.normalizeLanguage(lang)
        }
        if let lang = lcDefaults?.string(forKey: "LCUserLanguage"), !lang.isEmpty {
            return Self.normalizeLanguage(lang)
        }
        return Self.defaultLanguage
    }
    
    public static let supportedLanguages: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"),
        ("en", "English")
    ]
    
    private var lcDefaults: UserDefaults? {
        let sel = NSSelectorFromString("lcUserDefaults")
        guard let method = class_getClassMethod(UserDefaults.self, sel) else {
            return nil
        }
        typealias MethodSignature = @convention(c) (AnyClass, Selector) -> UserDefaults?
        let function = unsafeBitCast(method_getImplementation(method), to: MethodSignature.self)
        return function(UserDefaults.self, sel)
    }
    
    @objc public var currentLanguage: String {
        get {
            return readStoredLanguage()
        }
        set {
            let normalized = Self.normalizeLanguage(newValue)
            UserDefaults.standard.set(normalized, forKey: "SideStoreSelectedLanguage")
            UserDefaults.standard.set(normalized, forKey: "LCUserLanguage")
            lcDefaults?.set(normalized, forKey: "SideStoreSelectedLanguage")
            lcDefaults?.set(normalized, forKey: "LCUserLanguage")
            
            UserDefaults.standard.set([normalized], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            lcDefaults?.synchronize()
            self.needsRestart = (normalized != self.activeLanguage)
        }
    }
    
    private var cachedBundles: [String: Bundle] = [:]
    
    @objc public func bundle(for language: String) -> Bundle? {
        if let existing = cachedBundles[language] {
            return existing
        }
        
        // 1. Check inside framework or self bundle
        let selfBundle = Bundle(for: SideStoreLanguageManager.self)
        if let path = selfBundle.path(forResource: language, ofType: "lproj"),
           let b = Bundle(path: path) {
            cachedBundles[language] = b
            return b
        }
        if language == "zh-Hans" {
            if let path = selfBundle.path(forResource: "zh_CN", ofType: "lproj"),
               let b = Bundle(path: path) {
                cachedBundles[language] = b
                return b
            }
        }
        
        // 2. Check main bundle
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let b = Bundle(path: path) {
            cachedBundles[language] = b
            return b
        }
        if language == "zh-Hans" {
            if let path = Bundle.main.path(forResource: "zh_CN", ofType: "lproj"),
               let b = Bundle(path: path) {
                cachedBundles[language] = b
                return b
            }
        }
        
        return nil
    }
    
    @objc public func restartApp() {
        lcDefaults?.set("builtinSideStore", forKey: "selected")
        lcDefaults?.synchronize()
        UserDefaults.standard.synchronize()
        
        if let utilsClass = NSClassFromString("LCSharedUtils") as? NSObject.Type {
            let relaunchSel = NSSelectorFromString("relaunchBuiltinSideStore")
            if utilsClass.responds(to: relaunchSel) {
                _ = utilsClass.perform(relaunchSel)
                return
            }
            let classicSel = NSSelectorFromString("launchToGuestAppWithClassicMode:")
            if utilsClass.responds(to: classicSel) {
                _ = utilsClass.perform(classicSel, with: nil)
                return
            }
        }
        
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            exit(0)
        }
    }
    
    @objc public func presentRestartAlert(from viewController: UIViewController?) {
        guard let presenter = viewController ?? Self.topViewController() else { return }
        let title = NSLocalizedString("Restart Required", comment: "")
        let message = NSLocalizedString("Changing the display language requires restarting SideStore to take full effect. Restart now?", comment: "")
        let restartTitle = NSLocalizedString("Restart Now", comment: "")
        let laterTitle = NSLocalizedString("Later", comment: "")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: laterTitle, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: restartTitle, style: .default) { _ in
            self.restartApp()
        })
        presenter.present(alert, animated: true)
    }
    
    @objc public static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
    
    private static var isSwizzled = false
    
    @objc public static func setup() {
        _ = SideStoreLanguageManager.shared
        guard !isSwizzled else { return }
        isSwizzled = true
        
        let original = class_getInstanceMethod(Bundle.self, #selector(Bundle.localizedString(forKey:value:table:)))
        let swizzled = class_getInstanceMethod(Bundle.self, #selector(Bundle.sideStore_localizedString(forKey:value:table:)))
        if let orig = original, let swiz = swizzled {
            method_exchangeImplementations(orig, swiz)
        }
    }
}

extension Bundle {
    private static let recursionKey = "com.sidestore.localizedString.recursion"
    
    @objc func sideStore_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // Guard against any re-entrancy or recursion loop
        if Thread.current.threadDictionary[Self.recursionKey] as? Bool == true {
            return self.sideStore_localizedString(forKey: key, value: value, table: tableName)
        }
        
        // If this bundle itself is an lproj bundle, do standard lookup to prevent infinite recursion
        let path = self.bundlePath
        if path.contains(".lproj") || self.bundleURL.pathExtension == "lproj" {
            return self.sideStore_localizedString(forKey: key, value: value, table: tableName)
        }
        
        Thread.current.threadDictionary[Self.recursionKey] = true
        defer {
            Thread.current.threadDictionary[Self.recursionKey] = nil
        }
        
        // Keep the active language fixed for the lifetime of this process so changes take effect only after restart
        let lang = SideStoreLanguageManager.shared.activeLanguage
        if let langBundle = SideStoreLanguageManager.shared.bundle(for: lang), langBundle != self {
            let res = langBundle.sideStore_localizedString(forKey: key, value: "com.sidestore.notFound", table: tableName)
            if res != "com.sidestore.notFound" {
                return res
            }
        }
        if lang.hasPrefix("en") && (tableName == nil || tableName == "Localizable") {
            if let val = value, !val.isEmpty, val != "com.sidestore.notFound" {
                return val
            }
            return key
        }
        
        return self.sideStore_localizedString(forKey: key, value: value, table: tableName)
    }
}
