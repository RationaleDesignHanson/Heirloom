// components/ChallengeSection.tsx

import Image from 'next/image'

export default function ChallengeSection() {
  return (
    <section className="bg-gray-50 py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        <div className="mx-auto max-w-4xl">
          <h2 className="mb-12 text-4xl font-bold text-[#2D2D2D] md:text-5xl">
            The Challenge
          </h2>

          <div className="mb-16 space-y-8">
            <div>
              <h3 className="mb-4 text-2xl font-bold text-[#E85D4D]">
                PROBLEM
              </h3>
              <div className="prose prose-lg max-w-none text-gray-700">
                <p className="mb-4">Recipe apps treat recipes like data:</p>
                <ul className="list-disc space-y-2 pl-6">
                  <li>Plain text ingredients and instructions</li>
                  <li>No personality or context</li>
                  <li>Shared recipes lose all customization</li>
                  <li>No connection to family heritage</li>
                </ul>
                <p className="mt-6">
                  Existing apps like Paprika and Mealboard focus on organization and efficiency,
                  but they strip away the warmth and stories that make recipes meaningful.
                </p>
              </div>
            </div>

            <div>
              <h3 className="mb-4 text-2xl font-bold text-[#8B9F8D]">
                OPPORTUNITY
              </h3>
              <div className="prose prose-lg max-w-none text-gray-700">
                <p>
                  Families want to preserve recipes as heirlooms—not just functional cooking
                  instructions, but artifacts that carry stories, notes, and memories.
                </p>
                <p className="mt-4">
                  <strong>Our insight:</strong> The details matter. Coffee stains, handwritten notes, worn edges—
                  these aren't imperfections. They're part of the story.
                </p>
              </div>
            </div>
          </div>

          {/* Visual Comparison (optional - if you have images) */}
          <div className="grid gap-6 md:grid-cols-2">
            <div className="rounded-xl border-2 border-gray-300 p-6">
              <div className="mb-3 text-sm font-semibold uppercase tracking-wide text-gray-500">
                Other Apps
              </div>
              <div className="flex h-64 items-center justify-center bg-gray-200 text-gray-500">
                [Screenshot: Generic recipe app UI]
              </div>
              <p className="mt-4 text-sm text-gray-600">Sterile lists. No personality. Data only.</p>
            </div>

            <div className="rounded-xl border-2 border-[#E85D4D] p-6">
              <div className="mb-3 text-sm font-semibold uppercase tracking-wide text-[#E85D4D]">
                Heirloom
              </div>
              <div className="flex h-64 items-center justify-center bg-[#FBF8F3] text-gray-500">
                [Screenshot: Heirloom personalized card]
              </div>
              <p className="mt-4 text-sm text-gray-600">Warm, styled, personal. The full experience.</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
