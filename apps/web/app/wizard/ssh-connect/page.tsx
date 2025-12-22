"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Terminal, ChevronDown, BookOpen } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CommandCard } from "@/components/command-card";
import { AlertCard, OutputPreview } from "@/components/alert-card";
import { cn } from "@/lib/utils";
import Link from "next/link";
import { markStepComplete } from "@/lib/wizardSteps";
import { useWizardAnalytics } from "@/lib/hooks/useWizardAnalytics";
import { useVPSIP, useUserOS } from "@/lib/userPreferences";
import { withCurrentSearch } from "@/lib/utils";
import {
  SimplerGuide,
  GuideSection,
  GuideStep,
  GuideExplain,
  GuideTip,
  GuideCaution,
} from "@/components/simpler-guide";
import { Jargon } from "@/components/jargon";

interface TroubleshootingItem {
  error: string;
  causes: string[];
  solutions: string[];
}

const TROUBLESHOOTING: TroubleshootingItem[] = [
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
    error: "Permission denied",
    causes: [
      "Wrong password",
      "Password authentication might be disabled",
      "Trying wrong username",
    ],
    solutions: [
      "Double-check the password from your provider",
      "Some providers email the password - check your inbox",
      "Make sure you're using 'root' as the username",
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
  const [vpsIP, , vpsIPLoaded] = useVPSIP();
  const [os, , osLoaded] = useUserOS();
  const [expandedError, setExpandedError] = useState<string | null>(null);
  const [isNavigating, setIsNavigating] = useState(false);
  const ready = vpsIPLoaded && osLoaded;

  // Analytics tracking for this wizard step
  const { markComplete } = useWizardAnalytics({
    step: "ssh_connect",
    stepNumber: 6,
    stepTitle: "SSH Connect",
  });

  // Redirect if missing required data (after hydration)
  useEffect(() => {
    if (!ready) return;
    if (vpsIP === null) {
      router.push(withCurrentSearch("/wizard/create-vps"));
    } else if (os === null) {
      router.push(withCurrentSearch("/wizard/os-selection"));
    }
  }, [ready, vpsIP, os, router]);

  const handleContinue = useCallback(() => {
    markComplete();
    markStepComplete(6);
    setIsNavigating(true);
    router.push(withCurrentSearch("/wizard/accounts"));
  }, [router, markComplete]);

  if (!ready || !vpsIP || !os) {
    return (
      <div className="flex items-center justify-center py-12">
        <Terminal className="h-8 w-8 animate-pulse text-muted-foreground" />
      </div>
    );
  }

  // Password-first flow: connect as root with password
  const sshCommand = `ssh root@${vpsIP}`;
  const sshCommandWindows = `ssh root@${vpsIP}`;
  // Fallback if provider uses ubuntu user
  const sshCommandUbuntu = `ssh ubuntu@${vpsIP}`;
  const sshCommandUbuntuWindows = `ssh ubuntu@${vpsIP}`;

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
              <Jargon term="ssh">SSH</Jargon> into your <Jargon term="vps">VPS</Jargon>
            </h1>
            <p className="text-sm text-muted-foreground">
              ~1 min
            </p>
          </div>
        </div>
        <p className="text-muted-foreground">
          Connect to your new <Jargon term="vps">VPS</Jargon> for the first time.
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
          description="Connect as root with password"
          showCheckbox
          persistKey="ssh-connect-root"
        />
      </div>

      {/* Password prompt */}
      <AlertCard variant="warning" title="You'll be asked for your password">
        <p className="mb-2">
          First, you&apos;ll see a message about &quot;authenticity of host&quot;.
          Type <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs text-foreground">yes</code> and press Enter.
        </p>
        <p>
          Then enter the root password you set during VPS creation (or received via email).
          <strong className="block mt-1">Note: The password won&apos;t appear as you type - that&apos;s normal!</strong>
        </p>
      </AlertCard>

      {/* Fallback to ubuntu */}
      <div className="space-y-3">
        <h3 className="font-semibold">
          If &quot;root&quot; doesn&apos;t work, try ubuntu:
        </h3>
        <p className="text-sm text-muted-foreground">
          Some providers disable root login. If you get &quot;Permission denied&quot; with
          root, try connecting as ubuntu:
        </p>
        <CommandCard
          command={sshCommandUbuntu}
          windowsCommand={sshCommandUbuntuWindows}
          description="Connect as ubuntu user (fallback)"
        />
      </div>

      {/* Success indicator */}
      <OutputPreview title="You're connected when you see:">
        <p className="text-[oklch(0.72_0.19_145)]">
          root@vps:~# <span className="animate-pulse">_</span>
        </p>
        <p className="mt-2 text-muted-foreground">
          You should see a prompt with your username and &quot;vps&quot; or
          the server hostname. The &quot;#&quot; means you&apos;re logged in as root.
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

      {/* Beginner Guide */}
      <SimplerGuide>
        <div className="space-y-6">
          <GuideExplain term="SSH (Secure Shell)">
            SSH is a way to securely connect to another computer over the internet.
            It&apos;s like making a phone call to your VPS. Once connected, everything
            you type appears on the VPS, not your local computer.
            <br /><br />
            When you &quot;SSH into&quot; a computer, you&apos;re essentially remote-controlling it
            through text commands.
          </GuideExplain>

          <GuideSection title="Step-by-Step Connection Guide">
            <div className="space-y-4">
              <GuideStep number={1} title="Open your terminal">
                Open the terminal app you installed earlier (Ghostty, WezTerm, or Windows Terminal).
              </GuideStep>

              <GuideStep number={2} title="Copy the SSH command">
                Look at the gray command box above. Click the <strong>copy button</strong>
                on the right side (it looks like two overlapping squares).
              </GuideStep>

              <GuideStep number={3} title="Paste the command">
                Click inside your terminal window, then paste:
                <ul className="mt-2 list-disc space-y-1 pl-5">
                  <li><strong>Mac:</strong> <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">⌘</kbd> + <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">V</kbd></li>
                  <li><strong>Windows:</strong> Right-click inside the terminal, or <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Ctrl</kbd> + <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">V</kbd></li>
                </ul>
              </GuideStep>

              <GuideStep number={4} title="Press Enter">
                Press the <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Enter</kbd> key to run the command.
              </GuideStep>

              <GuideStep number={5} title="Say 'yes' to the security question">
                You&apos;ll see a scary-looking message about &quot;authenticity of host&quot;
                and a &quot;fingerprint&quot;. This is normal for first-time connections!
                <br /><br />
                Type <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">yes</kbd> (spelled out, not just &quot;y&quot;)
                and press <kbd className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">Enter</kbd>.
              </GuideStep>

              <GuideStep number={6} title="Enter your password">
                Now it will ask for your password. Type the password you set during VPS
                creation (or the one your provider emailed you).
                <br /><br />
                <strong>Important:</strong> The password won&apos;t show as you type—no dots
                or asterisks. Just type it and press Enter. This is normal security behavior!
              </GuideStep>

              <GuideStep number={7} title="You're connected!">
                If successful, you&apos;ll see a new prompt like:
                <code className="mt-2 block overflow-x-auto rounded bg-muted px-3 py-2 font-mono text-sm">
                  root@vps:~#
                </code>
                The &quot;root@vps&quot; part means you&apos;re now controlling the VPS!
                Everything you type from now on runs on the VPS, not your laptop.
              </GuideStep>
            </div>
          </GuideSection>

          <GuideSection title="Understanding What You See">
            <p className="mb-3">
              After connecting, your terminal looks different because you&apos;re now
              &quot;inside&quot; the VPS:
            </p>
            <ul className="space-y-2">
              <li>
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">root@</code>
                is your username on the VPS (you&apos;re the admin!)
              </li>
              <li>
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">vps</code>
                is the VPS hostname (might be different)
              </li>
              <li>
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">~</code>
                means you&apos;re in your &quot;home&quot; folder
              </li>
              <li>
                <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">#</code>
                means you&apos;re logged in as root (vs <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">$</code> for regular users)
              </li>
            </ul>
          </GuideSection>

          <GuideTip>
            To disconnect from the VPS and return to your local computer, type{" "}
            <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">exit</code>
            and press Enter. You can always reconnect using the same SSH command.
          </GuideTip>

          <GuideCaution>
            <strong>&quot;Permission denied&quot; error?</strong> Double-check your password.
            Some providers email the password instead of letting you set it—check your inbox.
            If you&apos;re trying root and it doesn&apos;t work, try the &quot;ubuntu&quot;
            command shown above.
          </GuideCaution>

          <div className="rounded-lg border border-primary/20 bg-primary/5 p-4">
            <Link href="/learn/ssh-basics" className="flex items-center gap-3 text-sm">
              <BookOpen className="h-5 w-5 text-primary" />
              <div>
                <span className="font-medium text-foreground">Want to learn more about SSH?</span>
                <p className="text-muted-foreground">
                  Check out the SSH & Persistence lesson in the Learning Hub →
                </p>
              </div>
            </Link>
          </div>
        </div>
      </SimplerGuide>

      {/* Continue button */}
      <div className="flex justify-end pt-4">
        <Button onClick={handleContinue} disabled={isNavigating} size="lg" disableMotion>
          {isNavigating ? "Loading..." : "I'm connected, continue"}
        </Button>
      </div>
    </div>
  );
}
