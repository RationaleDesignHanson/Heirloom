// components/FeatureGrid.tsx

import Image from 'next/image'

const features = [
  {
    icon: '📱',
    title: 'Smart Recipe Import',
    description: 'Web scraping for 500+ sites, OCR for cookbook scanning, and smart ingredient parsing.',
    image: '/images/work/heirloom/feature-import.png',
  },
  {
    icon: '🛒',
    title: 'iOS Reminders Integration',
    description: 'Export shopping lists as Grocery type, auto-categorized by aisle, with cross-device sync.',
    image: '/images/work/heirloom/feature-shopping.png',
  },
  {
    icon: '🎨',
    title: 'Card Personalization',
    description: '12 vintage backgrounds, 50+ hand-drawn stickers, and handwritten annotations.',
    image: '/images/work/heirloom/feature-personalization.png',
  },
  {
    icon: '📤',
    title: 'CloudKit Sharing',
    description: 'Styled cards preserve customization with provenance tracking ("Shared by Mom").',
    image: '/images/work/heirloom/feature-sharing.png',
  },
  {
    icon: '🍽️',
    title: 'Dinner Party Mode',
    description: 'Multi-recipe meal planning with smart cooking timelines and auto-scaled ingredients.',
    image: '/images/work/heirloom/feature-dinnerparty.png',
  },
  {
    icon: '🔒',
    title: 'Privacy-First Design',
    description: 'On-device processing (80-90%), no data selling or ads, and optional iCloud sync.',
    image: '/images/work/heirloom/feature-privacy.png',
  },
]

export default function FeatureGrid() {
  return (
    <section className="bg-gray-50 py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        {/* Section Header */}
        <div className="mx-auto mb-16 max-w-3xl text-center">
          <h2 className="mb-6 text-4xl font-bold text-[#2D2D2D] md:text-5xl">
            Key Features
          </h2>
          <p className="text-xl text-gray-700">
            Everything you need to preserve family recipes as beautiful, shareable artifacts.
          </p>
        </div>

        {/* Feature Grid */}
        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
          {features.map((feature, index) => (
            <div
              key={index}
              className="group relative overflow-hidden rounded-2xl bg-white p-8 shadow-sm transition-all hover:shadow-xl"
            >
              {/* Icon */}
              <div className="mb-4 text-5xl">{feature.icon}</div>

              {/* Title */}
              <h3 className="mb-3 text-2xl font-bold text-[#2D2D2D]">
                {feature.title}
              </h3>

              {/* Description */}
              <p className="mb-6 leading-relaxed text-gray-700">
                {feature.description}
              </p>

              {/* Screenshot (optional - if you have the image) */}
              {/* Uncomment when you have the images
              <div className="relative h-48 overflow-hidden rounded-lg">
                <Image
                  src={feature.image}
                  alt={feature.title}
                  fill
                  className="object-cover transition-transform group-hover:scale-105"
                />
              </div>
              */}

              {/* Hover Accent */}
              <div className="absolute bottom-0 left-0 h-1 w-0 bg-[#E85D4D] transition-all group-hover:w-full"></div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
