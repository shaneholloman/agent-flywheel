"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { RefreshCw, Check, UserCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CommandCard } from "@/components/command-card";
import { OutputPreview } from "@/components/alert-card";
import { markStepComplete } from "@/lib/wizardSteps";
import { useVPSIP, useMounted } from "@/lib/userPreferences";

export default function ReconnectUbuntuPage() {
  const router = useRouter();
  const [vpsIP] = useVPSIP();
  const [isNavigating, setIsNavigating] = useState(false);
  const mounted = useMounted();

  // Redirect if no VPS IP (after hydration)
  useEffect(() => {
    if (mounted && vpsIP === null) {
      router.push("/wizard/create-vps");
    }
  }, [mounted, vpsIP, router]);

  const handleContinue = useCallback(() => {
    markStepComplete(8);
    setIsNavigating(true);
    router.push("/wizard/status-check");
  }, [router]);

  const handleSkip = useCallback(() => {
    markStepComplete(8);
    setIsNavigating(true);
    router.push("/wizard/status-check");
  }, [router]);

  if (!mounted || !vpsIP) {
    return (
      <div className="flex items-center justify-center py-12">
        <RefreshCw className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  const sshCommand = `ssh -i ~/.ssh/acfs_ed25519 ubuntu@${vpsIP}`;
  const sshCommandWindows = `ssh -i $HOME\\.ssh\\acfs_ed25519 ubuntu@${vpsIP}`;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20">
            <UserCheck className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h1 className="bg-gradient-to-r from-foreground via-foreground to-muted-foreground bg-clip-text text-2xl font-bold tracking-tight text-transparent sm:text-3xl">
              Reconnect as ubuntu
            </h1>
            <p className="text-sm text-muted-foreground">
              ~1 min
            </p>
          </div>
        </div>
        <p className="text-muted-foreground">
          If you ran the installer as root, reconnect as the ubuntu user to get
          the full shell experience.
        </p>
      </div>

      {/* Already ubuntu? */}
      <div className="rounded-xl border border-[oklch(0.72_0.19_145/0.3)] bg-[oklch(0.72_0.19_145/0.08)] p-4">
        <div className="flex items-start gap-3">
          <Check className="mt-0.5 h-5 w-5 text-[oklch(0.72_0.19_145)]" />
          <div>
            <p className="font-medium text-foreground">Already connected as ubuntu?</p>
            <p className="text-sm text-muted-foreground">
              If your prompt shows <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">ubuntu@</code>, you can skip this step.
            </p>
            <Button
              variant="outline"
              size="sm"
              className="mt-2"
              onClick={handleSkip}
            >
              Skip, I&apos;m already ubuntu
            </Button>
          </div>
        </div>
      </div>

      {/* Reconnect steps */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold">If you connected as root:</h2>

        <div className="space-y-3">
          <p className="text-sm text-muted-foreground">
            1. Type <code className="rounded bg-muted px-1">exit</code> to close
            the current session
          </p>
          <CommandCard command="exit" description="Close root session" />
        </div>

        <div className="space-y-3">
          <p className="text-sm text-muted-foreground">
            2. Reconnect as ubuntu:
          </p>
          <CommandCard
            command={sshCommand}
            windowsCommand={sshCommandWindows}
            description="Reconnect as ubuntu user"
            showCheckbox
            persistKey="reconnect-ubuntu"
          />
        </div>
      </div>

      {/* Verification */}
      <OutputPreview title="You'll know it worked when:">
        <ul className="space-y-1 text-sm">
          <li className="text-[oklch(0.72_0.19_145)]">
            • Your prompt shows <code className="text-muted-foreground">ubuntu@</code> (not <code className="text-muted-foreground">root@</code>)
          </li>
          <li className="text-[oklch(0.72_0.19_145)]">• You see the colorful powerlevel10k prompt</li>
          <li className="text-[oklch(0.72_0.19_145)]">• The shell feels more responsive</li>
        </ul>
      </OutputPreview>

      {/* Continue button */}
      <div className="flex justify-end pt-4">
        <Button onClick={handleContinue} disabled={isNavigating} size="lg">
          {isNavigating ? "Loading..." : "I'm connected as ubuntu"}
        </Button>
      </div>
    </div>
  );
}
