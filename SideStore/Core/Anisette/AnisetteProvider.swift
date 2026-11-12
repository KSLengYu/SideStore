//
//  AnisetteProvider.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import SideSign

enum AnisetteProvider {
    private static let macAnisetteMigrationKey = "didMigrateMacAnisetteDefaultsV1"

    /// One-time migration for upgrades from builds where ODA or Android-ADI servers defaulted on.
    static func migrateLegacyAnisetteDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: macAnisetteMigrationKey) else { return }
        defaults.set(true, forKey: macAnisetteMigrationKey)

        var clearedState = false
        if defaults.useOnDeviceAnisette {
            defaults.useOnDeviceAnisette = false
            clearedState = true
        }

        let currentURL = normalizedAddress(defaults.menuAnisetteURL)
        if currentURL.isEmpty || AppConstants.Anisette.Servers.legacyAndroidADIDefaultURLs.contains(currentURL) {
            defaults.menuAnisetteURL = AppConstants.Anisette.Servers.defaultServerURL
            clearedState = true
        }

        if clearedState {
            Keychain.shared.adiPb = nil
            AnisetteDataManager.shared.clearCache()
            debugLog("[AnisetteProvider] Migrated legacy Anisette defaults to Mac ADI (\(defaults.menuAnisetteURL)) and cleared cached adi.pb.")
        }
    }

    static func fetch(handler: AnisetteServerHandler? = nil) async throws -> ALTAnisetteData {
        migrateLegacyAnisetteDefaultsIfNeeded()
        if UserDefaults.standard.useOnDeviceAnisette {
            debugLog("[AnisetteProvider] Fetching anisette via On-Device Anisette (ODA)...")
            return try await OnDeviceAnisetteManager.shared.fetchAnisetteData()
        } else {
            debugLog("[AnisetteProvider] Fetching anisette via remote server...")
            return try await fetchRemote(handler: handler)
        }
    }

    private static func normalizedAddress(_ address: String) -> String {
        var trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func prioritizedRemoteServers(
        from activeURLStrings: [String],
        lastServer: String,
        disableRotation: Bool
    ) -> [URL] {
        if disableRotation {
            let trimmed = lastServer.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selected = URL(string: trimmed), !trimmed.isEmpty {
                return [selected]
            }
            return [URL(string: AppConstants.Anisette.Servers.defaultServerURL)!]
        }

        var seen = Set<String>()
        var ordered: [URL] = []

        func appendIfNew(_ raw: String) {
            let norm = normalizedAddress(raw)
            guard !norm.isEmpty, seen.insert(norm).inserted, let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return
            }
            ordered.append(url)
        }

        // Keep the user's last server first only if it is not a known rejected Android-ADI default.
        let lastNorm = normalizedAddress(lastServer)
        if !lastNorm.isEmpty && !AppConstants.Anisette.Servers.legacyAndroidADIDefaultURLs.contains(lastNorm) {
            appendIfNew(lastServer)
        }

        // Prefer working Mac-ADI servers (starting with SideStore (New) fallback).
        appendIfNew(AppConstants.Anisette.Servers.defaultServerURL)
        for host in AppConstants.Anisette.Servers.preferredMacADIHosts {
            for raw in activeURLStrings where URL(string: normalizedAddress(raw))?.host?.lowercased() == host {
                appendIfNew(raw)
            }
        }

        // Non-legacy servers next, legacy Android-ADI defaults last.
        for raw in activeURLStrings where !AppConstants.Anisette.Servers.legacyAndroidADIDefaultURLs.contains(normalizedAddress(raw)) {
            appendIfNew(raw)
        }
        for raw in activeURLStrings where AppConstants.Anisette.Servers.legacyAndroidADIDefaultURLs.contains(normalizedAddress(raw)) {
            appendIfNew(raw)
        }

        return ordered
    }

    private static func fetchRemote(handler: AnisetteServerHandler? = nil) async throws -> ALTAnisetteData {
        let serverUrlStrings = await AnisetteServersManager.shared.getActiveServerURLs()
        let lastServer = UserDefaults.standard.menuAnisetteURL
        let servers = prioritizedRemoteServers(
            from: serverUrlStrings,
            lastServer: lastServer,
            disableRotation: UserDefaults.standard.disableAnisetteRotation
        )
        guard !servers.isEmpty else {
            throw AnisetteError.noServersConfigured
        }

        let startIndex = 0

        let provider = SideSign.AnisetteDataManager.shared
        let existingBlob = AnisetteConfigManager.shared.anisetteAdiBlob.flatMap { Data(base64Encoded: $0) }
        let identifier = await AnisetteConfigManager.shared.resolveDeviceIdentifier()
        let headers = await AnisetteConfigManager.shared.makeRequestHeaders()

        let (anisetteData, newAdiBlob) = try await provider.fetchAnisetteDataWithFailover(
            servers: UserDefaults.standard.disableAnisetteRotation ? [servers[startIndex]] : servers,
            startIndex: startIndex,
            identifier: identifier,
            existingAdiBlob: existingBlob,
            headers: headers,
            onError: { error in
                if let anisetteError = error as? SideSign.AnisetteError,
                   case .outdatedV1Server(let serverURL, _) = anisetteError {
                    if UserDefaults.standard.defaultServerURL == serverURL.absoluteString {
                        return true
                    }
                    if let handler = handler {
                        let shouldContinue = try await handler.warnOutdatedAnisetteServer()
                        if shouldContinue {
                            UserDefaults.standard.defaultServerURL = serverURL.absoluteString
                        }
                        return shouldContinue
                    }
                }
                return false
            },
            onSuccess: { successfulServer in
                UserDefaults.standard.menuAnisetteURL = successfulServer.absoluteString
                debugLog("[AnisetteProvider] Successfully fetched Anisette data from \(successfulServer.absoluteString)")
            }
        )

        if let freshBlob = newAdiBlob {
            AnisetteConfigManager.shared.anisetteAdiBlob = freshBlob.base64EncodedString()
        }

        return anisetteData
    }
}
