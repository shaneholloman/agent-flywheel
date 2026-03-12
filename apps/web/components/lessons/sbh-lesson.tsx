'use client';

import {
  Terminal,
  HardDrive,
  Shield,
  Activity,
  Play,
  AlertTriangle,
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

export function SbhLesson() {
  return (
    <div className="space-y-8">
      <GoalBanner>
        Protect your disk from pressure spikes with Storage Ballast Helper.
      </GoalBanner>

      {/* Section 1: What Is SBH */}
      <Section title="What Is Storage Ballast Helper?" icon={<HardDrive className="h-5 w-5" />} delay={0.1}>
        <Paragraph>
          <Highlight>SBH (Storage Ballast Helper)</Highlight> is a cross-platform disk-pressure
          defense tool designed for AI coding workloads. It pre-allocates a &ldquo;ballast&rdquo;
          file that can be released when disk space runs critically low, buying time
          to clean up.
        </Paragraph>
        <Paragraph>
          Agent coding sessions generate enormous amounts of build artifacts, logs, and
          caches. SBH monitors disk usage and automatically releases ballast when pressure
          exceeds configurable thresholds.
        </Paragraph>

        <div className="mt-8">
          <FeatureGrid>
            <FeatureCard
              icon={<HardDrive className="h-5 w-5" />}
              title="Ballast Files"
              description="Pre-allocated space released under pressure"
              gradient="from-blue-500/20 to-indigo-500/20"
            />
            <FeatureCard
              icon={<Activity className="h-5 w-5" />}
              title="Monitoring"
              description="Continuous disk usage tracking with alerts"
              gradient="from-green-500/20 to-emerald-500/20"
            />
            <FeatureCard
              icon={<AlertTriangle className="h-5 w-5" />}
              title="Auto-Release"
              description="Ballast freed automatically at critical thresholds"
              gradient="from-amber-500/20 to-orange-500/20"
            />
            <FeatureCard
              icon={<Shield className="h-5 w-5" />}
              title="Safe Recovery"
              description="Prevents out-of-space crashes and data loss"
              gradient="from-red-500/20 to-rose-500/20"
            />
          </FeatureGrid>
        </div>
      </Section>

      <Divider />

      {/* Section 2: Essential Commands */}
      <Section title="Essential Commands" icon={<Terminal className="h-5 w-5" />} delay={0.2}>
        <CommandList
          commands={[
            { command: 'sbh status', description: 'Show disk usage and ballast state' },
            { command: 'sbh create --size 5G', description: 'Create a 5 GB ballast file' },
            { command: 'sbh release', description: 'Manually release ballast space' },
            { command: 'sbh reclaim', description: 'Re-create ballast after cleanup' },
          ]}
        />

        <TipBox>
          Create ballast files on machines running multi-agent swarms, where parallel
          cargo builds and npm installs can exhaust disk space unexpectedly.
        </TipBox>
      </Section>

      <Divider />

      {/* Section 3: Common Scenarios */}
      <Section title="Common Scenarios" icon={<Play className="h-5 w-5" />} delay={0.3}>
        <CodeBlock code={`# Check current disk pressure
sbh status

# Create ballast on a new machine
sbh create --size 10G

# Emergency release when disk is full
sbh release`} />
      </Section>
    </div>
  );
}
