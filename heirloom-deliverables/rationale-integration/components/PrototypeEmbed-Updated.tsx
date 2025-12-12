// components/PrototypeEmbed.tsx
// UPDATED: Uses actual interactive prototypes instead of Figma

'use client'

import { useState } from 'react'
import CardCustomizationDemo from '../prototypes/CardCustomizationDemo'
import ShoppingListDemo from '../prototypes/ShoppingListDemo'

const demos = [
  { id: 'customization', name: 'Card Customization', icon: '🎨' },
  { id: 'shopping', name: 'Shopping List', icon: '🛒' },
]

export default function PrototypeEmbed() {
  const [activeDemo, setActiveDemo] = useState('customization')

  return (
    <section id="prototype" className="bg-white py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        {/* Section Header */}
        <div className="mx-auto mb-12 max-w-3xl text-center">
          <h2 className="mb-6 text-4xl font-bold text-[#2D2D2D] md:text-5xl">
            Try It Yourself
          </h2>
          <p className="text-xl text-gray-700">
            Explore Heirloom's key features in these interactive prototypes. No download required.
          </p>
        </div>

        {/* Tab Navigation */}
        <div className="mx-auto mb-8 max-w-6xl">
          <div className="flex flex-wrap gap-3 justify-center">
            {demos.map((demo) => (
              <button
                key={demo.id}
                onClick={() => setActiveDemo(demo.id)}
                className={`flex items-center gap-2 rounded-full px-6 py-3 font-semibold transition-all ${
                  activeDemo === demo.id
                    ? 'bg-[#E85D4D] text-white shadow-lg'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                <span className="text-xl">{demo.icon}</span>
                <span>{demo.name}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Demo Container */}
        <div className="mx-auto max-w-6xl">
          <div className="rounded-2xl border-2 border-gray-200 bg-gray-50 p-8 md:p-12">
            {activeDemo === 'customization' && <CardCustomizationDemo />}
            {activeDemo === 'shopping' && <ShoppingListDemo />}
          </div>
        </div>
      </div>
    </section>
  )
}
