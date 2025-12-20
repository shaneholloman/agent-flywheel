"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  ArrowRight,
  Terminal,
  Rocket,
  ShieldCheck,
  Zap,
  GitBranch,
  Cpu,
  Clock,
  Sparkles,
  ChevronRight,
} from "lucide-react";
import { Button } from "@/components/ui/button";

// Animated terminal lines
const TERMINAL_LINES = [
  { type: "command", text: "curl -fsSL https://acfs.dev/install | bash" },
  { type: "output", text: "▸ Detecting Ubuntu 24.04... ✓" },
  { type: "output", text: "▸ Installing zsh + oh-my-zsh + powerlevel10k..." },
  { type: "output", text: "▸ Installing bun, uv, rust, go..." },
  { type: "output", text: "▸ Installing Claude Code, Codex CLI, Gemini CLI..." },
  { type: "output", text: "▸ Configuring tmux, ripgrep, lazygit..." },
  { type: "output", text: "▸ Setting up Dicklesworthstone stack..." },
  { type: "success", text: "✓ Setup complete! Run 'onboard' to get started." },
];

function AnimatedTerminal() {
  const [visibleLines, setVisibleLines] = useState(0);
  const [cursorVisible, setCursorVisible] = useState(true);

  useEffect(() => {
    const interval = setInterval(() => {
      setVisibleLines((prev) => {
        if (prev >= TERMINAL_LINES.length) {
          return 1; // Reset to loop (keep first line visible to avoid blank frame)
        }
        return prev + 1;
      });
    }, 800);

    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const cursorInterval = setInterval(() => {
      setCursorVisible((prev) => !prev);
    }, 530);
    return () => clearInterval(cursorInterval);
  }, []);

  return (
    <div className="terminal-window animate-scale-in shadow-2xl">
      <div className="terminal-header">
        <div className="terminal-dot terminal-dot-red" />
        <div className="terminal-dot terminal-dot-yellow" />
        <div className="terminal-dot terminal-dot-green" />
        <span className="ml-3 font-mono text-xs text-muted-foreground">
          ubuntu@vps ~
        </span>
      </div>
      <div className="terminal-content min-h-[280px]">
        {TERMINAL_LINES.slice(0, visibleLines).map((line, i) => (
          <div
            key={i}
            className={`terminal-line mb-2 opacity-0 animate-slide-up`}
            style={{ animationDelay: `${i * 0.1}s`, animationFillMode: "forwards" }}
          >
            {line.type === "command" && (
              <>
                <span className="terminal-prompt">$</span>
                <span className="terminal-command">{line.text}</span>
              </>
            )}
            {line.type === "output" && (
              <span className="terminal-output">{line.text}</span>
            )}
            {line.type === "success" && (
              <span className="text-[oklch(0.72_0.19_145)]">{line.text}</span>
            )}
          </div>
        ))}
        {visibleLines <= TERMINAL_LINES.length && (
          <div className="terminal-line">
            <span className="terminal-prompt">$</span>
            <span
              className={`terminal-cursor ${cursorVisible ? "opacity-100" : "opacity-0"}`}
            />
          </div>
        )}
      </div>
    </div>
  );
}

interface FeatureCardProps {
  icon: React.ReactNode;
  title: string;
  description: string;
  gradient: string;
  delay: number;
}

function FeatureCard({ icon, title, description, gradient, delay }: FeatureCardProps) {
  return (
    <div
      className={`group relative overflow-hidden rounded-2xl border border-border/50 bg-card/50 p-6 backdrop-blur-sm transition-all duration-300 hover:border-primary/30 hover:shadow-lg hover:shadow-primary/5 card-hover opacity-0 animate-slide-up`}
      style={{ animationDelay: `${delay}s`, animationFillMode: "forwards" }}
    >
      {/* Gradient glow on hover */}
      <div
        className={`absolute -right-20 -top-20 h-40 w-40 rounded-full opacity-0 blur-3xl transition-opacity duration-500 group-hover:opacity-30 ${gradient}`}
      />

      <div className="relative z-10">
        <div className="mb-4 inline-flex rounded-xl bg-primary/10 p-3 text-primary">
          {icon}
        </div>
        <h3 className="mb-2 text-lg font-semibold tracking-tight">{title}</h3>
        <p className="text-sm leading-relaxed text-muted-foreground">{description}</p>
      </div>
    </div>
  );
}

function StatBadge({ value, label }: { value: string; label: string }) {
  return (
    <div className="flex flex-col items-center gap-1 px-4">
      <span className="text-2xl font-bold text-gradient-cyan">{value}</span>
      <span className="text-xs text-muted-foreground">{label}</span>
    </div>
  );
}

