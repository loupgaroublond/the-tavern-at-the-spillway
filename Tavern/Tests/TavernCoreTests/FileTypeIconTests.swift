import Foundation
import Testing
@testable import TavernCore

@Suite("FileTypeIcon Tests")
struct FileTypeIconTests {

    @Test("Known extensions map correctly")
    func knownExtensionsMapCorrectly() {
        #expect(FileTypeIcon.symbolName(for: "swift", isDirectory: false) == "swift")
        #expect(FileTypeIcon.symbolName(for: "json", isDirectory: false) == "curlybraces")
        #expect(FileTypeIcon.symbolName(for: "md", isDirectory: false) == "doc.text")
        #expect(FileTypeIcon.symbolName(for: "yml", isDirectory: false) == "list.bullet.rectangle")
        #expect(FileTypeIcon.symbolName(for: "py", isDirectory: false) == "terminal")
        #expect(FileTypeIcon.symbolName(for: "sh", isDirectory: false) == "terminal")
        #expect(FileTypeIcon.symbolName(for: "png", isDirectory: false) == "photo")
        #expect(FileTypeIcon.symbolName(for: "html", isDirectory: false) == "globe")
        #expect(FileTypeIcon.symbolName(for: "zip", isDirectory: false) == "doc.zipper")
    }

    @Test("Unknown extension returns generic symbol")
    func unknownExtensionReturnsGenericSymbol() {
        #expect(FileTypeIcon.symbolName(for: "xyz", isDirectory: false) == "doc")
        #expect(FileTypeIcon.symbolName(for: "unknown", isDirectory: false) == "doc")
    }

    @Test("Nil extension returns generic symbol")
    func nilExtensionReturnsGenericSymbol() {
        #expect(FileTypeIcon.symbolName(for: nil, isDirectory: false) == "doc")
    }

    @Test("Directory returns folder symbol")
    func directoryReturnsFolderSymbol() {
        #expect(FileTypeIcon.symbolName(for: nil, isDirectory: true) == "folder")
        #expect(FileTypeIcon.symbolName(for: nil, isDirectory: true, isExpanded: true) == "folder.fill")
    }

    @Test("Case insensitive extension matching")
    func caseInsensitiveExtensionMatching() {
        #expect(FileTypeIcon.symbolName(for: "SWIFT", isDirectory: false) == "swift")
        #expect(FileTypeIcon.symbolName(for: "Json", isDirectory: false) == "curlybraces")
    }
}
