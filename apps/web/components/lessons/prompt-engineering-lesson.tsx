"use client";

import { motion } from "@/components/motion";
import {
  Sparkles,
  Brain,
  Target,
  Maximize2,
  Layers,
  Anchor,
  Clock,
  CheckSquare,
  Lightbulb,
  Zap,
  Eye,
  FileText,
} from "lucide-react";
import {
  Section,
  Paragraph,
  CodeBlock,
  TipBox,
  Highlight,
  Divider,
  GoalBanner,
  FeatureCard,
  FeatureGrid,
} from "./lesson-components";

export function PromptEngineeringLesson() {
  return (
    <div className="space-y-8">
      <GoalBanner>
        Master the art of directing AI agents with precision and intention.
      </GoalBanner>

      {/* Introduction */}
      <Section
        title="Why Prompting Matters"
        icon={<Sparkles className="h-5 w-5" />}
        delay={0.1}
      >
        <Paragraph>
          The difference between a mediocre agent session and a brilliant one
          often comes down to <Highlight>how you direct the agent</Highlight>.
          This lesson dissects the patterns that make prompts effective, drawn
          from real-world workflows that consistently produce excellent results.
        </Paragraph>

        <div className="mt-8">
          <FeatureGrid>
            <FeatureCard
              icon={<Target className="h-5 w-5" />}
              title="Intensity Calibration"
              description="Signal how much attention to allocate"
              gradient="from-primary/20 to-violet-500/20"
            />
            <FeatureCard
              icon={<Maximize2 className="h-5 w-5" />}
              title="Scope Control"
              description="Expand or contract the search space"
              gradient="from-emerald-500/20 to-teal-500/20"
            />
            <FeatureCard
              icon={<Brain className="h-5 w-5" />}
              title="Metacognition"
              description="Force self-verification and reflection"
              gradient="from-amber-500/20 to-orange-500/20"
            />
            <FeatureCard
              icon={<Anchor className="h-5 w-5" />}
              title="Context Anchoring"
              description="Ground behavior in stable references"
              gradient="from-blue-500/20 to-indigo-500/20"
            />
          </FeatureGrid>
        </div>
      </Section>

      <Divider />

      {/* Pattern 1: Intensity Calibration */}
      <Section
        title="Pattern 1: Intensity Calibration"
        icon={<Zap className="h-5 w-5" />}
        delay={0.15}
      >
        <Paragraph>
          AI models allocate &quot;compute&quot; based on perceived task
          importance. <Highlight>Stacked modifiers</Highlight> signal that this
          task deserves maximum attention:
        </Paragraph>

        <div className="mt-6 space-y-4">
          <IntensityExample
            phrase="super carefully"
            effect="Elevates attention above baseline"
          />
          <IntensityExample
            phrase="super careful, methodical, and critical"
            effect="Triple-stacking for maximum precision"
          />
          <IntensityExample
            phrase="systematically and meticulously and intelligently"
            effect="Emphasizes both process and quality"
          />
        </div>

        <div className="mt-6">
          <CodeBlock
            code={`# Low intensity (default behavior)
"Check the code for bugs"

# High intensity (elevated attention)
"Do a super careful, methodical, and critical check
with fresh eyes to find any obvious bugs, problems,
errors, issues, silly mistakes, etc. and then
systematically and meticulously and intelligently
correct them."`}
          />
        </div>

        <div className="mt-6">
          <TipBox variant="info">
            These aren&apos;t filler words. They&apos;re{" "}
            <strong>calibration signals</strong> that tell the model to allocate
            more reasoning depth to the task.
          </TipBox>
        </div>

        <div className="mt-6">
          <TipBox variant="tip">
            <strong>Claude Code feature:</strong> The word{" "}
            <strong>ultrathink</strong> is a specific Claude Code directive that
            tells the system to allocate significantly more thinking tokens. While
            it&apos;s a tool-level feature in Claude Code, using intensity words like
            &quot;think deeply&quot; or &quot;reason carefully&quot; can help other
            agents/models allocate more attention to complex tasks as well.
          </TipBox>
        </div>
      </Section>

      <Divider />

      {/* Pattern 2: Scope Control */}
      <Section
        title="Pattern 2: Scope Control"
        icon={<Maximize2 className="h-5 w-5" />}
        delay={0.2}
      >
        <Paragraph>
          Models tend to take shortcuts. Explicit scope directives push against
          premature narrowing:
        </Paragraph>

        <div className="mt-6 grid gap-4 md:grid-cols-2">
          <ScopeCard
            direction="expand"
            phrases={[
              "take ALL of that",
              "Don't restrict yourself",
              "cast a wider net",
              "comprehensive and granular",
            ]}
          />
          <ScopeCard
            direction="deepen"
            phrases={[
              "go super deep",
              "deeply investigate and understand",
              "trace their functionality and execution flows",
              "first-principle analysis",
            ]}
          />
        </div>

        <div className="mt-6">
          <CodeBlock
            code={`# Avoiding narrow focus
"Don't restrict yourself to the latest commits,
cast a wider net and go super deep!"

# Comprehensive coverage
"Take ALL of that and elaborate on it more,
then create a comprehensive and granular set..."

# Depth with breadth
"Randomly explore the code files in this project,
choosing code files to deeply investigate and understand
and trace their functionality and execution flows
through the related code files which they import
or which they are imported by."`}
          />
        </div>
      </Section>

      <Divider />

      {/* Pattern 3: Self-Verification */}
      <Section
        title="Pattern 3: Forcing Self-Verification"
        icon={<CheckSquare className="h-5 w-5" />}
        delay={0.25}
      >
        <Paragraph>
          Questions trigger <Highlight>metacognition</Highlight>—forcing the
          model to evaluate its own output before finalizing:
        </Paragraph>

        <div className="mt-6 space-y-4">
          <VerificationQuestion
            question="Are you sure it makes sense?"
            purpose="Basic sanity check"
          />
          <VerificationQuestion
            question="Is it optimal?"
            purpose="Pushes beyond 'good enough'"
          />
          <VerificationQuestion
            question="Could we change anything to make the system work better for users?"
            purpose="User-centric optimization"
          />
          <VerificationQuestion
            question="Check over each bead super carefully"
            purpose="Item-by-item review"
          />
        </div>

        <div className="mt-6">
          <CodeBlock
            code={`# The Plan Review Pattern
"Check over each bead super carefully—
are you sure it makes sense?
Is it optimal?
Could we change anything to make the system work better?
If so, revise the beads.

It's a lot easier and faster to operate in 'plan space'
before we start implementing these things!"`}
          />
        </div>

        <div className="mt-6">
          <TipBox variant="tip">
            <strong>Plan Space Principle:</strong> Revising plans is 10x cheaper
            than debugging implementations. Force verification at the planning
            stage.
          </TipBox>
        </div>
      </Section>

      <Divider />

      {/* Pattern 4: Fresh Eyes Technique */}
      <Section
        title="Pattern 4: The Fresh Eyes Technique"
        icon={<Eye className="h-5 w-5" />}
        delay={0.3}
      >
        <Paragraph>
          <Highlight>Psychological reset techniques</Highlight> help agents
          approach code without prior assumptions or confirmation bias:
        </Paragraph>

        <div className="mt-6 space-y-4">
          <FreshEyesCard
            technique="Explicit Reset"
            example='with "fresh eyes"'
            mechanism="Signals to discard prior assumptions"
          />
          <FreshEyesCard
            technique="Random Exploration"
            example='"randomly explore the code files"'
            mechanism="Avoids tunnel vision on expected locations"
          />
          <FreshEyesCard
            technique="Peer Framing"
            example='"reviewing code written by your fellow agents"'
            mechanism="Creates psychological distance from own work"
          />
        </div>

        <div className="mt-6">
          <CodeBlock
            code={`# The Fresh Eyes Code Review
"I want you to carefully read over all of the new code
you just wrote and other existing code you just modified
with 'fresh eyes' looking super carefully for any obvious
bugs, errors, problems, issues, confusion, etc.
Carefully fix anything you uncover."

# Peer Review Framing
"Turn your attention to reviewing the code written by
your fellow agents and checking for any issues, bugs,
errors, problems, inefficiencies, security problems,
reliability issues, etc. and carefully diagnose their
underlying root causes using first-principle analysis."`}
          />
        </div>
      </Section>

      <Divider />

      {/* Pattern 5: Temporal Awareness */}
      <Section
        title="Pattern 5: Temporal Awareness"
        icon={<Clock className="h-5 w-5" />}
        delay={0.35}
      >
        <Paragraph>
          Great prompts consider <Highlight>future contexts</Highlight>—the
          agent that will continue this work, the human who will review it, the
          &quot;future self&quot; who needs to understand it:
        </Paragraph>

        <div className="mt-6">
          <CodeBlock
            code={`# Self-Documenting Output
"Create a comprehensive set of beads with detailed comments
so that the whole thing is totally self-contained and
self-documenting (including relevant background,
reasoning/justification, considerations, etc.—
anything we'd want our 'future self' to know about
the goals and intentions and thought process and how it
serves the over-arching goals of the project)."`}
          />
        </div>

        <div className="mt-6 space-y-3">
          <TemporalConcept
            concept="Future Self"
            description="Write as if explaining to someone with no context"
          />
          <TemporalConcept
            concept="Self-Contained"
            description="Output should work independently of current conversation"
          />
          <TemporalConcept
            concept="Over-Arching Goals"
            description="Connect current work to bigger picture"
          />
        </div>
      </Section>

      <Divider />

      {/* Pattern 6: Context Anchoring */}
      <Section
        title="Pattern 6: Context Anchoring"
        icon={<Anchor className="h-5 w-5" />}
        delay={0.4}
      >
        <Paragraph>
          <Highlight>Stable reference documents</Highlight> (like AGENTS.md)
          serve as behavioral anchors. Re-reading them is especially critical
          after context compaction.
        </Paragraph>

        <div className="mt-6">
          <CodeBlock
            code={`# The Post-Compaction Refresh
"Reread AGENTS.md so it's still fresh in your mind.
Use ultrathink."`}
          />
        </div>

        <div className="mt-6">
          <TipBox variant="warning">
            <strong>Why this matters after compaction:</strong>
            <br /><br />
            1. <strong>Context decay:</strong> Rules lose salience as more
            content is added
            <br />
            2. <strong>Summarization loss:</strong> Compaction may miss nuances
            <br />
            3. <strong>Drift prevention:</strong> Periodic grounding prevents
            behavioral divergence
            <br />
            4. <strong>Fresh frame:</strong> Re-reading establishes correct
            operating context
          </TipBox>
        </div>

        <div className="mt-6">
          <CodeBlock
            code={`# Grounding Throughout Work
"Be sure to comply with ALL rules in AGENTS.md and
ensure that any code you write or revise conforms to
the best practice guides referenced in the AGENTS.md file."

# Making Rules Explicit
"You may NOT delete any file or directory unless I
explicitly give the exact command in this session."`}
          />
        </div>
      </Section>

      <Divider />

      {/* Pattern 7: First Principles */}
      <Section
        title="Pattern 7: First Principles Analysis"
        icon={<Layers className="h-5 w-5" />}
        delay={0.45}
      >
        <Paragraph>
          Push for <Highlight>deep understanding</Highlight> over surface-level
          pattern matching:
        </Paragraph>

        <div className="mt-6">
          <CodeBlock
            code={`# Root Cause Emphasis
"Carefully diagnose their underlying root causes
using first-principle analysis and then fix or
revise them if necessary."

# Context Before Action
"Once you understand the purpose of the code in
the larger context of the workflows, I want you
to do a super careful, methodical check..."`}
          />
        </div>

        <div className="mt-6 space-y-3">
          <PrincipleCard
            principle="Understand Before Fixing"
            description="Trace execution flows and dependencies first"
          />
          <PrincipleCard
            principle="Root Cause Over Symptom"
            description="Diagnose underlying issues, not surface manifestations"
          />
          <PrincipleCard
            principle="Larger Context"
            description="Understand how code fits into overall workflows"
          />
        </div>
      </Section>

      <Divider />

      {/* Putting It Together */}
      <Section
        title="Putting It All Together"
        icon={<Lightbulb className="h-5 w-5" />}
        delay={0.5}
      >
        <Paragraph>
          Here&apos;s a real prompt that combines multiple patterns:
        </Paragraph>

        <div className="mt-6">
          <CodeBlock
            code={`"Reread AGENTS.md so it's still fresh in your mind.
Use ultrathink.

I want you to sort of randomly explore the code files
in this project, choosing code files to deeply investigate
and understand and trace their functionality and execution
flows through the related code files which they import or
which they are imported by.

Once you understand the purpose of the code in the larger
context of the workflows, I want you to do a super careful,
methodical, and critical check with 'fresh eyes' to find
any obvious bugs, problems, errors, issues, silly mistakes,
etc. and then systematically and meticulously and
intelligently correct them.

Be sure to comply with ALL rules in AGENTS.md and ensure
that any code you write or revise conforms to the best
practice guides referenced in the AGENTS.md file."`}
            language="markdown"
          />
        </div>

        <div className="mt-6">
          <PatternBreakdown />
        </div>
      </Section>

      <Divider />

      {/* Quick Reference */}
      <Section
        title="Quick Reference"
        icon={<FileText className="h-5 w-5" />}
        delay={0.55}
      >
        <div className="space-y-4">
          <QuickRefItem
            pattern="Intensity"
            when="Tasks requiring maximum precision"
            key_phrases="super carefully, methodical, use ultrathink"
          />
          <QuickRefItem
            pattern="Scope Expansion"
            when="Avoiding narrow focus or shortcuts"
            key_phrases="take ALL, cast wider net, comprehensive"
          />
          <QuickRefItem
            pattern="Self-Verification"
            when="Before implementing or finalizing"
            key_phrases="are you sure?, is it optimal?, revise if needed"
          />
          <QuickRefItem
            pattern="Fresh Eyes"
            when="Code review, finding missed issues"
            key_phrases="fresh eyes, fellow agents, randomly explore"
          />
          <QuickRefItem
            pattern="Temporal"
            when="Creating persistent artifacts"
            key_phrases="future self, self-documenting, self-contained"
          />
          <QuickRefItem
            pattern="Anchoring"
            when="After compaction or drift risk"
            key_phrases="reread AGENTS.md, comply with ALL rules"
          />
          <QuickRefItem
            pattern="First Principles"
            when="Debugging or understanding complex code"
            key_phrases="root causes, first-principle, larger context"
          />
        </div>
      </Section>
    </div>
  );
}

