import Foundation
import CoreText

enum FontLoader {
    private(set) static var voniquePostScriptName: String?
    private(set) static var highlandPostScriptName: String?
    private(set) static var titilliumPostScriptName: String?

    @discardableResult
    static func registerVoniqueIfNeeded() -> String? {
        if let existing = voniquePostScriptName {
            return existing
        }
        let name = registerFontIfNeeded(fileName: "Vonique 64", fileExtension: "ttf")
        voniquePostScriptName = name
        return name
    }

    @discardableResult
    static func registerHighlandIfNeeded() -> String? {
        if let existing = highlandPostScriptName {
            return existing
        }
        let name = registerFontIfNeeded(fileName: "HighlandGothicFLF-Bold", fileExtension: "ttf")
        highlandPostScriptName = name
        return name
    }

    @discardableResult
    static func registerTitilliumIfNeeded() -> String? {
        if let existing = titilliumPostScriptName {
            return existing
        }
        let name = registerFontIfNeeded(fileName: "TitilliumWeb-Light", fileExtension: "ttf")
        titilliumPostScriptName = name
        return name
    }

    private static func registerFontIfNeeded(fileName: String, fileExtension: String) -> String? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Resources/Fonts")
            ?? Bundle.main.url(forResource: fileName, withExtension: fileExtension)
        else {
            print("[FontLoader] \(fileName).\(fileExtension) not found in bundle")
            return nil
        }

        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

        if !registered, let err = error?.takeRetainedValue() {
            let nsError = err as Error as NSError
            if nsError.code != 105 {
                print("[FontLoader] Font registration error: \(nsError)")
            }
        }

        guard
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
            let descriptor = descriptors.first,
            let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
        else {
            print("[FontLoader] Could not resolve postscript name for \(fileName)")
            return nil
        }

        print("[FontLoader] Loaded font postscript name: \(name)")
        return name
    }
}
