"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Terminal, ChevronDown } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CommandCard } from "@/components/command-card";
import { AlertCard, OutputPreview } from "@/components/alert-card";
import { cn } from "@/lib/utils";
import { markStepComplete } from "@/lib/wizardSteps";
import { useVPSIP, useUserOS, useMounted } from "@/lib/userPreferences";

interface TroubleshootingItem {
  error: string;
  causes: string[];
  solutions: string[];
}

const TROUBLESHOOTING: TroubleshootingItem[] = [
  {
    error: "Permission denied (publickey)",
    causes: [
      "SSH key wasn't added to the VPS during creation",
      "Using the wrong SSH key file",
      "Key file permissions are too open",
    ],
    solutions: [
      "Check your VPS provider's control panel - is your SSH key listed?",
      "Make sure you're using the acfs_ed25519 key file",
      "On Mac/Linux: run chmod 600 ~/.ssh/acfs_ed25519",
    ],
  },
  {
    error: "Connection refused",
    causes: [
      "VPS is still starting up",
      "SSH service not running on the VPS",
      "Firewall blocking port 22",
    ],
    solutions: [
      "Wait 2-5 minutes for the VPS to fully boot",
      "Check your VPS provider's status page",
      "Use the VPS console in your provider's control panel to check",
    ],
  },
  {
    error: "Connection timed out",
    causes: [
      "Wrong IP address",
      "VPS is offline",
      "Network issue between you and the VPS",
    ],
    solutions: [
      "Double-check the IP address in your provider's control panel",
      "Try pinging the IP: ping YOUR_IP",
      "Check if your VPS is running in the control panel",
    ],
  },
  {
    error: "Host key verification failed",
    causes: [
      "You've connected to this IP before with a different VPS",
      "The server was reinstalled",
    ],
    solutions: [
      "Remove the old key: ssh-keygen -R YOUR_IP",
      "Then try connecting again",
    ],
  },
];

function TroubleshootingSection({
  item,
  isExpanded,
  onToggle,
}: {
  item: TroubleshootingItem;
  isExpanded: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="rounded-lg border">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={isExpanded}
        className="flex w-full items-center justify-between p-3 text-left hover:bg-muted/50"
      >
        <span className="font-medium text-destructive">{item.error}</span>
        <ChevronDown
          className={cn(
            "h-4 w-4 text-muted-foreground transition-transform",
            isExpanded && "rotate-180"
          )}
        />
      </button>
      {isExpanded && (
        <div className="space-y-3 border-t px-3 pb-3 pt-2 text-sm">
          <div>
            <p className="font-medium">Possible causes:</p>
            <ul className="mt-1 list-disc space-y-1 pl-5 text-muted-foreground">
              {item.causes.map((cause, i) => (
                <li key={i}>{cause}</li>
              ))}
            </ul>
          </div>
          <div>
            <p className="font-medium">Solutions:</p>
            <ul className="mt-1 list-disc space-y-1 pl-5 text-muted-foreground">
              {item.solutions.map((solution, i) => (
                <li key={i}>{solution}</li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </div>
  );
}

export default function SSHConnectPage() {
  const router = useRouter();
  const [vpsIP] = useVPSIP();
  const [os] = useUserOS();
  const [expandedError, setExpandedError] = useState<string | null>(null);
  const [isNavigating, setIsNavigating] = useState(false);
  const mounted = useMounted();

  // Redirect if missing required data (after hydration)
  useEffect(() => {
    if (mounted) {
      if (vpsIP === null) {
        router.push("/wizard/create-vps");
      } else if (os === null) {
        router.push("/wizard/os-selection");
      }
    }
  }, [mounted, vpsIP, os, router]);

  const handleContinue = useCallback(() => {
    markStepComplete(6);
    setIsNavigating(true);
    router.push("/wizard/run-installer");
  }, [router]);

  if (!mounted || !vpsIP || !os) {
    return (
      <div className="flex items-center justify-center py-12">
        <Terminal className="h-8 w-8 animate-pulse text-muted-foreground" />
      </div>
    );
  }

  const sshCommand = `ssh -i ~/.ssh/acfs_ed25519 ubuntu@${vpsIP}`;
  const sshCommandWindows = `ssh -i $HOME\\.ssh\\acfs_ed25519 ubuntu@${vpsIP}`;
  const sshCommandRoot = `ssh -i ~/.ssh/acfs_ed25519 root@${vpsIP}`;
  const sshCommandRootWindows = `ssh -i $HOME\\.ssh\\acfs_ed25519 root@${vpsIP}`;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20">
            <Terminal className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h1 className="bg-gradient-to-r from-foreground via-foreground to-muted-foreground bg-clip-text text-2xl font-bold tracking-tight text-transparent sm:text-3xl">
              SSH into your VPS
            </h1>
            <p className="text-sm text-muted-foreground">
              ~1 min
            </p>
          </div>
        </div>
        <p className="text-muted-foreground">
          Connect to your new VPS for the first time.
        </p>
      </div>

      {/* IP confirmation */}
      <AlertCard variant="info" icon={Terminal}>
        Connecting to:{" "}
        <code className="ml-1 rounded bg-[oklch(0.75_0.18_195/0.15)] px-2 py-0.5 font-mono font-bold text-[oklch(0.85_0.12_195)]">{vpsIP}</code>
      </AlertCard>

      {/* Primary command */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold">Run this command</h2>
        <CommandCard
          command={sshCommand}
          windowsCommand={sshCommandWindows}
          description="Connect as ubuntu user"
          showCheckbox
          persistKey="ssh-connect-ubuntu"
        />
      </div>

      {/* Host key prompt */}
      <AlertCard variant="warning" title="First-time connection prompt">
        You&apos;ll see a message about &quot;authenticity of host&quot;.
        Type <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs text-foreground">yes</code> and press
        Enter. This is normal for first-time connections.
      </AlertCard>

      {/* Fallback to root */}
      <div className="space-y-3">
        <h3 className="font-semibold">
          If &quot;ubuntu&quot; doesn&apos;t work, try root:
        </h3>
        <p className="text-sm text-muted-foreground">
          Some providers use &quot;root&quot; as the default user instead of
          &quot;ubuntu&quot;. If you get &quot;Permission denied&quot; with
          ubuntu, try this:
        </p>
        <CommandCard
          command={sshCommandRoot}
          windowsCommand={sshCommandRootWindows}
          description="Connect as root user (fallback)"
        />
      </div>

      {/* Success indicator */}
      <OutputPreview title="You're connected when you see:">
        <p className="text-[oklch(0.72_0.19_145)]">
          ubuntu@vps:~$ <span className="animate-pulse">_</span>
        </p>
        <p className="mt-2 text-muted-foreground">
          You should see a prompt with your username and &quot;vps&quot; or
          the server hostname.
        </p>
      </OutputPreview>

      {/* Troubleshooting */}
      <div className="space-y-3">
        <h2 className="font-semibold">Having trouble?</h2>
        <div className="space-y-2">
          {TROUBLESHOOTING.map((item) => (
            <TroubleshootingSection
              key={item.error}
              item={item}
              isExpanded={expandedError === item.error}
              onToggle={() =>
                setExpandedError((prev) =>
                  prev === item.error ? null : item.error
                )
              }
            />
          ))}
        </div>
      </div>

      {/* Continue button */}
      <div className="flex justify-end pt-4">
        <Button onClick={handleContinue} disabled={isNavigating} size="lg">
          {isNavigating ? "Loading..." : "I'm connected, continue"}
        </Button>
      </div>
    </div>
  );
}
