import Foundation

/// A theme for naming agents in the Tavern
/// Each theme has a pool of names organized by tiers (more common to more obscure)
public struct NamingTheme: Identifiable, Sendable {

    public let id: String
    public let displayName: String
    public let description: String

    /// Names organized by tier (index 0 = most common/recognizable)
    /// When generating names, we exhaust earlier tiers first
    public let tiers: [[String]]

    public init(
        id: String,
        displayName: String,
        description: String,
        tiers: [[String]]
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.tiers = tiers
    }

    /// All names in this theme (flattened)
    public var allNames: [String] {
        tiers.flatMap { $0 }
    }
}

// MARK: - Built-in Themes

extension NamingTheme {

    /// Lord of the Rings theme
    public static let lotr = NamingTheme(
        id: "lotr",
        displayName: "Lord of the Rings",
        description: "Names from Middle-earth",
        tiers: [
            // Tier 0: Main fellowship + iconic
            ["Frodo", "Sam", "Gandalf", "Aragorn", "Legolas", "Gimli", "Boromir", "Merry", "Pippin"],
            // Tier 1: Major characters
            ["Gollum", "Saruman", "Elrond", "Galadriel", "Arwen", "Eowyn", "Faramir", "Theoden", "Eomer"],
            // Tier 2: Supporting
            ["Bilbo", "Treebeard", "Tom Bombadil", "Radagast", "Denethor", "Grima", "Haldir", "Celeborn"],
            // Tier 3: Deep cuts
            ["Glorfindel", "Cirdan", "Beregond", "Imrahil", "Quickbeam", "Goldberry", "Fatty Bolger"]
        ]
    )

    /// Rick and Morty theme
    public static let rickAndMorty = NamingTheme(
        id: "rick-and-morty",
        displayName: "Rick and Morty",
        description: "Names from the multiverse",
        tiers: [
            // Tier 0: Main family
            ["Rick", "Morty", "Summer", "Beth", "Jerry"],
            // Tier 1: Recurring characters
            ["Mr. Meeseeks", "Birdperson", "Squanchy", "Mr. Poopybutthole", "Scary Terry", "Evil Morty"],
            // Tier 2: Memorable one-offs
            ["Snowball", "Unity", "Krombopulos Michael", "Noob Noob", "Pickle Rick", "Phoenix Person"],
            // Tier 3: Deep cuts
            ["Abradolf Lincler", "Gazorpazorpfield", "Hemorrhage", "Jaguar", "Supernova", "Million Ants"]
        ]
    )

    /// Star Trek theme
    public static let starTrek = NamingTheme(
        id: "star-trek",
        displayName: "Star Trek",
        description: "Names from the final frontier",
        tiers: [
            // Tier 0: TOS main crew
            ["Kirk", "Spock", "McCoy", "Scotty", "Uhura", "Sulu", "Chekov"],
            // Tier 1: TNG main crew
            ["Picard", "Data", "Worf", "Riker", "Troi", "La Forge", "Crusher"],
            // Tier 2: Other series leads
            ["Sisko", "Janeway", "Seven", "Archer", "Tpol", "Burnham", "Pike"],
            // Tier 3: Memorable recurring
            ["Q", "Quark", "Odo", "Guinan", "Garak", "Dukat", "Neelix", "Tuvok"]
        ]
    )

    /// Discworld theme
    public static let discworld = NamingTheme(
        id: "discworld",
        displayName: "Discworld",
        description: "Names from Terry Pratchett's Disc",
        tiers: [
            // Tier 0: Major recurring
            ["Rincewind", "Death", "Vimes", "Granny Weatherwax", "Nanny Ogg", "Tiffany Aching"],
            // Tier 1: Watch and Wizards
            ["Carrot", "Angua", "Nobby", "Colon", "Ridcully", "Ponder Stibbons", "The Librarian"],
            // Tier 2: Gods and Others
            ["Moist von Lipwig", "Vetinari", "CMOT Dibbler", "Magrat", "Agnes Nitt", "Susan Sto Helit"],
            // Tier 3: Deep cuts
            ["Brutha", "Om", "Lu-Tze", "Lobsang", "Dorfl", "Detritus", "Gaspode"]
        ]
    )

    /// All built-in themes
    public static let builtIn: [NamingTheme] = [
        .lotr,
        .rickAndMorty,
        .starTrek,
        .discworld
    ]
}
