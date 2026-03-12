'use client';

import {
  Terminal,
  BellRing,
  BookOpen,
  RefreshCw,
  Play,
  FileText,
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

export function PcrLesson() {
  return (
    <div className="space-y-8">
      <GoalBanner>
        Keep agents aligned after context compaction with Post-Compact Reminder.
      </GoalBanner>

      {/* Section 1: What Is PCR */}
      <Section title="What Is PCR?" icon={<BellRing className="h-5 w-5" />} delay={0.1}>
        <Paragraph>
          <Highlight>PCR (Post-Compact Reminder)</Highlight> is a Claude Code hook
          that fires after context compaction and forces the agent to re-read AGENTS.md.
          This prevents agents from &ldquo;forgetting&rdquo; project rules and conventions
          after their context window is compressed.
        </Paragraph>
        <Paragraph>
          Without PCR, agents that hit context limits lose awareness of project-specific
          instructions. PCR ensures continuity by automatically injecting a reminder
          to re-read the project guidelines.
        </Paragraph>

        <div className="mt-8">
          <FeatureGrid>
            <FeatureCard
              icon={<BellRing className="h-5 w-5" />}
              title="Auto-Reminder"
              description="Triggers on every context compaction event"
              gradient="from-rose-500/20 to-pink-500/20"
            />
            <FeatureCard
              icon={<BookOpen className="h-5 w-5" />}
              title="AGENTS.md Re-read"
              description="Forces re-reading project guidelines"
              gradient="from-blue-500/20 to-indigo-500/20"
            />
            <FeatureCard
              icon={<RefreshCw className="h-5 w-5" />}
              title="Context Recovery"
              description="Restores lost project awareness after compaction"
              gradient="from-green-500/20 to-emerald-500/20"
            />
            <FeatureCard
              icon={<FileText className="h-5 w-5" />}
              title="Zero Config"
              description="Installs as a Claude Code hook, works automatically"
              gradient="from-amber-500/20 to-yellow-500/20"
            />
          </FeatureGrid>
        </div>
      </Section>

      <Divider />

      {/* Section 2: Setup */}
      <Section title="Setup & Verification" icon={<Terminal className="h-5 w-5" />} delay={0.2}>
        <CommandList
          commands={[
            { command: 'claude-post-compact-reminder --check', description: 'Verify hook is installed' },
            { command: 'claude-post-compact-reminder --install', description: 'Install the hook' },
            { command: 'cat ~/.claude/settings.json', description: 'View hook configuration' },
          ]}
        />

        <TipBox>
          PCR is especially important for long-running agent sessions that process
          many files and are likely to hit context limits.
        </TipBox>
      </Section>

      <Divider />

      {/* Section 3: How It Works */}
      <Section title="How It Works" icon={<Play className="h-5 w-5" />} delay={0.3}>
        <CodeBlock code={`# PCR installs a hook in ~/.claude/settings.json
# that watches for the "compact" event.
# When triggered, it injects:
#   "Re-read AGENTS.md now and follow all instructions."

# Verify the hook is active:
claude-post-compact-reminder --check

# The hook fires automatically - no manual action needed.`} />
      </Section>
    </div>
  );
}
