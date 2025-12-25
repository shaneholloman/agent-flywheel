"use client";

import Link from "next/link";
import { useState, useEffect, useCallback } from "react";
import {
  ArrowLeft,
  BookOpen,
  ChevronRight,
  Home,
  Search,
  Terminal,
  Zap,
  Keyboard,
  X,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { CodeBlock } from "@/components/command-card";
import { motion, AnimatePresence, springs, staggerContainer, fadeUp } from "@/components/motion";
import { useScrollReveal } from "@/lib/hooks/useScrollReveal";
import { cn } from "@/lib/utils";
import {
  AgentHeroCard,
  AgentCardContent,
  AgentCarousel,
  QuickAccessBar,
  type AgentInfo,
} from "@/components/agent-commands";

const agents: AgentInfo[] = [
  {
    id: "claude",
    name: "Claude Code",
    command: "claude",
    aliases: ["cc"],
    description:
      "Anthropic's powerful coding agent. Uses Claude Opus 4.5 with deep reasoning capabilities. Best for complex architecture decisions and nuanced code understanding.",
    model: "Claude Opus 4.5",
    icon: "C",
    examples: [
      { command: "cc", description: "Start interactive REPL session" },
      { command: 'cc "fix the authentication bug in auth.ts"', description: "Direct prompt with task" },
      { command: "claude --continue", description: "Continue most recent session" },
      { command: "/compact", description: "Compress context (type inside cc session)" },
      { command: 'cc "review this PR" --print', description: "Output-only mode (no REPL)" },
    ],
    tips: [
      "Use /compact when context gets full",
      "Start with cc for quick sessions",
      "Combine with ultrathink prompts for complex reasoning",
      "Use claude --continue to continue your last session",
    ],
  },
  {
    id: "codex",
    name: "Codex CLI",
    command: "codex",
    aliases: ["cod"],
    description:
      "OpenAI's coding agent. Uses GPT-5.2-Codex with high or extra high effort settings. Excellent for code generation, refactoring, and following structured instructions.",
    model: "GPT-5.2-Codex",
    icon: "O",
    examples: [
      { command: "cod", description: "Start interactive session" },
      { command: 'cod "add unit tests for utils.ts"', description: "Direct prompt with task" },
      { command: 'cod "explain this code" --effort extra-high', description: "Use extra high effort for complex reasoning" },
      { command: "cod --help", description: "Show all options" },
    ],
    tips: [
      "Good for structured, step-by-step tasks",
      "Use --effort high or extra-high for complex reasoning",
      "Works well with clear, specific prompts",
    ],
  },
  {
    id: "gemini",
    name: "Gemini CLI",
    command: "gemini",
    aliases: ["gmi"],
    description:
      "Google's coding agent. Uses Gemini 3 with large context windows. Great for analyzing large codebases and multi-file understanding.",
    model: "Gemini 3",
    icon: "G",
    examples: [
      { command: "gmi", description: "Start interactive session" },
      { command: 'gmi "analyze the project structure"', description: "Direct prompt with task" },
      { command: "gmi --yolo", description: "Explicit YOLO mode (already default in vibe alias)" },
      { command: "gmi --help", description: "Show all options" },
    ],
    tips: [
      "Leverage the large context window for big codebases",
      "Good for exploration and understanding",
      "Use sandbox mode for safer experimentation",
    ],
  },
];

export default function AgentCommandsPage() {
  const [searchQuery, setSearchQuery] = useState("");
  const [expandedAgents, setExpandedAgents] = useState<Set<string>>(new Set());
  const [mobileIndex, setMobileIndex] = useState(0);
  const [showKeyboardHints, setShowKeyboardHints] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  const { ref: heroRef, isInView: heroInView } = useScrollReveal({ threshold: 0.1 });
  const { ref: contentRef, isInView: contentInView } = useScrollReveal({ threshold: 0.05 });

  // Detect mobile
  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener("resize", checkMobile);
    return () => window.removeEventListener("resize", checkMobile);
  }, []);

  // Keyboard navigation
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (
        document.activeElement?.tagName === "INPUT" ||
        document.activeElement?.tagName === "TEXTAREA"
      ) {
        return;
      }

      // "/" to focus search
      if (e.key === "/" && !e.metaKey && !e.ctrlKey) {
        e.preventDefault();
        document.querySelector<HTMLInputElement>('input[type="text"]')?.focus();
      }

      // "?" to toggle keyboard hints
      if (e.key === "?" && !e.metaKey && !e.ctrlKey) {
        setShowKeyboardHints((prev) => !prev);
      }

      // Escape to collapse all or close hints
      if (e.key === "Escape") {
        if (showKeyboardHints) {
          setShowKeyboardHints(false);
        } else {
          setExpandedAgents(new Set());
        }
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [showKeyboardHints]);

  const toggleAgent = useCallback((agentId: string) => {
    setExpandedAgents((prev) => {
      const next = new Set(prev);
      if (next.has(agentId)) {
        next.delete(agentId);
      } else {
        next.add(agentId);
      }
      return next;
    });
  }, []);

  const filteredAgents = agents.filter(
    (agent) =>
      agent.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      agent.command.toLowerCase().includes(searchQuery.toLowerCase()) ||
      agent.aliases.some((a) => a.toLowerCase().includes(searchQuery.toLowerCase())) ||
      agent.description.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="relative min-h-screen bg-background">
      {/* Background effects */}
      <div className="pointer-events-none fixed inset-0 bg-gradient-cosmic opacity-50" />
      <div className="pointer-events-none fixed inset-0 bg-grid-pattern opacity-20" />

      {/* Floating orbs - hidden on mobile for performance */}
      <div className="pointer-events-none fixed -left-40 top-1/4 hidden h-80 w-80 rounded-full bg-[oklch(0.75_0.18_195/0.08)] blur-[100px] sm:block" />
      <div className="pointer-events-none fixed -right-40 bottom-1/3 hidden h-80 w-80 rounded-full bg-[oklch(0.7_0.2_330/0.08)] blur-[100px] sm:block" />

      <div className={cn(
        "relative mx-auto max-w-7xl px-4 py-6 sm:px-6 md:px-8 md:py-10",
        isMobile && "pb-32" // Space for QuickAccessBar
      )}>
        {/* Header - 48px touch targets */}
        <motion.div
          className="mb-6 flex items-center justify-between sm:mb-8"
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={springs.smooth}
        >
          <Link
            href="/learn"
            className="flex min-h-[48px] items-center gap-2 text-muted-foreground transition-colors hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
            <span className="text-sm">Learning Hub</span>
          </Link>
          <div className="flex items-center gap-2">
            {/* Keyboard hints toggle - desktop only */}
            <button
              type="button"
              onClick={() => setShowKeyboardHints((prev) => !prev)}
              className="hidden min-h-[48px] items-center gap-2 rounded-lg px-3 text-muted-foreground transition-colors hover:text-foreground lg:flex"
              aria-label="Toggle keyboard shortcuts"
            >
              <Keyboard className="h-4 w-4" />
              <span className="text-sm">Shortcuts</span>
            </button>
            <Link
              href="/"
              className="flex min-h-[48px] items-center gap-2 text-muted-foreground transition-colors hover:text-foreground"
            >
              <Home className="h-4 w-4" />
              <span className="text-sm">Home</span>
            </Link>
          </div>
        </motion.div>

        {/* Hero section */}
        <motion.div
          ref={heroRef as React.RefObject<HTMLDivElement>}
          className="mb-8 text-center sm:mb-10"
          initial={{ opacity: 0, y: 20 }}
          animate={heroInView ? { opacity: 1, y: 0 } : { opacity: 0, y: 20 }}
          transition={springs.smooth}
        >
          <motion.div
            className="mb-4 flex justify-center"
            whileHover={{ scale: 1.05, rotate: 5 }}
            transition={springs.snappy}
          >
            <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-primary/10 shadow-lg shadow-primary/20">
              <Terminal className="h-8 w-8 text-primary" />
            </div>
          </motion.div>
          <h1 className="mb-3 text-3xl font-bold tracking-tight md:text-4xl">
            Agent Commands
          </h1>
          <p className="mx-auto max-w-xl text-base text-muted-foreground sm:text-lg">
            Quick reference for Claude Code, Codex CLI, and Gemini CLI. Click any card to explore commands and tips.
          </p>
        </motion.div>

        {/* Search - desktop only */}
        <motion.div
          className="relative mb-8 hidden sm:block"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...springs.smooth, delay: 0.1 }}
        >
          <Search className="absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search agents, commands, or features... (press / to focus)"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            aria-label="Search agents, commands, or features"
            className="w-full rounded-xl border border-border/50 bg-card/50 py-3 pl-12 pr-4 text-foreground backdrop-blur-sm placeholder:text-muted-foreground focus:border-primary/40 focus:outline-none focus:ring-2 focus:ring-primary/20"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => setSearchQuery("")}
              className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              aria-label="Clear search"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </motion.div>

        {/* Quick start banner */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...springs.smooth, delay: 0.15 }}
          className="mb-8 sm:mb-10"
        >
          <Card className="overflow-hidden border-primary/20 bg-primary/5 backdrop-blur-sm">
            <div className="flex flex-col gap-4 p-4 sm:flex-row sm:items-center sm:p-5">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10">
                <Zap className="h-5 w-5 text-primary" />
              </div>
              <div className="flex-1">
                <h2 className="mb-1 font-semibold">Quick Start</h2>
                <p className="text-sm text-muted-foreground">
                  All three agents are pre-installed. Just type the alias:
                </p>
              </div>
              <div className="flex flex-wrap gap-3">
                {[
                  { alias: "cc", label: "Claude", gradient: "from-orange-400 to-amber-500" },
                  { alias: "cod", label: "Codex", gradient: "from-emerald-400 to-teal-500" },
                  { alias: "gmi", label: "Gemini", gradient: "from-blue-400 to-indigo-500" },
                ].map((item) => (
                  <div key={item.alias} className="flex items-center gap-2">
                    <code className={cn(
                      "rounded-lg px-3 py-1.5 font-mono text-sm font-medium text-white",
                      `bg-gradient-to-r ${item.gradient}`
                    )}>
                      {item.alias}
                    </code>
                    <span className="hidden text-sm text-muted-foreground sm:inline">
                      {item.label}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </Card>
        </motion.div>

        {/* Agent cards - responsive layout */}
        <motion.div
          ref={contentRef as React.RefObject<HTMLDivElement>}
          initial="hidden"
          animate={contentInView ? "visible" : "hidden"}
          variants={staggerContainer}
        >
          {/* Desktop: 3-column grid */}
          <div className="hidden md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-6">
            {filteredAgents.length > 0 ? (
              filteredAgents.map((agent, index) => (
                <motion.div key={agent.id} variants={fadeUp}>
                  <div className="h-full">
                    <AgentHeroCard
                      agent={agent}
                      isExpanded={expandedAgents.has(agent.id)}
                      onToggle={() => toggleAgent(agent.id)}
                      index={index}
                    />
                    <AgentCardContent
                      agent={agent}
                      isExpanded={expandedAgents.has(agent.id)}
                    />
                  </div>
                </motion.div>
              ))
            ) : (
              <motion.div
                className="col-span-full py-12 text-center"
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={springs.smooth}
              >
                <Search className="mx-auto mb-4 h-12 w-12 text-muted-foreground/50" />
                <p className="text-muted-foreground">No agents match your search.</p>
              </motion.div>
            )}
          </div>

          {/* Mobile: Swipeable carousel */}
          <div className="md:hidden">
            {filteredAgents.length > 0 ? (
              <AgentCarousel
                agents={filteredAgents}
                currentIndex={Math.min(mobileIndex, filteredAgents.length - 1)}
                onIndexChange={setMobileIndex}
              >
                {(agent, index) => (
                  <div>
                    <AgentHeroCard
                      agent={agent}
                      isExpanded={expandedAgents.has(agent.id)}
                      onToggle={() => toggleAgent(agent.id)}
                      index={index}
                    />
                    <AgentCardContent
                      agent={agent}
                      isExpanded={expandedAgents.has(agent.id)}
                    />
                  </div>
                )}
              </AgentCarousel>
            ) : (
              <div className="py-12 text-center">
                <Search className="mx-auto mb-4 h-12 w-12 text-muted-foreground/50" />
                <p className="text-muted-foreground">No agents match your search.</p>
              </div>
            )}
          </div>
        </motion.div>

        {/* Multi-agent workflow */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...springs.smooth, delay: 0.3 }}
          className="mt-10 sm:mt-12"
        >
          <Card className="overflow-hidden border-border/50 bg-card/50 p-6 backdrop-blur-sm">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <BookOpen className="h-5 w-5 text-primary" />
              Multi-Agent Workflow with NTM
            </h2>
            <p className="mb-4 text-sm text-muted-foreground">
              Use NTM (Named Tmux Manager) to run multiple agents in parallel:
            </p>
            <CodeBlock
              code={`# Spawn 2 Claude, 1 Codex, 1 Gemini in parallel
ntm spawn myproject --cc=2 --cod=1 --gmi=1

# Send prompt to all Claude agents
ntm send myproject --cc "implement the new feature"

# Send prompt to all agents
ntm send myproject "review and test your changes"`}
              language="bash"
            />
            <div className="mt-4">
              <Link
                href="/learn/ntm-palette"
                className="inline-flex items-center gap-1 text-sm text-primary hover:underline"
              >
                Learn more about NTM commands
                <ChevronRight className="h-4 w-4" />
              </Link>
            </div>
          </Card>
        </motion.div>

        {/* Footer */}
        <motion.div
          className="mt-10 text-center text-sm text-muted-foreground sm:mt-12"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ ...springs.smooth, delay: 0.4 }}
        >
          <p>
            Back to{" "}
            <Link href="/learn" className="text-primary hover:underline">
              Learning Hub &rarr;
            </Link>
          </p>
        </motion.div>
      </div>

      {/* Mobile Quick Access Bar */}
      {isMobile && <QuickAccessBar />}

      {/* Keyboard shortcuts overlay */}
      <AnimatePresence>
        {showKeyboardHints && (
          <motion.div
            className="fixed inset-0 z-50 flex items-center justify-center bg-background/80 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setShowKeyboardHints(false)}
          >
            <motion.div
              className="mx-4 w-full max-w-sm rounded-2xl border border-border/50 bg-card p-6 shadow-xl"
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.95, opacity: 0 }}
              transition={springs.snappy}
              onClick={(e) => e.stopPropagation()}
            >
              <div className="mb-4 flex items-center justify-between">
                <h3 className="text-lg font-semibold">Keyboard Shortcuts</h3>
                <button
                  type="button"
                  onClick={() => setShowKeyboardHints(false)}
                  className="rounded-lg p-2 text-muted-foreground hover:bg-muted"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
              <div className="space-y-3">
                {[
                  { key: "1 / 2 / 3", action: "Focus agent card" },
                  { key: "/", action: "Focus search" },
                  { key: "Enter", action: "Expand/collapse card" },
                  { key: "Esc", action: "Collapse all" },
                  { key: "?", action: "Toggle this menu" },
                ].map((shortcut) => (
                  <div key={shortcut.key} className="flex items-center justify-between">
                    <span className="text-sm text-muted-foreground">{shortcut.action}</span>
                    <kbd className="rounded bg-muted px-2 py-1 font-mono text-xs">
                      {shortcut.key}
                    </kbd>
                  </div>
                ))}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
