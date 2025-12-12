// app/work/heirloom/page.tsx
// Heirloom Case Study - Main Page Component

import { Metadata } from 'next'
import HeroSection from './components/HeroSection'
import ProjectOverview from './components/ProjectOverview'
import ChallengeSection from './components/ChallengeSection'
import ApproachSection from './components/ApproachSection'
import FeatureGrid from './components/FeatureGrid'
import DesignSystem from './components/DesignSystem'
import TechnicalStack from './components/TechnicalStack'
import Timeline from './components/Timeline'
import Outcomes from './components/Outcomes'
import PrototypeEmbed from './components/PrototypeEmbed'
import LessonsLearned from './components/LessonsLearned'
import FinalCTA from './components/FinalCTA'

export const metadata: Metadata = {
  title: 'Heirloom: iOS Recipe App Case Study | Rationale Studios',
  description: 'How we built Heirloom, a native iOS app that preserves family recipes as beautiful, shareable artifacts. Complete product design and development in 5 weeks.',
  keywords: ['iOS app development', 'recipe app', 'SwiftUI', 'product design', 'native app', 'CloudKit', 'Rationale Studios'],
  openGraph: {
    title: 'Heirloom: Recipes Worth Passing Down',
    description: 'Native iOS recipe app with smart shopping lists, card personalization, and dinner party mode. Built by Rationale Studios.',
    images: [
      {
        url: '/images/work/heirloom/og-image.png',
        width: 1200,
        height: 630,
        alt: 'Heirloom iOS App',
      },
    ],
    url: 'https://rationale.work/work/heirloom',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Heirloom Case Study | Rationale Studios',
    description: 'How we built a native iOS recipe app in 5 weeks with SwiftUI, CloudKit, and OCR.',
    images: ['/images/work/heirloom/twitter-card.png'],
  },
}

export default function HeirloomCaseStudy() {
  return (
    <main className="heirloom-case-study">
      {/* Hero with gradient background and device mockup */}
      <HeroSection />

      {/* Quick overview stats and description */}
      <ProjectOverview />

      {/* The problem: recipe apps treat recipes like data */}
      <ChallengeSection />

      {/* Our approach: preserve the artifact, smart utility, native-first */}
      <ApproachSection />

      {/* 6 key features in grid layout */}
      <FeatureGrid />

      {/* Design system showcase: colors, typography, components */}
      <DesignSystem />

      {/* Technical architecture diagram */}
      <TechnicalStack />

      {/* 5-week development timeline */}
      <Timeline />

      {/* Results and target metrics */}
      <Outcomes />

      {/* Interactive Figma prototype embed */}
      <PrototypeEmbed />

      {/* 3 lessons learned in columns */}
      <LessonsLearned />

      {/* Final CTA: Work with us */}
      <FinalCTA />

      {/* Structured data for SEO */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            '@context': 'https://schema.org',
            '@type': 'CreativeWork',
            name: 'Heirloom: iOS Recipe App',
            description: 'A native iOS app for preserving and sharing family recipes with smart shopping lists and card personalization.',
            creator: {
              '@type': 'Organization',
              name: 'Rationale Studios',
              url: 'https://rationale.work',
            },
            image: 'https://rationale.work/images/work/heirloom/hero-mockup.png',
            url: 'https://rationale.work/work/heirloom',
            datePublished: '2025-01-01',
            keywords: 'iOS app, recipe app, SwiftUI, product design, native development',
          }),
        }}
      />
    </main>
  )
}