// =============================================================================
// INTENSITY EXAMPLE
// =============================================================================
function IntensityExample({
  phrase,
  effect,
}: {
  phrase: string;
  effect: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      whileHover={{ x: 4 }}
      className="group flex items-center gap-4 p-4 rounded-xl border border-primary/20 bg-primary/5 transition-all duration-300 hover:border-primary/40"
    >
      <code className="text-primary font-mono font-medium">&quot;{phrase}&quot;</code>
      <span className="text-white/60">→</span>
      <span className="text-white/70">{effect}</span>
    </motion.div>
  );
}

// =============================================================================
// SCOPE CARD
// =============================================================================
function ScopeCard({
  direction,
  phrases,
}: {
  direction: "expand" | "deepen";
  phrases: string[];
}) {
  const isExpand = direction === "expand";
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -4, scale: 1.02 }}
      className={`group rounded-2xl border p-5 backdrop-blur-xl transition-all duration-300 ${
        isExpand
          ? "border-emerald-500/20 bg-emerald-500/5 hover:border-emerald-500/40"
          : "border-blue-500/20 bg-blue-500/5 hover:border-blue-500/40"
      }`}
    >
      <h4 className={`font-bold mb-3 ${isExpand ? "text-emerald-400" : "text-blue-400"}`}>
        {isExpand ? "↔ Breadth" : "↓ Depth"}
      </h4>
      <ul className="space-y-2">
        {phrases.map((phrase) => (
          <li key={phrase} className="text-sm text-white/60 font-mono">
            &quot;{phrase}&quot;
          </li>
        ))}
      </ul>
    </motion.div>
  );
}

