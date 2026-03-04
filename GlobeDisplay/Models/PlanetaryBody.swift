import Foundation

enum PlanetaryBody: String, Codable, CaseIterable, Sendable {
    case earth, moon, mars, venus, mercury
    case jupiter, saturn, uranus, neptune, pluto

    var displayName: String {
        rawValue.capitalized
    }
}
