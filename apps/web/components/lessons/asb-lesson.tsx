'use client';

import {
  Terminal,
  Save,
  FolderSync,
  Clock,
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

export function AsbLesson() {
  return (
    <div className="space-y-8">
      <GoalBanner>
        Back up and restore your AI agent configurations with Agent Settings Backup.
      </GoalBanner>

      {/* Section 1: What Is ASB */}
      <Section title="What Is ASB?" icon={<Save className="h-5 w-5" />} delay={0.1}>
        <Paragraph>
          <Highlight>ASB (Agent Settings Backup)</Highlight> is a smart backup tool
          for AI coding agent configuration folders. It backs up settings for Claude Code,
          Cursor, Codex CLI, Gemini CLI, and other agents to a single versioned archive.
        </Paragraph>
        <Paragraph>
          When you provision a new machine or recover from a misconfiguration, ASB
          restores all your agent settings, skills, hooks, and preferences in one command.
        </Paragraph>

        <div className="mt-8">
          <FeatureGrid>
            <FeatureCard
              icon={<Save className="h-5 w-5" />}
              title="Multi-Agent Backup"
              description="Claude, Cursor, Codex, Gemini configs in one archive"
              gradient="from-emerald-500/20 to-green-500/20"
            />
            <FeatureCard
              icon={<FolderSync className="h-5 w-5" />}
              title="One-Command Restore"
              description="Restore all settings to a new machine instantly"
              gradient="from-blue-500/20 to-indigo-500/20"
            />
            <FeatureCard
              icon={<Clock className="h-5 w-5" />}
              title="Versioned Snapshots"
              description="Keep historical snapshots of your config state"
              gradient="from-amber-500/20 to-yellow-500/20"
            />
            <FeatureCard
              icon={<Shield className="h-5 w-5" />}
              title="Selective Restore"
              description="Restore specific agents or specific config files"
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
            { command: 'asb backup', description: 'Create a backup of all agent settings' },
            { command: 'asb restore', description: 'Restore settings from latest backup' },
            { command: 'asb list', description: 'List available backup snapshots' },
            { command: 'asb diff', description: 'Show changes since last backup' },
          ]}
        />

        <TipBox>
          Run ASB backup before provisioning new machines or making major configuration
          changes to your agent setups.
        </TipBox>
      </Section>

      <Divider />

      {/* Section 3: Common Scenarios */}
      <Section title="Common Scenarios" icon={<Play className="h-5 w-5" />} delay={0.3}>
        <CodeBlock code={`# Back up all agent configs
asb backup

# Restore to a fresh machine
asb restore

# See what changed since last backup
asb diff`} />
      </Section>
    </div>
  );
}
