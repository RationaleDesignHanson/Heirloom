import XCTest
@testable import Heirloom

/// Tests for URLNormalizer utility
/// Covers URL normalization, duplicate detection, validation, and extraction
final class URLNormalizerTests: XCTestCase {

    // MARK: - Normalization Tests

    func test_normalize_removesQueryParameters() {
        let url = "https://example.com/recipe?utm_source=email"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://example.com/recipe")
    }

    func test_normalize_removesFragment() {
        let url = "https://example.com/recipe#comments"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://example.com/recipe")
    }

    func test_normalize_removesTrailingSlash() {
        let url = "https://example.com/recipe/"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://example.com/recipe")
    }

    func test_normalize_convertsToLowercase() {
        let url = "https://Example.COM/Recipe"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://example.com/recipe")
    }

    func test_normalize_convertsHTTPToHTTPS() {
        let url = "http://example.com/recipe"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://example.com/recipe")
    }

    func test_normalize_removesInvisibleCharacters() {
        let url = "https://example.com/recipe\u{200B}" // Zero-width space
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://example.com/recipe")
    }

    func test_normalize_trimsWhitespace() {
        let url = "  https://example.com/recipe  "
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://example.com/recipe")
    }

    func test_normalize_returnsNilForInvalidURL() {
        let url = "not a url"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertNil(normalized)
    }

    func test_normalize_handlesComplexURL() {
        let url = "HTTP://WWW.Example.COM/recipe?source=email&id=123#section/"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://www.example.com/recipe")
    }

    // MARK: - Duplicate Detection Tests

    func test_areDuplicates_sameURLAfterNormalization() {
        let url1 = "https://example.com/recipe"
        let url2 = "https://example.com/recipe?utm_source=email"

        XCTAssertTrue(URLNormalizer.areDuplicates(url1, url2))
    }

    func test_areDuplicates_caseInsensitive() {
        let url1 = "https://example.com/Recipe"
        let url2 = "https://EXAMPLE.COM/recipe"

        XCTAssertTrue(URLNormalizer.areDuplicates(url1, url2))
    }

    func test_areDuplicates_differentPaths() {
        let url1 = "https://example.com/recipe1"
        let url2 = "https://example.com/recipe2"

        XCTAssertFalse(URLNormalizer.areDuplicates(url1, url2))
    }

    func test_areDuplicates_trailingSlashIgnored() {
        let url1 = "https://example.com/recipe"
        let url2 = "https://example.com/recipe/"

        XCTAssertTrue(URLNormalizer.areDuplicates(url1, url2))
    }

    func test_areDuplicates_invalidURLReturnsFalse() {
        let url1 = "https://example.com/recipe"
        let url2 = "not a url"

        XCTAssertFalse(URLNormalizer.areDuplicates(url1, url2))
    }

    // MARK: - Domain Extraction Tests

    func test_extractDomain_basic() {
        let url = "https://nytimes.com/cooking/recipe"
        let domain = URLNormalizer.extractDomain(url)

        XCTAssertEqual(domain, "nytimes.com")
    }

    func test_extractDomain_removesWWW() {
        let url = "https://www.nytimes.com/cooking/recipe"
        let domain = URLNormalizer.extractDomain(url)

        XCTAssertEqual(domain, "nytimes.com")
    }

    func test_extractDomain_withSubdomain() {
        let url = "https://cooking.nytimes.com/recipe"
        let domain = URLNormalizer.extractDomain(url)

        XCTAssertEqual(domain, "cooking.nytimes.com")
    }

    func test_extractDomain_returnsNilForInvalidURL() {
        let url = "not a url"
        let domain = URLNormalizer.extractDomain(url)

        XCTAssertNil(domain)
    }

    // MARK: - Validation Tests

    func test_isValidForImport_validURL() {
        let url = "https://example.com/recipe/chocolate-chip-cookies"

        XCTAssertTrue(URLNormalizer.isValidForImport(url))
    }

