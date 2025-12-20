"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Sparkles,
  Clock,
  ExternalLink,
  Check,
  Rocket,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { CommandCard } from "@/components/command-card";
import { AlertCard, OutputPreview, DetailsSection } from "@/components/alert-card";
import { markStepComplete } from "@/lib/wizardSteps";

const ACFS_COMMAND = `curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/install.sh?$(date +%s)" | bash -s -- --yes --mode vibe`;

const WHAT_IT_INSTALLS = [
  {
    category: "Shell & Terminal UX",
    items: ["zsh + oh-my-zsh + powerlevel10k", "atuin (shell history)", "fzf", "zoxide", "lsd"],
  },
  {
    category: "Languages & Package Managers",
    items: ["bun (JavaScript/TypeScript)", "uv (Python)", "rust/cargo", "go"],
  },
  {
    category: "Dev Tools",
    items: ["tmux", "ripgrep", "ast-grep", "lazygit", "bat"],
  },
  {
    category: "Coding Agents",
    items: ["Claude Code", "Codex CLI", "Gemini CLI"],
  },
  {
    category: "Cloud & Database",
    items: ["PostgreSQL 18", "Vault", "Wrangler", "Supabase CLI", "Vercel CLI"],
  },
  {
    category: "Dicklesworthstone Stack",
    items: ["ntm", "mcp_agent_mail", "beads_viewer", "and 5 more tools"],
  },
];

export default function RunInstallerPage() {
  const router = useRouter();
  const [isNavigating, setIsNavigating] = useState(false);

  const handleContinue = useCallback(() => {
    markStepComplete(7);
    setIsNavigating(true);
    router.push("/wizard/reconnect-ubuntu");
  }, [router]);

  return (
    <div className="space-y-8">
      {/* Header with sparkle */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="relative flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-primary/30 to-[oklch(0.7_0.2_330/0.3)] shadow-lg shadow-primary/20">
            <Rocket className="h-6 w-6 text-primary" />
            <Sparkles className="absolute -right-1 -top-1 h-4 w-4 text-[oklch(0.78_0.16_75)] animate-pulse" />
          </div>
          <div>
            <h1 className="bg-gradient-to-r from-primary via-foreground to-[oklch(0.7_0.2_330)] bg-clip-text text-2xl font-bold tracking-tight text-transparent sm:text-3xl">
              Run the ACFS installer
            </h1>
            <p className="text-sm text-muted-foreground">
              ~15 min
            </p>
          </div>
        </div>
        <p className="text-lg text-muted-foreground">
          This is the magic moment. One command sets everything up.
        </p>
      </div>

      {/* Warning */}
      <AlertCard variant="warning" title="Don't close the terminal">
        Stay connected during installation. If disconnected, SSH back in
        and check if it&apos;s still running.
      </AlertCard>

      {/* The command */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold">
          Paste this command in your SSH session
        </h2>
        <CommandCard
          command={ACFS_COMMAND}
          description="ACFS installer one-liner"
          showCheckbox
          persistKey="run-acfs-installer"
          className="border-2 border-primary/20"
        />
      </div>

      {/* Time estimate */}
      <div className="flex items-center gap-2 text-muted-foreground">
        <Clock className="h-5 w-5" />
        <span>Takes about 10-15 minutes depending on your VPS speed</span>
      </div>

      {/* What it installs - collapsible */}
      <DetailsSection summary="What this command installs">
        <div className="grid gap-4 sm:grid-cols-2">
          {WHAT_IT_INSTALLS.map((group) => (
            <div key={group.category}>
              <h4 className="mb-2 font-medium text-foreground">{group.category}</h4>
              <ul className="space-y-1 text-sm text-muted-foreground">
                {group.items.map((item, i) => (
                  <li key={i} className="flex items-center gap-2">
                    <Check className="h-3 w-3 text-[oklch(0.72_0.19_145)]" />
                    {item}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </DetailsSection>

      {/* View source */}
      <div className="flex items-center gap-2 text-sm">
        <span className="text-muted-foreground">
          Want to see exactly what it does?
        </span>
        <a
          href="https://github.com/Dicklesworthstone/agentic_coding_flywheel_setup/blob/main/install.sh"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1 font-medium text-primary hover:underline"
        >
          View install.sh source
          <ExternalLink className="h-3 w-3" />
        </a>
      </div>

      {/* Success signs */}
      <OutputPreview title="You'll know it's done when you see:">
        <p className="text-[oklch(0.72_0.19_145)]">✔ ACFS installation complete!</p>
        <p className="text-muted-foreground">
          Please reconnect as: ssh ubuntu@YOUR_IP
        </p>
      </OutputPreview>

      {/* Continue button */}
      <div className="flex justify-end pt-4">
        <Button onClick={handleContinue} disabled={isNavigating} size="lg">
          {isNavigating ? "Loading..." : "Installation finished"}
        </Button>
      </div>
    </div>
  );
}
