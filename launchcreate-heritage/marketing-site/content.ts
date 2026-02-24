export type FAQItem = { q: string; a: string };
export type FeatureItem = { title: string; body: string; icon?: string };
export type StepItem = { title: string; body?: string };
export type TechPillarItem = { title: string; body: string; detail: string; icon: string };
export type ComparisonRowItem = { feature: string; heirloom: boolean | string; others: boolean | string };
export type TeamMemberItem = { name: string; role: string; bio: string; skills?: string[] };
export type MetricItem = { value: string; label: string };
export type Hero = {
  h1: string;
  subhead: string;
  primaryCta: { label: string; href: string };
  secondaryCta?: { label: string; href: string };
  emailCapture?: { formName: string; placeholder?: string; buttonLabel?: string };
  trustLine?: string;
  demo: { video: string; poster: string; alt: string; aspect: "16:9" | "9:16" };
};

export type PageSection =
  | { kind: "steps"; id: string; title: string; items: StepItem[] }
  | {
      kind: "problemSolution";
      id: string;
      title: string;
      problem: { title: string; body: string; bullets?: string[] };
      solution: { title: string; body: string; bullets?: string[] };
    }
  | {
      kind: "featureGrid";
      id: string;
      title: string;
      items: FeatureItem[];
      columns?: 3 | 4;
    }
  | {
      kind: "socialProof";
      id: string;
      title: string;
      ratingLabel?: string;
      items: { quote: string; name?: string }[];
    }
  | {
      kind: "testimonials";
      id: string;
      title: string;
      items: { quote: string; name?: string }[];
    }
  | {
      kind: "pricingCredits";
      id: string;
      title: string;
      subtitle?: string;
      trialCreditsIncluded?: number;
      premiumMonthlyCredits?: number;
      creditExamples: { label: string; cost: number; note?: string }[];
      plans: {
        title: string;
        price: string;
        trial?: string;
        highlight?: boolean;
        bullets: string[];
      }[];
    }
  | { kind: "faq"; id: string; title: string; items: FAQItem[] }
  | {
      kind: "cta";
      id: string;
      title: string;
      body?: string;
      cta: { label: string; href: string };
      emailCapture?: { formName: string; placeholder?: string; buttonLabel?: string };
    }
  | { kind: "trustBar"; id: string; items: string[] }
  | { kind: "techShowcase"; id: string; title: string; subtitle?: string; items: TechPillarItem[] }
  | { kind: "comparisonTable"; id: string; title: string; subtitle?: string; rows: ComparisonRowItem[] }
  | { kind: "teamSection"; id: string; title: string; subtitle?: string; members: TeamMemberItem[] }
  | { kind: "metricsBar"; id: string; items: MetricItem[] };

export type MarketingPage = {
  meta: { title: string; description: string };
  nav: { label: string; href: string }[];
  hero: Hero;
  sections: PageSection[];
  variants?: Record<
    string,
    Partial<{
      hero: Partial<Hero>;
      sections: PageSection[];
    }>
  >;
};

export const brand = {
  productNameFull: "Heirloom Recipe Box",
  productNameShort: "Heirloom",
  appStoreTitle: "Heirloom: Recipe Box",
  appStoreSubtitle: "Preserve your family's recipes",
};

export const urls = {
  appStore: "#",
  download: "#download",
  lpVideo: "/lp/video",
  lpScan: "/lp/scan",
  lpGenerate: "/lp/generate",
  lpShare: "/lp/share",
  about: "/about",
  technology: "/technology",
  support: "/support",
  community: "/community",
  presskit: "/presskit",
  privacy: "/privacy",
  terms: "/terms",
};

const sharedNav = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Video", href: urls.lpVideo },
  { label: "Scan", href: urls.lpScan },
  { label: "Generate", href: urls.lpGenerate },
  { label: "Share", href: urls.lpShare },
  { label: "Technology", href: urls.technology },
  { label: "About", href: urls.about },
];