// =============================================================================
// VERIFICATION QUESTION
// =============================================================================
function VerificationQuestion({
  question,
  purpose,
}: {
  question: string;
  purpose: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      whileHover={{ x: 4, scale: 1.01 }}
      className="group flex items-start gap-4 p-4 rounded-xl border border-amber-500/20 bg-amber-500/5 transition-all duration-300 hover:border-amber-500/40"
    >
      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-amber-500/20 text-amber-400">
        ?
      </div>
      <div>
        <p className="font-medium text-amber-300 italic">&quot;{question}&quot;</p>
        <p className="text-sm text-white/50 mt-1">→ {purpose}</p>
      </div>
    </motion.div>
  );
}

// =============================================================================
// FRESH EYES CARD
// =============================================================================
function FreshEyesCard({
  technique,
  example,
  mechanism,
}: {
  technique: string;
  example: string;
  mechanism: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ x: 4, scale: 1.01 }}
      className="group rounded-2xl border border-violet-500/20 bg-violet-500/5 p-5 backdrop-blur-xl transition-all duration-300 hover:border-violet-500/40"
    >
      <div className="flex items-center gap-3 mb-3">
        <Eye className="h-5 w-5 text-violet-400" />
        <h4 className="font-bold text-violet-300">{technique}</h4>
      </div>
      <code className="text-sm text-white/70 font-mono">{example}</code>
      <p className="text-sm text-white/50 mt-2">↳ {mechanism}</p>
    </motion.div>
  );
}

