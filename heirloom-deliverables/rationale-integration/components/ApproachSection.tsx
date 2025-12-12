// components/ApproachSection.tsx

export default function ApproachSection() {
  return (
    <section className="bg-white py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-12 text-4xl font-bold text-[#2D2D2D] md:text-5xl">
            Our Approach
          </h2>

          <div className="prose prose-lg mb-16 max-w-none text-gray-700">
            <p className="text-xl font-medium text-[#2D2D2D]">
              We built Heirloom around three core principles:
            </p>
          </div>

          <div className="space-y-12">
            {/* Principle 1 */}
            <div className="border-l-4 border-[#E85D4D] pl-8">
              <h3 className="mb-4 text-2xl font-bold text-[#2D2D2D]">
                1. PRESERVE THE ARTIFACT
              </h3>
              <p className="leading-relaxed text-gray-700">
                Recipe cards aren't just data containers—they're personal objects. We designed
                a card personalization system with vintage backgrounds, hand-drawn stickers,
                and authentic handwriting. When you share a styled card, the recipient sees
                everything you added.
              </p>
            </div>

            {/* Principle 2 */}
            <div className="border-l-4 border-[#F4A460] pl-8">
              <h3 className="mb-4 text-2xl font-bold text-[#2D2D2D]">
                2. SMART UTILITY WITHOUT STERILITY
              </h3>
              <p className="leading-relaxed text-gray-700">
                Great design doesn't mean sacrificing function. Heirloom's shopping list
                aggregation automatically combines ingredients from multiple recipes and exports
                directly to iOS Reminders with grocery categorization—a feature no competitor offers.
              </p>
            </div>

            {/* Principle 3 */}
            <div className="border-l-4 border-[#8B9F8D] pl-8">
              <h3 className="mb-4 text-2xl font-bold text-[#2D2D2D]">
                3. NATIVE-FIRST QUALITY
              </h3>
              <p className="leading-relaxed text-gray-700">
                We committed to a fully native iOS experience using SwiftUI and SwiftData.
                This meant: instant responsiveness, seamless iCloud sync, and iOS 17 feature
                integration (Reminders grocery type, VisionKit OCR, CloudKit sharing).
                <br /><br />
                <strong>No web wrappers. No React Native compromises. Just native.</strong>
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