const sharedFAQs: FAQItem[] = [
  {
    q: "Does it work from the Share Sheet?",
    a: "Yes—saving from the Share Sheet is the core of Heirloom Recipe Box.",
  },
  {
    q: "Are my recipes public?",
    a: "No. Your Recipe Box is private by default. Sharing and publishing are optional.",
  },
  {
    q: "Can I share recipes with friends?",
    a: "Yes—send recipes directly, and they can tap to accept into their Recipe Box.",
  },
  {
    q: "How do credits and Heritage work?",
    a: "Some imports use credits. Your trial starts with 50 credits, and Heritage includes 100 credits/month. You can also buy credit packs ($5 for 25, $15 for 100) when you need a burst.",
  },
  {
    q: "Is saving from websites free?",
    a: "Yes. Save from Safari with one tap using the Share Sheet. Heritage unlocks advanced preservation features like cookbook scanning, cloud sync, and voice capture.",
  },
];

const sharedPricingSection: PageSection = {
  kind: "pricingCredits",
  id: "pricing",
  title: "Heritage-grade preservation. Start free.",
  subtitle:
    "Your trial starts with 50 credits. Heritage includes 100 credits/month — plus credit packs ($5 for 25, $15 for 100) when you need a burst.",
  trialCreditsIncluded: 50,
  premiumMonthlyCredits: 100,
  creditExamples: [
    { label: "Text-rich PDF import", cost: 1, note: "Fast processing" },
    { label: "Scanned PDF import", cost: 5, note: "Vision OCR" },
    { label: "Video import (audio)", cost: 1, note: "On-device transcription" },
    { label: "Video import (ASMR)", cost: 5, note: "Vision-based extraction" },
  ],
  plans: [
    {
      title: "Heritage Monthly",
      price: "$6.99 / month",
      trial: "7-day trial",
      bullets: ["Full preservation suite", "Cancel anytime", "Best for short bursts"],
    },
    {
      title: "Heritage Annual",
      price: "$39.99 / year",
      trial: "14-day trial",
      highlight: true,
      bullets: ["Full preservation suite", "Best value — save 52%", "Cancel anytime"],
    },
    {
      title: "Founding Member Lifetime",
      price: "$149 once",
      bullets: ["Full preservation suite forever", "No subscription ever", "Founding Member pricing"],
    },
  ],
};

const sharedProblemSolution: PageSection = {
  kind: "problemSolution",
  id: "problem-solution",
  title: "73% of family recipes are lost within one generation",
  problem: {
    title: "The crisis",
    body: "Family recipes are scattered across 8+ surfaces — screenshots, texts, bookmarks, handwritten cards, and saved videos. When the keeper passes, the recipes vanish.",
    bullets: ["Recipes lost when platforms change", "Handwritten cards fade and get lost", "No backup for grandma's instructions"],
  },
  solution: {
    title: "The Heirloom way",
    body: "One tap from wherever you find recipes — then preserve them forever with attribution, provenance, and heritage-grade archiving.",
    bullets: ["Capture → Preserve → Share", "Track where every recipe comes from", "Private by default, always"],
  },
};

const sharedSocialProof: PageSection = {
  kind: "socialProof",
  id: "social-proof",
  title: "Made for families who cook",
  ratingLabel: "Add App Store ratings and testimonials when ready.",
  items: [],
};

const sharedTechShowcase: PageSection = {
  kind: "techShowcase",
  id: "technology",
  title: "Under the hood",
  subtitle:
    "Heirloom is built on production-grade infrastructure designed for privacy, reliability, and scale.",
  items: [
    {
      title: "Multi-pass AI",
      body: "Task-specific model selection across 8 AI task types. Cost-optimized per operation.",
      detail:
        "Fast parsing with Claude Haiku ($0.25/1M tokens), high-quality vision with Claude Sonnet ($3/1M tokens). 5-pass pipeline for silent cooking videos.",
      icon: "\u2728",
    },
    {
      title: "Offline-first sync",
      body: "Edit recipes on any device, even without internet. Changes merge automatically.",
      detail:
        "CRDT merge engine with vector clocks and 3-stage conflict resolution. No data loss during offline edits.",
      icon: "\u21C4",
    },
    {
      title: "Private by architecture",
      body: "No API keys in the app. On-device audio transcription. Your data stays yours.",
      detail:
        "Firebase gateway proxies all AI requests. WhisperKit runs Whisper locally. Two-tier GDPR consent.",
      icon: "\uD83D\uDD12",
    },
    {
      title: "Recipe provenance",
      body: "Every recipe has a verifiable history. Attribution chains track who created and shared what.",
      detail:
        "SHA256 hashing via CryptoKit. Generation tracking across multi-level shares. Aggregated trending metrics.",
      icon: "\uD83C\uDF33",
    },
  ],
};

