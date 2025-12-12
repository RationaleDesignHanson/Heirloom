// components/FinalCTA.tsx

import Link from 'next/link'

export default function FinalCTA() {
  return (
    <section className="bg-gradient-to-br from-[#E85D4D] to-[#d54d3d] py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        <div className="mx-auto max-w-4xl text-center text-white">
          {/* Headline */}
          <h2 className="mb-6 text-4xl font-bold md:text-5xl lg:text-6xl">
            Want to Build Your Own Product?
          </h2>

          {/* Description */}
          <p className="mb-12 text-xl leading-relaxed opacity-95 md:text-2xl">
            Rationale Studios helps founders and teams design, develop, and launch products that users love.
            <br />
            <span className="font-semibold">From idea to App Store in 5-12 weeks.</span>
          </p>

          {/* CTAs */}
          <div className="flex flex-wrap justify-center gap-6">
            <Link
              href="/contact"
              className="inline-flex items-center gap-2 rounded-full bg-white px-10 py-5 text-lg font-semibold text-[#E85D4D] shadow-xl transition-all hover:scale-105 hover:shadow-2xl"
            >
              Work With Us
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            </Link>

            <Link
              href="/work"
              className="inline-flex items-center gap-2 rounded-full border-2 border-white px-10 py-5 text-lg font-semibold text-white transition-all hover:bg-white hover:text-[#E85D4D]"
            >
              See More Work
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
              </svg>
            </Link>
          </div>

          {/* Sub-text */}
          <p className="mt-12 text-sm opacity-80">
            Native iOS · Product Design · From MVP to Scale
          </p>
        </div>
      </div>
    </section>
  )
}
