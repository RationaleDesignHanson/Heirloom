// components/PrototypeEmbed.tsx

'use client'

import { useState } from 'react'

export default function PrototypeEmbed() {
  const [isLoaded, setIsLoaded] = useState(false)

  // Replace with your actual Figma prototype URL
  const figmaEmbedUrl = 'https://www.figma.com/embed?embed_host=share&url=YOUR_FIGMA_PROTOTYPE_URL'

  return (
    <section id="prototype" className="bg-white py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        {/* Section Header */}
        <div className="mx-auto mb-12 max-w-3xl text-center">
          <h2 className="mb-6 text-4xl font-bold text-[#2D2D2D] md:text-5xl">
            Try It Yourself
          </h2>
          <p className="text-xl text-gray-700">
            Explore Heirloom's key features in this interactive prototype. No download required.
          </p>
        </div>

        {/* Prototype Embed */}
        <div className="mx-auto max-w-6xl">
          <div className="relative overflow-hidden rounded-2xl border-4 border-gray-200 shadow-2xl">
            {/* Loading State */}
            {!isLoaded && (
              <div className="flex h-[800px] items-center justify-center bg-gray-100">
                <div className="text-center">
                  <div className="mb-4 inline-block h-12 w-12 animate-spin rounded-full border-4 border-gray-300 border-t-[#E85D4D]"></div>
                  <p className="text-gray-600">Loading interactive prototype...</p>
                </div>
              </div>
            )}

            {/* Figma Embed */}
            <iframe
              src={figmaEmbedUrl}
              width="100%"
              height="800"
              allowFullScreen
              onLoad={() => setIsLoaded(true)}
              className={isLoaded ? 'block' : 'hidden'}
              title="Heirloom Interactive Prototype"
            />
          </div>

          {/* Instructions */}
          <div className="mt-8 rounded-xl bg-[#FBF8F3] p-6">
            <h4 className="mb-3 font-semibold text-[#2D2D2D]">
              How to use the prototype:
            </h4>
            <ul className="space-y-2 text-gray-700">
              <li className="flex items-start gap-2">
                <span className="text-[#E85D4D]">1.</span>
                <span>Click on any recipe card to view details</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-[#E85D4D]">2.</span>
                <span>Try the "Customize Card" button to add stickers and backgrounds</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-[#E85D4D]">3.</span>
                <span>Navigate to the Shopping tab to see ingredient aggregation</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="text-[#E85D4D]">4.</span>
                <span>Check out Dinner Party mode for multi-recipe meal planning</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  )
}
