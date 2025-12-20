"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import { AlertCircle, Stethoscope } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CommandCard } from "@/components/command-card";
import { AlertCard, OutputPreview } from "@/components/alert-card";
import { markStepComplete } from "@/lib/wizardSteps";

const QUICK_CHECKS = [
  {
    command: "cc --version",
    description: "Check Claude Code is installed",
  },
  {
    command: "bun --version",
    description: "Check bun is installed",
  },
  {
    command: "which tmux",
    description: "Check tmux is installed",
  },
];

export default function StatusCheckPage() {
  const router = useRouter();
  const [isNavigating, setIsNavigating] = useState(false);

  const handleContinue = useCallback(() => {
    markStepComplete(9);
    setIsNavigating(true);
    router.push("/wizard/launch-onboarding");
  }, [router]);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20">
            <Stethoscope className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h1 className="bg-gradient-to-r from-foreground via-foreground to-muted-foreground bg-clip-text text-2xl font-bold tracking-tight text-transparent sm:text-3xl">
              ACFS status check
            </h1>
            <p className="text-sm text-muted-foreground">
              ~1 min
            </p>
          </div>
        </div>
        <p className="text-muted-foreground">
          Let&apos;s verify everything installed correctly.
        </p>
      </div>

      {/* Doctor command */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold text-foreground">Run the doctor command</h2>
        <p className="text-sm text-muted-foreground">
          This checks all installed tools and reports any issues:
        </p>
        <CommandCard
          command="acfs doctor"
          description="Run ACFS health check"
          showCheckbox
          persistKey="acfs-doctor"
        />
      </div>

      {/* Expected output */}
      <OutputPreview title="Expected output">
        <div className="space-y-1 font-mono text-xs">
          <p className="text-muted-foreground">ACFS Doctor - System Health Check</p>
          <p className="text-muted-foreground">================================</p>
          <p className="text-[oklch(0.72_0.19_145)]">✔ Shell: zsh with oh-my-zsh</p>
          <p className="text-[oklch(0.72_0.19_145)]">✔ Languages: bun, uv, rust, go</p>
          <p className="text-[oklch(0.72_0.19_145)]">✔ Tools: tmux, ripgrep, lazygit</p>
          <p className="text-[oklch(0.72_0.19_145)]">✔ Agents: claude-code, codex</p>
          <p className="mt-2 text-foreground">All checks passed!</p>
        </div>
      </OutputPreview>

      {/* Quick spot checks */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold">Quick spot checks</h2>
        <p className="text-sm text-muted-foreground">
          Try a few commands to verify key tools:
        </p>
        <div className="space-y-3">
          {QUICK_CHECKS.map((check, i) => (
            <CommandCard
              key={i}
              command={check.command}
              description={check.description}
            />
          ))}
        </div>
      </div>

      {/* Troubleshooting */}
      <AlertCard variant="warning" icon={AlertCircle} title="Something not working?">
        Try running{" "}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">source ~/.zshrc</code> to
        reload your shell config, then try the doctor again.
      </AlertCard>

      {/* Continue button */}
      <div className="flex justify-end pt-4">
        <Button onClick={handleContinue} disabled={isNavigating} size="lg">
          {isNavigating ? "Loading..." : "Everything looks good!"}
        </Button>
      </div>
    </div>
  );
}
