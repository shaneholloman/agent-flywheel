'use client';

import {
  Terminal,
  Package,
  Server,
  GitBranch,
  Play,
  Shield,
} from 'lucide-react';
import {
  Section,
  Paragraph,
  CodeBlock,
  TipBox,
  Highlight,
  Divider,
  GoalBanner,
  CommandList,
  FeatureCard,
  FeatureGrid,
} from './lesson-components';

export function DsrLesson() {
  return (
    <div className="space-y-8">
      <GoalBanner>
        Ship releases locally when GitHub Actions is throttled with Doodlestein Self-Releaser.
      </GoalBanner>

      {/* Section 1: What Is DSR */}
      <Section title="What Is DSR?" icon={<Package className="h-5 w-5" />} delay={0.1}>
        <Paragraph>
          <Highlight>DSR (Doodlestein Self-Releaser)</Highlight> is fallback release
          infrastructure for when GitHub Actions is throttled or unavailable.
          It builds release artifacts locally using <code>act</code> (local GitHub Actions runner)
          and publishes them directly.
        </Paragraph>
        <Paragraph>
          When CI is backed up or your Actions minutes are exhausted, DSR lets you
          cut a release from your local machine with the same reproducibility as CI.
        </Paragraph>

        <div className="mt-8">
          <FeatureGrid>
            <FeatureCard
              icon={<Server className="h-5 w-5" />}
              title="Local Builds"
              description="Run GitHub Actions workflows locally via act"
              gradient="from-orange-500/20 to-red-500/20"
            />
            <FeatureCard
              icon={<Package className="h-5 w-5" />}
              title="Release Artifacts"
              description="Build and publish release binaries"
              gradient="from-blue-500/20 to-indigo-500/20"
            />
            <FeatureCard
              icon={<GitBranch className="h-5 w-5" />}
              title="Cross-Platform"
              description="Build for multiple OS targets from one machine"
              gradient="from-green-500/20 to-emerald-500/20"
            />
            <FeatureCard
              icon={<Shield className="h-5 w-5" />}
              title="CI Parity"
              description="Same workflow definitions as your real CI"
              gradient="from-purple-500/20 to-violet-500/20"
            />
          </FeatureGrid>
        </div>
      </Section>

      <Divider />

      {/* Section 2: Essential Commands */}
      <Section title="Essential Commands" icon={<Terminal className="h-5 w-5" />} delay={0.2}>
        <CommandList
          commands={[
            { command: 'dsr release', description: 'Build and publish a release locally' },
            { command: 'dsr build', description: 'Build artifacts without publishing' },
            { command: 'dsr status', description: 'Check release readiness' },
            { command: 'dsr --help', description: 'Show all options' },
          ]}
        />

        <TipBox>
          DSR is a safety net, not a replacement for CI. Use it when Actions is down
          or throttled and you need to ship now.
        </TipBox>
      </Section>

      <Divider />

      {/* Section 3: Common Scenarios */}
      <Section title="Common Scenarios" icon={<Play className="h-5 w-5" />} delay={0.3}>
        <CodeBlock code={`# Check if you're ready to release
dsr status

# Build release artifacts locally
dsr build

# Full release: build + tag + publish
dsr release`} />
      </Section>
    </div>
  );
}
