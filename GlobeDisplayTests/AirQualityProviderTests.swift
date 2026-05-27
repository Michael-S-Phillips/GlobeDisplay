import XCTest
@testable import GlobeDisplay

final class AirQualityProviderTests: XCTestCase {

    func test_cityCount_is60() {
        XCTAssertEqual(AirQualityProvider.cities.count, 60)
    }

    func test_allCities_haveValidLatitude() {
        for city in AirQualityProvider.cities {
            XCTAssertTrue(
                abs(city.latitude) <= 90,
                "\(city.name) has invalid latitude: \(city.latitude)"
            )
        }
    }

    func test_allCities_haveValidLongitude() {
        for city in AirQualityProvider.cities {
            XCTAssertTrue(
                abs(city.longitude) <= 180,
                "\(city.name) has invalid longitude: \(city.longitude)"
            )
        }
    }

    func test_allCities_haveNonEmptyName() {
        for city in AirQualityProvider.cities {
            XCTAssertFalse(city.name.isEmpty, "Found a city with an empty name")
        }
    }

    func test_feedType_isAirQuality() {
        XCTAssertEqual(AirQualityProvider().feedType, .airQuality)
    }
}
