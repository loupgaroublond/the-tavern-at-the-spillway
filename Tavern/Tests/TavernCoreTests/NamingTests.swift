import Foundation
import Testing
@testable import TavernCore

@Suite("NamingTheme Tests")
struct NamingThemeTests {

    @Test("Theme has all required properties")
    func themeHasRequiredProperties() {
        let theme = NamingTheme.lotr

        #expect(!theme.id.isEmpty)
        #expect(!theme.displayName.isEmpty)
        #expect(!theme.description.isEmpty)
        #expect(!theme.tiers.isEmpty)
    }

    @Test("Theme allNames returns flattened list")
    func themeAllNamesFlattened() {
        let theme = NamingTheme.lotr
        let allNames = theme.allNames

        // Should contain names from all tiers
        #expect(allNames.contains("Frodo"))  // Tier 0
        #expect(allNames.contains("Gollum")) // Tier 1
        #expect(allNames.contains("Bilbo"))  // Tier 2
        #expect(allNames.contains("Glorfindel")) // Tier 3
    }

    @Test("Built-in themes are available")
    func builtInThemesAvailable() {
        let themes = NamingTheme.builtIn

        #expect(themes.count >= 4)
        #expect(themes.contains { $0.id == "lotr" })
        #expect(themes.contains { $0.id == "rick-and-morty" })
        #expect(themes.contains { $0.id == "star-trek" })
        #expect(themes.contains { $0.id == "discworld" })
    }
}

@Suite("NameGenerator Tests")
struct NameGeneratorTests {

    @Test("Generator generates names in tier order")
    func generatorGeneratesInTierOrder() {
        let generator = NameGenerator(theme: .lotr)

        // First names should come from tier 0
        let name1 = generator.nextName()
        let name2 = generator.nextName()
        let name3 = generator.nextName()

        #expect(name1 != nil)
        #expect(name2 != nil)
        #expect(name3 != nil)

        // Should be from tier 0 (Fellowship members)
        let tier0 = NamingTheme.lotr.tiers[0]
        #expect(tier0.contains(name1!))
        #expect(tier0.contains(name2!))
        #expect(tier0.contains(name3!))
    }

    @Test("Generator generates unique names")
    func generatorGeneratesUniqueNames() {
        let generator = NameGenerator(theme: .lotr)

        var names: Set<String> = []
        for _ in 0..<10 {
            if let name = generator.nextName() {
                #expect(!names.contains(name), "Name \(name) was generated twice")
                names.insert(name)
            }
        }

        #expect(names.count == 10)
    }

    @Test("Generator exhausts tiers in order")
    func generatorExhaustsTiersInOrder() {
        // Create a tiny theme for testing
        let miniTheme = NamingTheme(
            id: "mini",
            displayName: "Mini",
            description: "Small test theme",
            tiers: [
                ["Alpha", "Beta"],
                ["Gamma", "Delta"]
            ]
        )

        let generator = NameGenerator(theme: miniTheme)

        let name1 = generator.nextName()
        let name2 = generator.nextName()
        let name3 = generator.nextName()
        let name4 = generator.nextName()
        let name5 = generator.nextName()

        #expect(name1 == "Alpha")
        #expect(name2 == "Beta")
        #expect(name3 == "Gamma")
        #expect(name4 == "Delta")
        #expect(name5 == nil) // Exhausted
    }

    @Test("Generator returns nil when exhausted")
    func generatorReturnsNilWhenExhausted() {
        let miniTheme = NamingTheme(
            id: "tiny",
            displayName: "Tiny",
            description: "Very small theme",
            tiers: [["Solo"]]
        )

        let generator = NameGenerator(theme: miniTheme)

        let name1 = generator.nextName()
        let name2 = generator.nextName()

        #expect(name1 == "Solo")
        #expect(name2 == nil)
    }

    @Test("Generator fallback provides numbered names")
    func generatorFallbackProvidesNumberedNames() {
        let miniTheme = NamingTheme(
            id: "tiny",
            displayName: "Tiny",
            description: "Very small theme",
            tiers: [["Solo"]]
        )

        let generator = NameGenerator(theme: miniTheme)

        let name1 = generator.nextNameOrFallback() // "Solo"
        let name2 = generator.nextNameOrFallback() // "Agent-1"
        let name3 = generator.nextNameOrFallback() // "Agent-2"

        #expect(name1 == "Solo")
        #expect(name2 == "Agent-1")
        #expect(name3 == "Agent-2")
    }

    @Test("Generator tracks used names")
    func generatorTracksUsedNames() {
        let generator = NameGenerator(theme: .lotr)

        #expect(generator.usedNames.isEmpty)

        _ = generator.nextName()
        _ = generator.nextName()

        #expect(generator.usedNames.count == 2)
    }

    @Test("Generator checks name availability")
    func generatorChecksNameAvailability() {
        let generator = NameGenerator(theme: .lotr)

        #expect(generator.isNameAvailable("Frodo"))

        _ = generator.nextName() // Takes "Frodo"

        #expect(!generator.isNameAvailable("Frodo"))
        #expect(generator.isNameAvailable("Gandalf")) // Not taken yet
    }

    @Test("Generator can reserve specific names")
    func generatorCanReserveNames() {
        let generator = NameGenerator(theme: .lotr)

        let reserved = generator.reserveName("Gandalf")
        #expect(reserved == true)
        #expect(!generator.isNameAvailable("Gandalf"))

        // Can't reserve again
        let reservedAgain = generator.reserveName("Gandalf")
        #expect(reservedAgain == false)
    }

    @Test("Generator can release names")
    func generatorCanReleaseNames() {
        let generator = NameGenerator(theme: .lotr)

        generator.reserveName("Frodo")
        #expect(!generator.isNameAvailable("Frodo"))

        generator.releaseName("Frodo")
        #expect(generator.isNameAvailable("Frodo"))
    }

    @Test("Generator reset clears all state")
    func generatorResetClearsState() {
        let generator = NameGenerator(theme: .lotr)

        _ = generator.nextName()
        _ = generator.nextName()
        #expect(!generator.usedNames.isEmpty)

        generator.reset()

        #expect(generator.usedNames.isEmpty)
        #expect(generator.isNameAvailable("Frodo"))
    }

    @Test("Generator tracks remaining names")
    func generatorTracksRemainingNames() {
        let miniTheme = NamingTheme(
            id: "small",
            displayName: "Small",
            description: "Small test theme",
            tiers: [["A", "B", "C"]]
        )

        let generator = NameGenerator(theme: miniTheme)

        #expect(generator.remainingNames == 3)

        _ = generator.nextName()
        #expect(generator.remainingNames == 2)

        _ = generator.nextName()
        #expect(generator.remainingNames == 1)
    }

    @Test("Generator can switch themes")
    func generatorCanSwitchThemes() {
        let generator = NameGenerator(theme: .lotr)

        _ = generator.nextName() // Gets a LOTR name

        generator.currentTheme = .rickAndMorty

        // Should now generate Rick and Morty names
        // Note: Previously used LOTR names are still marked as used
        let name = generator.nextName()
        #expect(name != nil)
        #expect(NamingTheme.rickAndMorty.allNames.contains(name!))
    }
}
