// components/ProjectOverview.tsx

export default function ProjectOverview() {
  return (
    <section className="bg-white py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        <div className="mx-auto max-w-4xl">
          {/* Section Title */}
          <h2 className="mb-12 text-4xl font-bold text-[#2D2D2D] md:text-5xl">
            Overview
          </h2>

          {/* Description */}
          <div className="prose prose-lg mb-16 max-w-none text-gray-700">
            <p>
              Heirloom reimagines recipe management for families who want to preserve their
              culinary heritage. Unlike traditional recipe apps that treat recipes as
              spreadsheet data, Heirloom enables users to personalize recipe cards with
              vintage backgrounds, hand-drawn stickers, and handwritten notes—all of which
              are preserved when shared.
            </p>
            <p>
              The app was built from the ground up as a native iOS experience, leveraging
              SwiftUI, SwiftData, and CloudKit for seamless sync and sharing. Key features
              include smart shopping lists with iOS Reminders integration, OCR-powered
              cookbook scanning, and dinner party mode with automatic cooking timelines.
            </p>
          </div>

          {/* Key Metrics Grid */}
          <div className="grid gap-8 md:grid-cols-3">
            <div className="group rounded-2xl border border-gray-200 p-8 transition-all hover:border-[#E85D4D] hover:shadow-lg">
              <div className="mb-3 text-5xl font-bold text-[#E85D4D]">5</div>
              <div className="text-sm font-semibold uppercase tracking-wide text-gray-500">Weeks</div>
              <div className="mt-2 text-gray-700">MVP to TestFlight</div>
            </div>

            <div className="group rounded-2xl border border-gray-200 p-8 transition-all hover:border-[#E85D4D] hover:shadow-lg">
              <div className="mb-3 text-5xl font-bold text-[#E85D4D]">500+</div>
              <div className="text-sm font-semibold uppercase tracking-wide text-gray-500">Sites</div>
              <div className="mt-2 text-gray-700">Recipe import compatibility</div>
            </div>

            <div className="group rounded-2xl border border-gray-200 p-8 transition-all hover:border-[#E85D4D] hover:shadow-lg">
              <div className="mb-3 text-5xl font-bold text-[#E85D4D]">$4.99</div>
              <div className="text-sm font-semibold uppercase tracking-wide text-gray-500">One-Time</div>
              <div className="mt-2 text-gray-700">Premium unlock, no subscription</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