// =============================================================================
// TEMPORAL CONCEPT
// =============================================================================
function TemporalConcept({
  concept,
  description,
}: {
  concept: string;
  description: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      whileHover={{ x: 4 }}
      className="group flex items-center gap-4 p-3 rounded-lg border border-white/[0.08] bg-white/[0.02] transition-all duration-300 hover:border-white/[0.15]"
    >
      <Clock className="h-4 w-4 text-primary shrink-0" />
      <span className="font-medium text-white">{concept}</span>
      <span className="text-white/40">—</span>
      <span className="text-sm text-white/50">{description}</span>
    </motion.div>
  );
}

// =============================================================================
// PRINCIPLE CARD
// =============================================================================
function PrincipleCard({
  principle,
  description,
}: {
  principle: string;
  description: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      whileHover={{ x: 4 }}
      className="group flex items-center gap-4 p-3 rounded-lg border border-blue-500/20 bg-blue-500/5 transition-all duration-300 hover:border-blue-500/40"
    >
      <Layers className="h-4 w-4 text-blue-400 shrink-0" />
      <span className="font-medium text-blue-300">{principle}</span>
      <span className="text-white/40">—</span>
      <span className="text-sm text-white/50">{description}</span>
    </motion.div>
  );
}

// =============================================================================
// PATTERN BREAKDOWN
// =============================================================================
function PatternBreakdown() {
  const patterns = [
    { name: "Anchoring", line: "Reread AGENTS.md..." },
    { name: "Intensity", line: "Use ultrathink" },
    { name: "Fresh Eyes", line: "randomly explore" },
    { name: "Scope (depth)", line: "deeply investigate and understand" },
    { name: "First Principles", line: "trace their functionality" },
    { name: "Context First", line: "Once you understand...larger context" },
    { name: "Intensity (stacked)", line: "super careful, methodical, and critical" },
    { name: "Fresh Eyes", line: 'with "fresh eyes"' },
    { name: "Scope (breadth)", line: "any obvious bugs, problems, errors, issues..." },
    { name: "Intensity (triple)", line: "systematically and meticulously and intelligently" },
    { name: "Anchoring", line: "comply with ALL rules" },
  ];

  return (
    <div className="rounded-2xl border border-white/[0.08] bg-white/[0.02] p-6 backdrop-blur-xl">
      <h4 className="font-bold text-white mb-4">Pattern Analysis</h4>
      <div className="space-y-2">
        {patterns.map((p, i) => (
          <div key={i} className="flex items-center gap-3 text-sm">
            <span className="w-32 shrink-0 text-primary font-medium">{p.name}</span>
            <span className="text-white/40">←</span>
            <code className="text-white/60 font-mono text-xs">&quot;{p.line}&quot;</code>
          </div>
        ))}
      </div>
    </div>
  );
}

// =============================================================================
// QUICK REF ITEM
// =============================================================================
function QuickRefItem({
  pattern,
  when,
  key_phrases,
}: {
  pattern: string;
  when: string;
  key_phrases: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, x: -10 }}
      animate={{ opacity: 1, x: 0 }}
      whileHover={{ x: 4, scale: 1.01 }}
      className="group grid grid-cols-3 gap-4 p-4 rounded-xl border border-white/[0.08] bg-white/[0.02] transition-all duration-300 hover:border-primary/30"
    >
      <div>
        <span className="text-xs text-white/40 uppercase">Pattern</span>
        <p className="font-bold text-primary">{pattern}</p>
      </div>
      <div>
        <span className="text-xs text-white/40 uppercase">When</span>
        <p className="text-sm text-white/70">{when}</p>
      </div>
      <div>
        <span className="text-xs text-white/40 uppercase">Key Phrases</span>
        <p className="text-xs text-white/50 font-mono">{key_phrases}</p>
      </div>
    </motion.div>
  );
}
