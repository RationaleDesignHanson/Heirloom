import type { PageSection } from "@/content/content";
import Section from "./Section";
import Steps from "./Steps";
import ProblemSolution from "./ProblemSolution";
import FeatureGrid from "./FeatureGrid";
import FAQ from "./FAQ";
import TrustBar from "./TrustBar";
import PageCTA from "./PageCTA";
import TestimonialStrip from "./TestimonialStrip";
import SocialProof from "./SocialProof";
import PricingCredits from "./PricingCredits";
import TechShowcase from "./TechShowcase";
import ComparisonTable from "./ComparisonTable";
import TeamSection from "./TeamSection";
import MetricsBar from "./MetricsBar";

export function renderSection(section: PageSection) {
  switch (section.kind) {
    case "steps":
      return (
        <Section id={section.id}>
          <Steps title={section.title} items={section.items} />
        </Section>
      );

    case "problemSolution":
      return (
        <Section id={section.id}>
          <ProblemSolution
            title={section.title}
            problem={section.problem}
            solution={section.solution}
          />
        </Section>
      );

    case "featureGrid":
      return (
        <Section id={section.id}>
          <FeatureGrid title={section.title} items={section.items} columns={section.columns ?? 3} />
        </Section>
      );

    case "socialProof":
      return (
        <Section id={section.id}>
          <SocialProof
            title={section.title}
            ratingLabel={section.ratingLabel}
            items={section.items}
          />
        </Section>
      );

    case "testimonials":
      return (
        <Section id={section.id}>
          <TestimonialStrip title={section.title} items={section.items} />
        </Section>
      );

    case "trustBar":
      return (
        <Section id={section.id}>
          <TrustBar items={section.items} />
        </Section>
      );

    case "faq":
      return (
        <Section id={section.id}>
          <FAQ title={section.title} items={section.items} />
        </Section>
      );

    case "pricingCredits":
      return (
        <Section id={section.id}>
          <PricingCredits
            title={section.title}
            subtitle={section.subtitle}
            trialCreditsIncluded={section.trialCreditsIncluded}
            premiumMonthlyCredits={section.premiumMonthlyCredits}
            creditExamples={section.creditExamples}
            plans={section.plans}
          />
        </Section>
      );

    case "cta":
      return (
        <Section id={section.id}>
          <PageCTA
            title={section.title}
            body={section.body}
            cta={section.cta}
            emailCapture={section.emailCapture}
          />
        </Section>
      );

    case "techShowcase":
      return (
        <Section id={section.id}>
          <TechShowcase
            title={section.title}
            subtitle={section.subtitle}
            items={section.items}
          />
        </Section>
      );

    case "comparisonTable":
      return (
        <Section id={section.id}>
          <ComparisonTable
            title={section.title}
            subtitle={section.subtitle}
            rows={section.rows}
          />
        </Section>
      );

    case "teamSection":
      return (
        <Section id={section.id}>
          <TeamSection
            title={section.title}
            subtitle={section.subtitle}
            members={section.members}
          />
        </Section>
      );

    case "metricsBar":
      return (
        <Section id={section.id}>
          <MetricsBar items={section.items} />
        </Section>
      );

    default: {
      const _exhaustive: never = section;
      return _exhaustive;
    }
  }
}
