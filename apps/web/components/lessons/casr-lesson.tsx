'use client';

import {
  Terminal,
  Repeat,
  FileText,
  ArrowRightLeft,
  Play,
  Lightbulb,
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

export function CasrLesson() {
  return (
    <div className="space-y-8">
      <GoalBanner>
        Resume coding sessions across AI providers with Cross-Agent Session Resumer.
      </GoalBanner>

      {/* Section 1: What Is CASR */}
      <Section title="What Is CASR?" icon={<Repeat className="h-5 w-5" />} delay={0.1}>
        <Paragraph>
          <Highlight>CASR (Cross-Agent Session Resumer)</Highlight> converts and resumes
          AI coding sessions across different providers. Start a session in Claude Code,
          continue it in Codex CLI, and pick it back up in Gemini CLI without losing context.
        </Paragraph>
        <Paragraph>
          CASR extracts conversation context, code changes, and decisions into a
          portable format that any agent can ingest. This enables provider-hopping
          when you hit rate limits or want a second opinion.
        </Paragraph>

        <div className="mt-8">
          <FeatureGrid>
            <FeatureCard
              icon={<ArrowRightLeft className="h-5 w-5" />}
              title="Provider Agnostic"
              description="Convert sessions between Claude, Codex, and Gemini"
              gradient="from-violet-500/20 to-purple-500/20"
            />
            <FeatureCard
              icon={<FileText className="h-5 w-5" />}
              title="Context Preservation"
              description="Decisions, code changes, and rationale carry over"
              gradient="from-blue-500/20 to-indigo-500/20"
            />
            <FeatureCard
              icon={<Repeat className="h-5 w-5" />}
              title="Seamless Handoff"
              description="Resume mid-task without re-explaining context"
              gradient="from-cyan-500/20 to-teal-500/20"
            />
            <FeatureCard
              icon={<Lightbulb className="h-5 w-5" />}
              title="Rate Limit Recovery"
              description="Switch providers instantly when throttled"
              gradient="from-amber-500/20 to-yellow-500/20"
            />
          </FeatureGrid>
        </div>
      </Section>

      <Divider />

      {/* Section 2: Essential Commands */}
      <Section title="Essential Commands" icon={<Terminal className="h-5 w-5" />} delay={0.2}>
        <CommandList
          commands={[
            { command: 'casr export', description: 'Export current session context' },
            { command: 'casr resume --from claude', description: 'Resume a Claude session in current provider' },
            { command: 'casr list', description: 'List available session snapshots' },
            { command: 'casr --help', description: 'Show all options' },
          ]}
        />

        <TipBox>
          Use CASR when you hit a rate limit on one provider and want to seamlessly
          continue your work on another without losing context.
        </TipBox>
      </Section>

      <Divider />

      {/* Section 3: Common Scenarios */}
      <Section title="Common Scenarios" icon={<Play className="h-5 w-5" />} delay={0.3}>
        <CodeBlock code={`# Export current Claude Code session
casr export

# Resume in Codex CLI
casr resume --from claude --to codex

# List all saved session snapshots
casr list`} />
      </Section>
    </div>
  );
}