const sharedComparisonTable: PageSection = {
  kind: "comparisonTable",
  id: "compare",
  title: "How Heirloom compares",
  subtitle: "Built different from the start.",
  rows: [
    { feature: "Save from any URL", heirloom: true, others: true },
    { feature: "Video-to-recipe (TikTok, YouTube)", heirloom: true, others: "Some" },
    { feature: "Cookbook scanning (camera + PDF)", heirloom: true, others: "Limited" },
    { feature: "Voice dictation", heirloom: true, others: false },
    { feature: "AI recipe generation", heirloom: true, others: false },
    { feature: "Offline editing with sync", heirloom: true, others: "Limited" },
    { feature: "Recipe attribution & lineage", heirloom: true, others: false },
    { feature: "Private by default", heirloom: true, others: "Varies" },
    { feature: "On-device audio processing", heirloom: true, others: false },
    { feature: "Share with accept/consent", heirloom: true, others: false },
  ],
};

export const pages: Record<
  "home" | "lpVideo" | "lpScan" | "lpGenerate" | "lpShare" | "community" | "presskit" | "about" | "technology",
  MarketingPage
> = {
  home: {
    meta: {
      title: "Heirloom Recipe Box — Preserve your family's recipes",
      description:
        "Preserve your family's recipes forever. Capture from links, videos, cookbooks, and voice — heritage-grade archiving, private by default.",
    },
    nav: sharedNav,
    hero: {
      h1: "Preserve your family's recipes forever",
      subhead:
        "Heirloom captures recipes from links, videos, cookbooks, and voice — preserving them as heritage, not just bookmarks.",
      primaryCta: { label: "Get Heirloom Recipe Box", href: urls.appStore },
      secondaryCta: { label: "See how it works", href: "#how-it-works" },
      emailCapture: { formName: "notify", placeholder: "you@domain.com", buttonLabel: "Notify me" },
      trustLine: "Private by default — Share only when you choose",
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "Saving a recipe to Heirloom Recipe Box from the share sheet",
        aspect: "16:9",
      },
    },
    variants: {
      b: {
        hero: {
          h1: "Your family's recipe archive",
          subhead:
            "Capture from links, videos, cookbooks, and voice — then preserve and share the recipes that matter most.",
        },
      },
    },
    sections: [
      sharedProblemSolution,
      {
        kind: "steps",
        id: "how-it-works",
        title: "The fastest way to preserve recipes",
        items: [
          { title: "Tap Share", body: "On a recipe anywhere—web, PDF, or video." },
          { title: "Save to Heirloom", body: 'Choose "Save to Heirloom Recipe Box".' },
          { title: "Cook from a clean recipe", body: "Ingredients and steps, ready to go." },
        ],
      },
      {
        kind: "featureGrid",
        id: "sources",
        title: "Capture recipes from everywhere they live",
        columns: 3,
        items: [
          { title: "From the web", body: "Articles, blogs, newsletters—save and move on." },
          {
            title: "From PDFs",
            body: "Cookbooks, printables, family recipes—clean and readable.",
          },
          { title: "From videos", body: "Keep the recipe, not the scrolling." },
        ],
      },
      sharedTechShowcase,
      sharedComparisonTable,
      sharedSocialProof,
      sharedPricingSection,
      { kind: "faq", id: "faq", title: "FAQ", items: sharedFAQs },
      {
        kind: "cta",
        id: "download",
        title: "Start preserving your family's recipes today",
        body: "Don't let another recipe disappear. Join the list for launch updates.",
        cta: { label: "Get Heirloom Recipe Box", href: urls.appStore },
        emailCapture: { formName: "notify", placeholder: "you@domain.com", buttonLabel: "Notify me" },
      },
    ],
  },

  lpVideo: {
    meta: {
      title: "Turn cooking videos into recipes — Heirloom Recipe Box",
      description:
        "TikTok, Instagram, YouTube—extract any recipe in seconds and keep it organized in your Recipe Box.",
    },
    nav: sharedNav,
    hero: {
      h1: "Turn cooking videos into recipes",
      subhead:
        "TikTok, Instagram, YouTube—extract any recipe in seconds and keep it organized.",
      primaryCta: { label: "Download on the App Store", href: urls.appStore },
      secondaryCta: { label: "See how it works", href: "#how-it-works" },
      trustLine: "Private by default — Share only when you choose",
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "Turning a cooking video into a recipe in Heirloom Recipe Box",
        aspect: "16:9",
      },
    },
    sections: [
      sharedProblemSolution,
      {
        kind: "steps",
        id: "how-it-works",
        title: "From video to recipe card",
        items: [
          { title: "Save a cooking video", body: "From TikTok, Instagram, YouTube, and more." },
          { title: "Share to Heirloom", body: 'From your camera roll, tap Share → "Heirloom".' },
          { title: "Cook from clean steps", body: "Ingredients and instructions, ready to use." },
        ],
      },
      {
        kind: "featureGrid",
        id: "features",
        title: "Built for video recipes",
        columns: 3,
        items: [
          { title: "Works across platforms", body: "TikTok, Instagram, YouTube—save what you find." },
          { title: "No copy/paste", body: "Keep browsing while the import runs in the background." },
          { title: "Organized automatically", body: "A Recipe Box you’ll actually use." },
        ],
      },
      sharedPricingSection,
      { kind: "faq", id: "faq", title: "FAQ", items: sharedFAQs },
      {
        kind: "cta",
        id: "download",
        title: "Turn your saved videos into a Recipe Box",
        cta: { label: "Download on the App Store", href: urls.appStore },
      },
    ],
  },

  lpScan: {
    meta: {
      title: "Digitize your cookbooks — Heirloom Recipe Box",
      description:
        "Point your camera at any recipe. Turn cookbooks, cards, and handwriting into clean recipes.",
    },
    nav: sharedNav,
    hero: {
      h1: "Digitize your cookbooks",
      subhead: "Point your camera at any recipe. Instant digital copy in your Recipe Box.",
      primaryCta: { label: "Download on the App Store", href: urls.appStore },
      secondaryCta: { label: "See how it works", href: "#how-it-works" },
      trustLine: "Private by default — Share only when you choose",
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "Scanning a cookbook page into Heirloom Recipe Box",
        aspect: "16:9",
      },
    },
    sections: [
      sharedProblemSolution,
      {
        kind: "steps",
        id: "how-it-works",
        title: "From page to recipe card",
        items: [
          { title: "Open your cookbook", body: "Any printed recipe page or card." },
          { title: "Scan with your camera", body: "Heirloom extracts the recipe for you." },
          { title: "Edit and cook", body: "Fix anything fast, then save it forever." },
        ],
      },
      {
        kind: "featureGrid",
        id: "features",
        title: "Perfect for cookbooks and handwriting",
        columns: 3,
        items: [
          { title: "Cookbook pages", body: "Turn printed recipes into clean steps." },
          { title: "Handwritten cards", body: "Capture the recipes you don’t want to lose." },
          { title: "Private by default", body: "Your Recipe Box stays yours." },
        ],
      },
      sharedPricingSection,
      { kind: "faq", id: "faq", title: "FAQ", items: sharedFAQs },
      {
        kind: "cta",
        id: "download",
        title: "Digitize your cookbook shelf",
        cta: { label: "Download on the App Store", href: urls.appStore },
      },
    ],
  },

  lpGenerate: {
    meta: {
      title: "Tell us what you have. Get a recipe. — Heirloom Recipe Box",
      description:
        "Describe ingredients or a craving. Heirloom generates a recipe you can save and cook.",
    },
    nav: sharedNav,
    hero: {
      h1: "Tell us what you have. Get a recipe.",
      subhead: "Describe ingredients or a craving. Get a recipe you’ll actually cook.",
      primaryCta: { label: "Download on the App Store", href: urls.appStore },
      secondaryCta: { label: "See how it works", href: "#how-it-works" },
      trustLine: "Private by default — Your Recipe Box stays yours",
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "Generating a recipe in Heirloom Recipe Box",
        aspect: "16:9",
      },
    },
    sections: [
      sharedProblemSolution,
      {
        kind: "steps",
        id: "how-it-works",
        title: "From idea to recipe card",
        items: [
          { title: "Describe what you want", body: "Ingredients, a cuisine, or a craving." },
          { title: "Heirloom writes a recipe", body: "Ingredients and steps, structured and clear." },
          { title: "Save it to your Recipe Box", body: "Edit, cook, and share when you choose." },
        ],
      },
      sharedPricingSection,
      {
        kind: "cta",
        id: "download",
        title: "Generate your next favorite recipe",
        cta: { label: "Download on the App Store", href: urls.appStore },
      },
    ],
  },

  lpShare: {
    meta: {
      title: "Share recipes that stick — Heirloom Recipe Box",
      description: "Privacy information for Heirloom Recipe Box.",
    },
    nav: sharedNav,
    hero: {
      h1: "Share recipes that stick",
      subhead: "Send recipes to friends and family. They’ll have it forever—organized.",
      primaryCta: { label: "Download on the App Store", href: urls.appStore },
      secondaryCta: { label: "See how it works", href: "#how-it-works" },
      demo: {
        video: "/assets/video/lp2-share-hero-16x9.mp4",
        poster: "/assets/posters/lp2-share-hero.jpg",
        alt: "Sharing a recipe from Heirloom Recipe Box",
        aspect: "16:9",
      },
    },
    sections: [
      sharedProblemSolution,
      {
        kind: "steps",
        id: "how-it-works",
        title: "Sharing that actually lands",
        items: [
          { title: "You send a recipe", body: "Directly from your Recipe Box." },
          { title: "They tap Accept", body: "It’s added instantly—no chasing links." },
          { title: "You both keep it organized", body: "A shared Recipe Box, built over time." },
        ],
      },
      sharedPricingSection,
      { kind: "faq", id: "faq", title: "FAQ", items: sharedFAQs },
      {
        kind: "cta",
        id: "download",
        title: "Make recipe sharing feel easy again",
        cta: { label: "Download on the App Store", href: urls.appStore },
      },
    ],
  },

  community: {
    meta: {
      title: "Community — Heirloom Recipe Box",
      description: "Join the Heirloom community and beta testing group.",
    },
    nav: sharedNav,
    hero: {
      h1: "Join the Heirloom community",
      subhead: "Get updates, share feedback, and swap recipes with other testers.",
      primaryCta: { label: "Join Discord", href: urls.support },
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "Heirloom community",
        aspect: "16:9",
      },
    },
    sections: [
      {
        kind: "featureGrid",
        id: "what-you-get",
        title: "What to expect",
        columns: 3,
        items: [
          { title: "Bug reports", body: "Share steps and screenshots so we can fix fast." },
          { title: "Feature requests", body: "Tell us what would make Heirloom magical for you." },
          { title: "Recipe sharing", body: "Swap recipes and workflows with other cooks." },
        ],
      },
      {
        kind: "cta",
        id: "download",
        title: "Ready to join?",
        cta: { label: "Join Discord", href: urls.support },
      },
    ],
  },

  presskit: {
    meta: {
      title: "Press Kit — Heirloom Recipe Box",
      description: "Press resources for Heirloom Recipe Box.",
    },
    nav: sharedNav,
    hero: {
      h1: "Press Kit",
      subhead: "Logos, screenshots, and product info for press and partners.",
      primaryCta: { label: "Contact", href: "mailto:admin@rationale.work" },
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "Heirloom Recipe Box press kit",
        aspect: "16:9",
      },
    },
    sections: [
      {
        kind: "steps",
        id: "resources",
        title: "What’s included",
        items: [
          { title: "Logos", body: "App icon and wordmark (coming soon)." },
          { title: "Screenshots", body: "High-resolution product shots (coming soon)." },
          { title: "Product summary", body: "Copy-friendly description and key features." },
        ],
      },
      {
        kind: "cta",
        id: "download",
        title: "Need something specific?",
        cta: { label: "Email us", href: "mailto:admin@rationale.work" },
      },
    ],
  },

  about: {
    meta: {
      title: "About — Heirloom Recipe Box | The System of Record for Family Food Culture",
      description:
        "The story behind Heirloom Recipe Box. Built by Rationale Studio to preserve family food culture for generations.",
    },
    nav: sharedNav,
    hero: {
      h1: "The system of record for family food culture",
      subhead:
        "Heirloom is built by Rationale Studio to solve a generational problem: 73% of family recipes are lost when the keeper passes away.",
      primaryCta: { label: "Get Heirloom Recipe Box", href: urls.appStore },
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "About Heirloom Recipe Box",
        aspect: "16:9",
      },
    },
    sections: [
      {
        kind: "problemSolution",
        id: "why",
        title: "Why we built Heirloom",
        problem: {
          title: "The loss",
          body: "73% of family recipes are lost within one generation. They exist as screenshots, bookmarks, handwritten cards, and memories\u2014scattered across devices and drawers.",
          bullets: [
            "Bookmarked recipes vanish when sites change",
            "Handwritten cards fade and get lost",
            "Video recipes disappear in algorithm feeds",
            "Family knowledge dies with the cook",
          ],
        },
        solution: {
          title: "The mission",
          body: "Heirloom treats recipes as what they are\u2014cultural heritage. We built technology that preserves, organizes, and attributes them properly.",
          bullets: [
            "Save from any source in one tap",
            "Track where every recipe comes from",
            "Share with intention, not broadcast",
            "Private by default, always",
          ],
        },
      },
      {
        kind: "teamSection",
        id: "team",
        title: "Built by Rationale Studio",
        subtitle: "A product studio focused on thoughtful software for real problems.",
        members: [
          {
            name: "Matt Hanson",
            role: "Founder & Engineer",
            bio: "Full-stack engineer who built Heirloom from the ground up\u2014iOS app, backend infrastructure, AI pipeline, and marketing site. Previously built Zero Inbox (AI email client). Believes the best software solves real problems with genuine craft.",
            skills: [
              "Swift/SwiftUI",
              "Firebase",
              "AI/ML",
              "Distributed Systems",
              "Next.js",
              "Product Design",
            ],
          },
        ],
      },
      {
        kind: "metricsBar",
        id: "metrics",
        items: [
          { value: "6", label: "Recipe import methods" },
          { value: "18+", label: "Months of engineering" },
          { value: "5-pass", label: "AI video pipeline" },
          { value: "0", label: "API keys in client" },
        ],
      },
      sharedTechShowcase,
      {
        kind: "cta",
        id: "download",
        title: "Start preserving today",
        body: "50 free credits to start. No subscription required. Your family's recipes deserve better than a screenshot folder.",
        cta: { label: "Get Heirloom Recipe Box", href: urls.appStore },
      },
    ],
  },

  technology: {
    meta: {
      title: "Technology — Heirloom Recipe Box",
      description:
        "How Heirloom works: multi-pass AI, CRDT sync, on-device transcription, and cryptographic provenance.",
    },
    nav: sharedNav,
    hero: {
      h1: "Built for trust, not shortcuts",
      subhead:
        "Heirloom is engineered with the same rigor as enterprise software\u2014because your family recipes deserve it.",
      primaryCta: { label: "Get Heirloom Recipe Box", href: urls.appStore },
      demo: {
        video: "/assets/video/lp1-save-hero-16x9.mp4",
        poster: "/assets/posters/lp1-save-hero.jpg",
        alt: "Heirloom technology",
        aspect: "16:9",
      },
    },
    sections: [
      {
        kind: "techShowcase",
        id: "ai-pipeline",
        title: "Multi-pass AI pipeline",
        subtitle:
          "Every import type gets the right model at the right cost. No one-size-fits-all prompts.",
        items: [
          {
            title: "Tiered model selection",
            body: "8 task types, each routed to the optimal model for cost and quality.",
            detail:
              "Text parsing uses fast, affordable models. Vision tasks use high-quality models. Costs stay predictable.",
            icon: "\u2699\uFE0F",
          },
          {
            title: "5-pass video extraction",
            body: "Silent cooking videos get a dedicated pipeline that watches, identifies, and validates.",
            detail:
              "Identifying \u2192 Detecting \u2192 Inferring \u2192 Analyzing \u2192 Validating. Each pass builds on the last.",
            icon: "\uD83C\uDFAC",
          },
          {
            title: "On-device transcription",
            body: "WhisperKit runs OpenAI's Whisper model locally. Audio never leaves your phone.",
            detail:
              "Adaptive model selection based on device capability. Zero API cost for voice capture.",
            icon: "\uD83C\uDF99\uFE0F",
          },
          {
            title: "Structured output",
            body: "AI returns typed JSON matching exact recipe schemas. No guessing, no parsing errors.",
            detail:
              "Schema validation ensures every generated recipe is immediately usable. Iterative image compression for API limits.",
            icon: "\uD83D\uDCCB",
          },
        ],
      },
      {
        kind: "techShowcase",
        id: "sync-engine",
        title: "Offline-first sync engine",
        subtitle:
          "Real CRDT-based conflict resolution\u2014not last-write-wins.",
        items: [
          {
            title: "Vector clocks",
            body: "Track causal relationships between edits across devices without relying on wall clocks.",
            detail:
              "Each device maintains a logical timestamp. Concurrent edits are detected precisely, not guessed.",
            icon: "\u23F1\uFE0F",
          },
          {
            title: "Operation log",
            body: "Every edit is an immutable operation. The full history is preserved and replayable.",
            detail:
              "Operations include: create, update, delete, addIngredient, addInstruction. Each carries device metadata.",
            icon: "\uD83D\uDCDD",
          },
          {
            title: "3-stage merge",
            body: "Auto-merge handles 80% of conflicts. The remaining 20% get a clear resolution UI.",
            detail:
              "Stage 1: additive operations merge automatically. Stage 2: delete wins. Stage 3: user chooses with full context.",
            icon: "\uD83D\uDD00",
          },
          {
            title: "Security validation",
            body: "Every operation's field path is validated against a whitelist before application.",
            detail:
              "Prevents injection attacks on CRDT operations. Only title, notes, ingredients, instructions, and time fields are allowed.",
            icon: "\uD83D\uDEE1\uFE0F",
          },
        ],
      },
      {
        kind: "techShowcase",
        id: "provenance",
        title: "Cryptographic recipe provenance",
        subtitle:
          "Every recipe has a verifiable, immutable history.",
        items: [
          {
            title: "SHA256 root hash",
            body: "Original recipes get a unique cryptographic fingerprint. All copies inherit it.",
            detail:
              "Generated via CryptoKit from timestamp + UUID. Unforgeable and globally unique.",
            icon: "#\uFE0F\u20E3",
          },
          {
            title: "Generation tracking",
            body: "Know whether a recipe is original (Gen 0), first share (Gen 1), or a re-share (Gen 2+).",
            detail:
              "Multi-generational chains: A shares to B, B shares to C. Everyone sees the full attribution.",
            icon: "\uD83C\uDF33",
          },
          {
            title: "Source attribution",
            body: "Imported from a URL? Scanned from a cookbook? AI generated? The source is always tracked.",
            detail:
              "6 source types: userCreated, imported, shared, scanned, ai, video. Social platform detection for video imports.",
            icon: "\uD83D\uDD17",
          },
          {
            title: "Aggregated metrics",
            body: "Total shares, cooks, ratings, and trending score computed across the entire family tree.",
            detail:
              "Trending threshold: score > 10 and total shares > 5. Metrics refresh from cloud periodically.",
            icon: "\uD83D\uDCC8",
          },
        ],
      },
      sharedComparisonTable,
      {
        kind: "cta",
        id: "download",
        title: "Heritage-grade technology, free to try",
        body: "Download Heirloom and experience preservation technology yourself. 50 free credits included.",
        cta: { label: "Get Heirloom Recipe Box", href: urls.appStore },
      },
    ],
  },
};
