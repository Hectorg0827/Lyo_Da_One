import XCTest
@testable import Lyo

/// The credit line a library video must show. `discover-attribution.test.mjs`
/// and `ClipAttributionTest.kt` assert the same rules for web and Android.
final class ClipAttributionTests: XCTestCase {

    func testTheServersCreditIsShownAsItIs() {
        let credit = ClipAttribution(credit: "NASA/JPL-Caltech · Public domain", sourceName: nil,
                                     sourceURL: nil, license: "Public domain", licenseURL: nil)
        XCTAssertEqual(credit.displayLine, "NASA/JPL-Caltech · Public domain")
    }

    func testTheLicenceIsAddedWhenTheCreditDoesNotNameIt() {
        let credit = ClipAttribution(credit: "Jane Doe", sourceName: nil, sourceURL: nil,
                                     license: "CC BY 4.0", licenseURL: nil)
        XCTAssertEqual(credit.displayLine, "Jane Doe · CC BY 4.0")
    }

    func testWithoutACreditTheSourceAndLicenceStillShow() {
        let credit = ClipAttribution(credit: nil, sourceName: "Wikimedia Commons", sourceURL: nil,
                                     license: "CC BY-SA 4.0", licenseURL: nil)
        XCTAssertEqual(credit.displayLine, "Wikimedia Commons · CC BY-SA 4.0")
    }

    func testNothingToCreditShowsNothing() {
        XCTAssertNil(ClipAttribution(credit: "  ", sourceName: nil, sourceURL: nil, license: nil, licenseURL: nil).displayLine)
    }

    func testOnlyHttpsSourceLinksAreOpened() {
        XCTAssertNil(ClipAttribution(credit: "X", sourceName: nil, sourceURL: "javascript:alert(1)", license: nil, licenseURL: nil).sourceLink)
        XCTAssertNil(ClipAttribution(credit: "X", sourceName: nil, sourceURL: "http://example.com", license: nil, licenseURL: nil).sourceLink)
        XCTAssertEqual(ClipAttribution(credit: "X", sourceName: nil, sourceURL: "https://images.nasa.gov/details/X",
                                       license: nil, licenseURL: nil).sourceLink?.absoluteString,
                       "https://images.nasa.gov/details/X")
    }

    func testTheDiscoverFeedDecodesAttributionAndSurvivesABadOne() throws {
        let json = """
        {"id": "7", "userId": 3, "title": "Rover landing", "createdAt": "2026-10-21T12:00:00Z",
         "attribution": {"credit": "NASA/JPL", "sourceName": "NASA Image and Video Library",
                         "sourceURL": "https://images.nasa.gov/details/X", "license": "Public domain",
                         "licenseURL": "https://www.nasa.gov/"}}
        """
        let clip = try JSONDecoder().decode(Discovery.self, from: Data(json.utf8))
        XCTAssertEqual(clip.attribution?.displayLine, "NASA/JPL · Public domain")

        let malformed = """
        {"id": 8, "userId": 3, "title": "Own clip", "attribution": "not an object"}
        """
        XCTAssertNil(try JSONDecoder().decode(Discovery.self, from: Data(malformed.utf8)).attribution)
    }
}