    func test_isValidForImport_requiresPath() {
        let url = "https://example.com"

        XCTAssertFalse(URLNormalizer.isValidForImport(url))
    }

    func test_isValidForImport_rootPathNotValid() {
        let url = "https://example.com/"

        XCTAssertFalse(URLNormalizer.isValidForImport(url))
    }

    func test_isValidForImport_requiresHTTPScheme() {
        let url = "ftp://example.com/recipe"

        XCTAssertFalse(URLNormalizer.isValidForImport(url))
    }

    func test_isValidForImport_acceptsHTTP() {
        let url = "http://example.com/recipe"

        XCTAssertTrue(URLNormalizer.isValidForImport(url))
    }

    func test_isValidForImport_requiresHost() {
        let url = "https:///recipe"

        XCTAssertFalse(URLNormalizer.isValidForImport(url))
    }

    func test_isValidForImport_invalidURL() {
        let url = "not a url"

        XCTAssertFalse(URLNormalizer.isValidForImport(url))
    }

    // MARK: - URL Extraction Tests

    func test_extractURLs_singleURL() {
        let text = "https://example.com/recipe"
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first, "https://example.com/recipe")
    }

    func test_extractURLs_multipleURLs() {
        let text = """
        https://example.com/recipe1
        https://example.com/recipe2
        https://example.com/recipe3
        """
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 3)
    }

    func test_extractURLs_addsHTTPSPrefix() {
        let text = "example.com/recipe"
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first, "https://example.com/recipe")
    }

    func test_extractURLs_mixedFormats() {
        let text = """
        https://example.com/recipe1
        example.com/recipe2
        http://example.com/recipe3
        """
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 3)
    }

    func test_extractURLs_ignoresDuplicates() {
        let text = """
        https://example.com/recipe
        https://example.com/recipe?source=email
        """
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 1)
    }

    func test_extractURLs_ignoresInvalidLines() {
        let text = """
        https://example.com/recipe1
        not a url
        https://example.com/recipe2
        another invalid line
        """
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 2)
    }

    func test_extractURLs_handlesEmptyText() {
        let text = ""
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 0)
    }

    func test_extractURLs_ignoresURLsWithoutPath() {
        let text = """
        https://example.com/recipe
        https://example.com
        """
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first, "https://example.com/recipe")
    }

    func test_extractURLs_handlesWhitespaceAndFormatting() {
        let text = """

        https://example.com/recipe1

        https://example.com/recipe2

        """
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 2)
    }

    // MARK: - Real-World Scenarios

    func test_realWorld_nytCookingURL() {
        let url = "https://cooking.nytimes.com/recipes/1024647-chocolate-chip-cookies?action=click&module=Collection"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://cooking.nytimes.com/recipes/1024647-chocolate-chip-cookies")
        XCTAssertTrue(URLNormalizer.isValidForImport(url))
    }

    func test_realWorld_allRecipesURL() {
        let url = "https://www.allrecipes.com/recipe/25037/best-chocolate-chip-cookies/?internalSource=hub%20recipe"
        let normalized = URLNormalizer.normalize(url)

        XCTAssertEqual(normalized, "https://www.allrecipes.com/recipe/25037/best-chocolate-chip-cookies")
        XCTAssertTrue(URLNormalizer.isValidForImport(url))
    }

    func test_realWorld_copyPastedList() {
        let text = """
        My recipe URLs:

        https://cooking.nytimes.com/recipes/1024647-chocolate-chip-cookies
        allrecipes.com/recipe/25037/best-chocolate-chip-cookies/
        https://www.bonappetit.com/recipe/bas-best-chocolate-chip-cookies

        Those are my favorites!
        """
        let urls = URLNormalizer.extractURLs(from: text)

        XCTAssertEqual(urls.count, 3)
        XCTAssertTrue(urls.allSatisfy { URLNormalizer.isValidForImport($0) })
    }
}