function ToolLogo({ name, color }: { name: string; color: string }) {
  return (
    <div
      className="flex h-10 w-10 items-center justify-center rounded-lg border border-border/50 bg-card/50 text-xs font-bold transition-all hover:scale-110 hover:border-primary/30"
      style={{ color }}
    >
      {name.slice(0, 2).toUpperCase()}
    </div>
  );
}

export default function HomePage() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  return (
    <div className="relative min-h-screen overflow-hidden bg-background">
      {/* Cosmic gradient background */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-hero" />
      <div className="pointer-events-none absolute inset-0 bg-grid-pattern opacity-30" />

      {/* Floating orbs */}
      <div className="pointer-events-none absolute left-1/4 top-1/4 h-96 w-96 rounded-full bg-[oklch(0.75_0.18_195/0.1)] blur-[100px] animate-pulse-glow" />
      <div className="pointer-events-none absolute right-1/4 bottom-1/4 h-80 w-80 rounded-full bg-[oklch(0.7_0.2_330/0.08)] blur-[80px] animate-pulse-glow" style={{ animationDelay: "1s" }} />

      {/* Navigation */}
      <nav className="relative z-20 mx-auto flex max-w-7xl items-center justify-between px-6 py-6">
        <div className="flex items-center gap-2">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/20">
            <Terminal className="h-5 w-5 text-primary" />
          </div>
          <span className="font-mono text-lg font-bold tracking-tight">ACFS</span>
        </div>
        <div className="flex items-center gap-4">
          <a
            href="https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden text-sm text-muted-foreground transition-colors hover:text-foreground sm:block"
          >
            GitHub
          </a>
          <Button asChild size="sm" variant="outline" className="border-primary/30 hover:bg-primary/10">
            <Link href="/wizard/os-selection">
              Get Started
              <ChevronRight className="ml-1 h-4 w-4" />
            </Link>
          </Button>
        </div>
      </nav>

      {/* Hero Section */}
      <main className="relative z-10">
        <section className="mx-auto max-w-7xl px-6 pb-20 pt-12 sm:pt-20">
          <div className="grid gap-12 lg:grid-cols-2 lg:gap-16">
            {/* Left column - Text */}
            <div className="flex flex-col justify-center">
              {/* Badge */}
              <div
                className={`mb-6 inline-flex w-fit items-center gap-2 rounded-full border border-primary/30 bg-primary/10 px-4 py-1.5 text-sm text-primary opacity-0 ${mounted ? "animate-slide-up" : ""}`}
                style={mounted ? { animationDelay: "0.1s", animationFillMode: "forwards" } : undefined}
              >
                <Sparkles className="h-4 w-4" />
                <span>Zero to agentic coding in 30 minutes</span>
              </div>

              {/* Headline */}
              <h1
                className={`mb-6 font-mono text-4xl font-bold leading-tight tracking-tight sm:text-5xl lg:text-6xl opacity-0 ${mounted ? "animate-slide-up" : ""}`}
                style={mounted ? { animationDelay: "0.2s", animationFillMode: "forwards" } : undefined}
              >
                <span className="text-gradient-cosmic">AI Agents</span>
                <br />
                <span className="text-foreground">Coding For You</span>
              </h1>

              {/* Subheadline */}
              <p
                className={`mb-8 max-w-xl text-lg leading-relaxed text-muted-foreground opacity-0 ${mounted ? "animate-slide-up" : ""}`}
                style={mounted ? { animationDelay: "0.3s", animationFillMode: "forwards" } : undefined}
              >
                Transform a fresh Ubuntu VPS into a fully-configured agentic coding
                environment. Claude, Codex, Gemini — all pre-configured with 30+ modern
                developer tools.
              </p>

              {/* CTA Buttons */}
              <div
                className={`flex flex-col gap-3 sm:flex-row sm:items-center opacity-0 ${mounted ? "animate-slide-up" : ""}`}
                style={mounted ? { animationDelay: "0.4s", animationFillMode: "forwards" } : undefined}
              >
                <Button
                  asChild
                  size="lg"
                  className="group relative overflow-hidden bg-primary text-primary-foreground hover:bg-primary/90"
                >
                  <Link href="/wizard/os-selection">
                    <span className="relative z-10 flex items-center gap-2">
                      Start the Wizard
                      <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
                    </span>
                    <span className="absolute inset-0 -z-10 bg-gradient-to-r from-primary via-[oklch(0.7_0.2_330)] to-primary opacity-0 transition-opacity group-hover:opacity-100" style={{ backgroundSize: "200% 100%", animation: "shimmer 2s linear infinite" }} />
                  </Link>
                </Button>
                <Button asChild size="lg" variant="outline" className="border-border/50 hover:bg-muted/50">
                  <a
                    href="https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <GitBranch className="mr-2 h-4 w-4" />
                    View on GitHub
                  </a>
                </Button>
              </div>

              {/* Stats */}
              <div
                className={`mt-10 flex items-center divide-x divide-border/50 opacity-0 ${mounted ? "animate-slide-up" : ""}`}
                style={mounted ? { animationDelay: "0.5s", animationFillMode: "forwards" } : undefined}
              >
                <StatBadge value="30+" label="Tools Installed" />
                <StatBadge value="3" label="AI Agents" />
                <StatBadge value="~30m" label="Setup Time" />
              </div>
            </div>

            {/* Right column - Terminal */}
            <div className="flex items-center justify-center lg:justify-end">
              {mounted && <AnimatedTerminal />}
            </div>
          </div>
        </section>

        {/* Tools ticker */}
        <section className="border-y border-border/30 bg-card/30 py-6">
          <div className="mx-auto max-w-7xl px-6">
            <div className="flex items-center justify-center gap-6 overflow-hidden">
              <span className="shrink-0 text-xs uppercase tracking-widest text-muted-foreground">
                Powered by
              </span>
              <div className="flex items-center gap-4">
                <ToolLogo name="Claude" color="oklch(0.78 0.16 75)" />
                <ToolLogo name="Codex" color="oklch(0.72 0.19 145)" />
                <ToolLogo name="Gemini" color="oklch(0.75 0.18 195)" />
                <ToolLogo name="Bun" color="oklch(0.78 0.16 75)" />
                <ToolLogo name="Rust" color="oklch(0.65 0.22 25)" />
                <ToolLogo name="Go" color="oklch(0.75 0.18 195)" />
                <ToolLogo name="tmux" color="oklch(0.72 0.19 145)" />
                <ToolLogo name="zsh" color="oklch(0.7 0.2 330)" />
              </div>
            </div>
          </div>
        </section>

        {/* Features Grid */}
        <section className="mx-auto max-w-7xl px-6 py-24">
          <div className="mb-12 text-center">
            <h2
              className={`mb-4 font-mono text-3xl font-bold tracking-tight opacity-0 ${mounted ? "animate-slide-up" : ""}`}
              style={mounted ? { animationDelay: "0.6s", animationFillMode: "forwards" } : undefined}
            >
              Everything You Need
            </h2>
            <p
              className={`mx-auto max-w-2xl text-muted-foreground opacity-0 ${mounted ? "animate-slide-up" : ""}`}
              style={mounted ? { animationDelay: "0.7s", animationFillMode: "forwards" } : undefined}
            >
              A single curl command installs and configures your complete agentic coding environment
            </p>
          </div>

          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <FeatureCard
              icon={<Rocket className="h-6 w-6" />}
              title="One-liner Install"
              description="A single command transforms your VPS. No manual configuration, no dependency hell."
              gradient="bg-[oklch(0.75_0.18_195)]"
              delay={0.8}
            />
            <FeatureCard
              icon={<Cpu className="h-6 w-6" />}
              title="Three AI Agents"
              description="Claude Code, Codex CLI, and Gemini CLI — all configured with optimal settings for coding."
              gradient="bg-[oklch(0.7_0.2_330)]"
              delay={0.9}
            />
            <FeatureCard
              icon={<ShieldCheck className="h-6 w-6" />}
              title="Idempotent & Safe"
              description="Re-run anytime. Checkpointed phases resume on failure. SHA256 verified installers."
              gradient="bg-[oklch(0.72_0.19_145)]"
              delay={1.0}
            />
            <FeatureCard
              icon={<Zap className="h-6 w-6" />}
              title="Vibe Mode"
              description="Passwordless sudo, dangerous flags enabled — maximum velocity for throwaway VPS environments."
              gradient="bg-[oklch(0.78_0.16_75)]"
              delay={1.1}
            />
            <FeatureCard
              icon={<Terminal className="h-6 w-6" />}
              title="Modern Shell"
              description="zsh + oh-my-zsh + powerlevel10k with lsd, atuin, fzf, zoxide — developer UX perfected."
              gradient="bg-[oklch(0.65_0.18_290)]"
              delay={1.2}
            />
            <FeatureCard
              icon={<Clock className="h-6 w-6" />}
              title="Interactive Tutorial"
              description="Run 'onboard' after setup for guided lessons from Linux basics to full agentic workflows."
              gradient="bg-[oklch(0.75_0.18_195)]"
              delay={1.3}
            />
          </div>
        </section>

        {/* Flywheel Teaser */}
        <section className="border-t border-border/30 bg-card/20 py-24">
          <div className="mx-auto max-w-7xl px-6">
            <div className="mb-12 text-center">
              <div className="mb-4 flex items-center justify-center gap-3">
                <div className="h-px w-8 bg-gradient-to-r from-transparent via-primary/50 to-transparent" />
                <span className="text-[11px] font-bold uppercase tracking-[0.25em] text-primary">Ecosystem</span>
                <div className="h-px w-8 bg-gradient-to-l from-transparent via-primary/50 to-transparent" />
              </div>
              <h2 className="mb-4 font-mono text-3xl font-bold tracking-tight">
                The Agentic Coding Flywheel
              </h2>
              <p className="mx-auto max-w-2xl text-muted-foreground">
                Eight interconnected tools that transform multi-agent workflows. Each tool enhances the others.
              </p>
            </div>

            {/* Tool preview grid */}
            <div className="grid grid-cols-4 sm:grid-cols-8 gap-4 mb-8">
              {[
                { name: "NTM", color: "from-sky-400 to-blue-500", desc: "Agent Orchestration" },
                { name: "Mail", color: "from-violet-400 to-purple-500", desc: "Coordination" },
                { name: "UBS", color: "from-rose-400 to-red-500", desc: "Bug Scanning" },
                { name: "BV", color: "from-emerald-400 to-teal-500", desc: "Task Graph" },
                { name: "CASS", color: "from-cyan-400 to-sky-500", desc: "Search" },
                { name: "CM", color: "from-pink-400 to-fuchsia-500", desc: "Memory" },
                { name: "CAAM", color: "from-amber-400 to-orange-500", desc: "Auth" },
                { name: "SLB", color: "from-yellow-400 to-amber-500", desc: "Safety" },
              ].map((tool, i) => (
                <div key={tool.name} className="flex flex-col items-center gap-2 opacity-0 animate-slide-up" style={{ animationDelay: `${1.4 + i * 0.1}s`, animationFillMode: "forwards" }}>
                  <div className={`flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br ${tool.color} shadow-lg`}>
                    <span className="text-xs font-bold text-white">{tool.name}</span>
                  </div>
                  <span className="text-[10px] text-muted-foreground text-center">{tool.desc}</span>
                </div>
              ))}
            </div>

            <div className="flex justify-center">
              <Button asChild size="lg" variant="outline" className="border-primary/30 hover:bg-primary/10">
                <Link href="/flywheel">
                  Explore the Flywheel
                  <ChevronRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
            </div>
          </div>
        </section>

        {/* Workflow Steps Preview */}
        <section className="border-t border-border/30 bg-card/30 py-24">
          <div className="mx-auto max-w-7xl px-6">
            <div className="mb-12 text-center">
              <h2 className="mb-4 font-mono text-3xl font-bold tracking-tight">
                10 Steps to Liftoff
              </h2>
              <p className="mx-auto max-w-2xl text-muted-foreground">
                The wizard guides you from &quot;I have a laptop&quot; to &quot;AI agents are coding for me&quot;
              </p>
            </div>

            <div className="flex flex-wrap justify-center gap-3">
              {[
                "Choose OS",
                "Install Terminal",
                "Generate SSH Key",
                "Rent VPS",
                "Create Instance",
                "SSH Connect",
                "Run Installer",
                "Reconnect",
                "Status Check",
                "Launch Onboard",
              ].map((step, i) => (
                <div
                  key={step}
                  className="flex items-center gap-2 rounded-full border border-border/50 bg-card/50 px-4 py-2 text-sm transition-all hover:border-primary/30 hover:bg-card"
                >
                  <span className="flex h-5 w-5 items-center justify-center rounded-full bg-primary/20 text-xs font-medium text-primary">
                    {i + 1}
                  </span>
                  <span className="text-foreground">{step}</span>
                </div>
              ))}
            </div>

            <div className="mt-12 flex justify-center">
              <Button asChild size="lg" className="bg-primary text-primary-foreground">
                <Link href="/wizard/os-selection">
                  Start Your Journey
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Link>
              </Button>
            </div>
          </div>
        </section>

        {/* Footer */}
        <footer className="border-t border-border/30 py-12">
          <div className="mx-auto max-w-7xl px-6">
            <div className="flex flex-col items-center justify-between gap-6 sm:flex-row">
              <div className="flex items-center gap-2">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/20">
                  <Terminal className="h-4 w-4 text-primary" />
                </div>
                <span className="font-mono text-sm font-bold">ACFS</span>
              </div>

              <div className="flex items-center gap-6 text-sm text-muted-foreground">
                <a
                  href="https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="transition-colors hover:text-foreground"
                >
                  GitHub
                </a>
                <a
                  href="https://github.com/Dicklesworthstone/ntm"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="transition-colors hover:text-foreground"
                >
                  NTM
                </a>
                <a
                  href="https://github.com/Dicklesworthstone/mcp_agent_mail"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="transition-colors hover:text-foreground"
                >
                  Agent Mail
                </a>
              </div>

              <p className="text-xs text-muted-foreground">
                Built for the agentic coding community
              </p>
            </div>
          </div>
        </footer>
      </main>
    </div>
  );
}
