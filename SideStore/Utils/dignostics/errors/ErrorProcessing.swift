//
//  ErrorProcessing.swift
//  SideStore
//
//  Created by Magesh K on 20/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//


class ErrorProcessing {
    
    enum InfoMode: String {
        case fullError
        case localizedDescription
    }
    
    let info: InfoMode
    let unique: Bool
    let recur: Bool
    
    
    var errors: Set<String> = []
    
    // by default we will process only the localDesc on first level errors
    init(_ mode: InfoMode = .localizedDescription, unique: Bool = false, recur: Bool = false){
        self.info = mode
        self.unique = unique
        self.recur = recur
    }
    
    private func userFriendlyDescription(for error: NSError) -> String {
        let domain = error.domain
        if domain == "kcerrordomain" || domain == NSOSStatusErrorDomain {
            switch error.code {
            case -25300: // errSecItemNotFound
                return NSLocalizedString("Keychain item not found.", comment: "")
            case -25299: // errSecDuplicateItem
                return NSLocalizedString("Keychain item already exists.", comment: "")
            case -25293: // errSecAuthFailed
                return NSLocalizedString("Keychain authentication failed.", comment: "")
            default:
                return NSLocalizedString("Keychain security error.", comment: "")
            }
        }
        return error.localizedDescription
    }

    private func processError(_ error: NSError, ignoreTitle: Bool = false, getMoreErrors: (_ error: NSError)->String) -> String{
        let serializedError = "\(error.domain):\(error.code):\(error.localizedDescription)"
        // Always prevent recursion cycles regardless of unique flag
        if errors.contains(serializedError) {
            return ""
        }
        errors.insert(serializedError)    // mark this as processed
        
        var title = ""
        var desc = ""
        switch (info){
            case .localizedDescription:
                title = !ignoreTitle ? (error.localizedTitle.map{$0+"\n"} ?? "") : ""
                desc = userFriendlyDescription(for: error)
            case .fullError:
                desc = "\(error)"
        }
        let moreErrors = getMoreErrors(error)
        let formattedMore = moreErrors.isEmpty ? "" : "\n" + moreErrors
        return title + desc + formattedMore
    }

    func getDescription(error: NSError) -> String{
        errors = []  // reinit for each request
        return getDescriptionText(error: error, 0)
    }
    
    func getDescriptionText(error: NSError, _ depth: Int = 0) -> String{
        guard depth < 6 else { return "" }
        
        // closure
        let recurseErrors = { (err: NSError) in
            self.getDescriptionText(error: err, depth + 1)
        }
        
        var description = ""
        // process current error only if recur was requested
        let processMoreErrors = recur ? recurseErrors : { (_: NSError) in "" }
        
        let underlyingErrors = error.underlyingErrors
        if let wrappedError = (error as? ALTWrappedError)?.wrappedError {
            description += getDescriptionText(error: wrappedError, depth + 1)
        } else if !underlyingErrors.isEmpty {
            description += underlyingErrors.compactMap { err in
                let nsErr = err as NSError
                return processError(nsErr, getMoreErrors: processMoreErrors)
            }.joined(separator: "\n")
        } else if let underlyingError = error.underlyingError as? NSError, underlyingError !== error {
            description += processError(underlyingError, getMoreErrors: processMoreErrors)
        } else {
            // ignore the title for the base error since we wanted this to be description
            let isBaseError = (depth == 0)
            description += processError(error, ignoreTitle: isBaseError, getMoreErrors: processMoreErrors)
        }
        return description
    }
}
