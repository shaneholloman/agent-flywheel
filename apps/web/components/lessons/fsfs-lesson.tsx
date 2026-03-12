'use client';

import {
  Terminal,
  Search,
  Zap,
  Database,
  Play,
  Layers,
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

export function FsfsLesson() {
  return (
    <div className="space-y-8">
      <GoalBanner>
        Search your local files at blazing speed with FrankenSearch&apos;s hybrid retrieval engine.
      </GoalBanner>

      {/* Section 1: What Is FSFS */}
      <Section title="What Is FrankenSearch?" icon={<Search className="h-5 w-5" />} delay={0.1}>
        <Paragraph>
          <Highlight>FSFS (FrankenSearch)</Highlight> is a two-tier hybrid local search engine
          combining lexical (BM25) and semantic retrieval with progressive delivery.
          It indexes your local files and returns results ranked by both keyword relevance
          and meaning.
        </Paragraph>
        <Paragraph>
          FSFS builds an index once, then serves queries in milliseconds. It supports
          incremental updates so new files are searchable without a full re-index.
        </Paragraph>

        <div className="mt-8">
          <FeatureGrid>
            <FeatureCard
              icon={<Search className="h-5 w-5" />}
              title="BM25 Lexical Search"
              description="Fast keyword matching with TF-IDF scoring"
              gradient="from-purple-500/20 to-indigo-500/20"
            />
            <FeatureCard
              icon={<Layers className="h-5 w-5" />}
              title="Semantic Retrieval"
              description="Embedding-based similarity for meaning-aware results"
              gradient="from-blue-500/20 to-cyan-500/20"
            />
            <FeatureCard
              icon={<Zap className="h-5 w-5" />}
              title="Progressive Delivery"
              description="Results stream as they're found, fast first results"
              gradient="from-amber-500/20 to-yellow-500/20"
            />
            <FeatureCard
              icon={<Database className="h-5 w-5" />}
              title="Incremental Index"
              description="Only re-indexes changed files for fast updates"
              gradient="from-green-500/20 to-emerald-500/20"
            />
          </FeatureGrid>
        </div>
      </Section>

      <Divider />

      {/* Section 2: Essential Commands */}
      <Section title="Essential Commands" icon={<Terminal className="h-5 w-5" />} delay={0.2}>
        <CommandList
          commands={[
            { command: 'fsfs index .', description: 'Index the current directory' },
            { command: 'fsfs search "query"', description: 'Search indexed files' },
            { command: 'fsfs search --semantic "concept"', description: 'Semantic-only search' },
            { command: 'fsfs status', description: 'Show index statistics' },
          ]}
        />

        <TipBox>
          Use FSFS when you need to search across large codebases or documentation sets
          where simple grep isn&apos;t enough.
        </TipBox>
      </Section>

      <Divider />

      {/* Section 3: Common Scenarios */}
      <Section title="Common Scenarios" icon={<Play className="h-5 w-5" />} delay={0.3}>
        <CodeBlock code={`# Index a project
fsfs index ~/projects/my-app

# Search for error handling patterns
fsfs search "error handling retry"

# Find conceptually similar code
fsfs search --semantic "authentication middleware"`} />
      </Section>
    </div>
  );
}
