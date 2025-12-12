// prototypes/CardCustomizationDemo.tsx
// Interactive prototype: Recipe card customization with stickers and backgrounds

'use client'

import { useState } from 'react'
import Image from 'next/image'

const backgrounds = [
  { id: 'cream', name: 'Cream', color: '#FBF8F3', texture: 'none' },
  { id: 'parchment', name: 'Parchment', color: '#F5E6D3', texture: 'paper' },
  { id: 'linen', name: 'Linen', color: '#EDE9E4', texture: 'linen' },
  { id: 'floral', name: 'Floral', color: '#FFF9F5', texture: 'floral' },
]

const stickers = [
  { id: 'tomato', emoji: '🍅', name: 'Tomato' },
  { id: 'garlic', emoji: '🧄', name: 'Garlic' },
  { id: 'heart', emoji: '❤️', name: 'Heart' },
  { id: 'star', emoji: '⭐', name: 'Star' },
  { id: 'spoon', emoji: '🥄', name: 'Spoon' },
  { id: 'cookie', emoji: '🍪', name: 'Cookie' },
]

interface PlacedSticker {
  id: string
  emoji: string
  x: number
  y: number
}

export default function CardCustomizationDemo() {
  const [selectedBackground, setSelectedBackground] = useState(backgrounds[0])
  const [placedStickers, setPlacedStickers] = useState<PlacedSticker[]>([])
  const [annotation, setAnnotation] = useState('')

  const addSticker = (sticker: typeof stickers[0]) => {
    // Add sticker at random position on card
    const randomX = Math.random() * 60 + 20 // 20-80%
    const randomY = Math.random() * 60 + 20

    setPlacedStickers([
      ...placedStickers,
      {
        id: `${sticker.id}-${Date.now()}`,
        emoji: sticker.emoji,
        x: randomX,
        y: randomY,
      },
    ])
  }

  const removeSticker = (id: string) => {
    setPlacedStickers(placedStickers.filter((s) => s.id !== id))
  }

  const clearAll = () => {
    setPlacedStickers([])
    setAnnotation('')
  }

  return (
    <div className="mx-auto max-w-6xl">
      <div className="grid gap-8 lg:grid-cols-[2fr,1fr]">
        {/* Recipe Card Preview */}
        <div className="relative">
          <div className="text-sm font-semibold text-gray-500 mb-3">RECIPE CARD PREVIEW</div>

          <div
            className="relative aspect-[3/4] overflow-hidden rounded-2xl shadow-2xl transition-colors duration-300"
            style={{ backgroundColor: selectedBackground.color }}
          >
            {/* Background texture overlay */}
            {selectedBackground.texture === 'paper' && (
              <div className="absolute inset-0 opacity-5 bg-[repeating-linear-gradient(0deg,transparent,transparent_2px,#000_2px,#000_4px)]" />
            )}
            {selectedBackground.texture === 'linen' && (
              <div className="absolute inset-0 opacity-3 bg-[repeating-linear-gradient(45deg,transparent,transparent_2px,#000_2px,#000_3px)]" />
            )}

            {/* Recipe Content */}
            <div className="absolute inset-0 p-8">
              <h2 className="text-3xl font-bold text-[#2D2D2D] mb-6" style={{ fontFamily: 'Georgia, serif' }}>
                Grandma's Chocolate Chip Cookies
              </h2>

              <div className="space-y-4 text-[#2D2D2D]">
                <div>
                  <div className="text-sm font-semibold text-gray-600 mb-2">INGREDIENTS</div>
                  <ul className="space-y-1 text-sm">
                    <li>• 2¼ cups all-purpose flour</li>
                    <li>• 1 cup butter, softened</li>
                    <li>• ¾ cup sugar</li>
                    <li>• 2 eggs</li>
                    <li>• 2 cups chocolate chips</li>
                  </ul>
                </div>

                <div className="border-t border-gray-300 pt-4">
                  <div className="text-xs text-gray-500">
                    Prep: 15 min · Cook: 12 min · Yields: 48 cookies
                  </div>
                </div>
              </div>

              {/* Handwritten Annotation */}
              {annotation && (
                <div
                  className="absolute bottom-8 left-8 right-8 p-3 bg-yellow-100/80 rounded-lg border-l-4 border-yellow-400"
                  style={{ fontFamily: 'Caveat, cursive', fontSize: '1.2rem' }}
                >
                  {annotation}
                </div>
              )}

              {/* Placed Stickers */}
              {placedStickers.map((sticker) => (
                <div
                  key={sticker.id}
                  className="absolute cursor-pointer transition-transform hover:scale-110"
                  style={{
                    left: `${sticker.x}%`,
                    top: `${sticker.y}%`,
                    fontSize: '3rem',
                  }}
                  onClick={() => removeSticker(sticker.id)}
                  title="Click to remove"
                >
                  {sticker.emoji}
                </div>
              ))}
            </div>
          </div>

          <div className="mt-4 text-sm text-gray-500 text-center">
            Click stickers to remove them
          </div>
        </div>

        {/* Customization Panel */}
        <div className="space-y-6">
          {/* Background Selector */}
          <div>
            <div className="text-sm font-semibold text-gray-700 mb-3">BACKGROUND</div>
            <div className="grid grid-cols-2 gap-2">
              {backgrounds.map((bg) => (
                <button
                  key={bg.id}
                  onClick={() => setSelectedBackground(bg)}
                  className={`aspect-square rounded-lg border-2 transition-all ${
                    selectedBackground.id === bg.id
                      ? 'border-[#E85D4D] ring-2 ring-[#E85D4D]/20'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                  style={{ backgroundColor: bg.color }}
                  title={bg.name}
                >
                  <span className="sr-only">{bg.name}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Sticker Picker */}
          <div>
            <div className="text-sm font-semibold text-gray-700 mb-3">STICKERS</div>
            <div className="grid grid-cols-3 gap-2">
              {stickers.map((sticker) => (
                <button
                  key={sticker.id}
                  onClick={() => addSticker(sticker)}
                  className="aspect-square flex items-center justify-center text-4xl rounded-lg border-2 border-gray-200 bg-white transition-all hover:border-[#E85D4D] hover:scale-105 active:scale-95"
                  title={`Add ${sticker.name}`}
                >
                  {sticker.emoji}
                </button>
              ))}
            </div>
          </div>

          {/* Annotation Input */}
          <div>
            <div className="text-sm font-semibold text-gray-700 mb-3">HANDWRITTEN NOTE</div>
            <textarea
              value={annotation}
              onChange={(e) => setAnnotation(e.target.value)}
              placeholder="Add more garlic!"
              className="w-full rounded-lg border-2 border-gray-200 p-3 text-sm focus:border-[#E85D4D] focus:outline-none"
              rows={3}
              style={{ fontFamily: 'Caveat, cursive', fontSize: '1.1rem' }}
            />
          </div>

          {/* Actions */}
          <div className="space-y-2">
            <button
              onClick={clearAll}
              className="w-full rounded-lg border-2 border-gray-300 bg-white px-4 py-2 text-sm font-semibold text-gray-700 transition-colors hover:bg-gray-50"
            >
              Clear All
            </button>
            <div className="text-xs text-gray-500 text-center">
              Stickers: {placedStickers.length} added
            </div>
          </div>
        </div>
      </div>

      {/* Instructions */}
      <div className="mt-8 rounded-xl bg-[#FBF8F3] p-6">
        <h4 className="mb-3 font-semibold text-[#2D2D2D]">Try it:</h4>
        <ul className="space-y-2 text-sm text-gray-700">
          <li>• Select a background color above</li>
          <li>• Click stickers to add them to the card (random position)</li>
          <li>• Click placed stickers to remove them</li>
          <li>• Type a handwritten note in the annotation box</li>
          <li>• In the real app, stickers are draggable and can be resized</li>
        </ul>
      </div>
    </div>
  )
}
