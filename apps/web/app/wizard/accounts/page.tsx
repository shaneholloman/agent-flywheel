"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import {
  BookOpen,
  Users,
  ExternalLink,
  Check,
  Shield,
  Bot,
  Cloud,
  Wrench,
  Sparkles,
  Terminal,
  Zap,
  ChevronDown,
} from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { AlertCard } from "@/components/alert-card";
import { markStepComplete } from "@/lib/wizardSteps";
import { useWizardAnalytics } from "@/lib/hooks/useWizardAnalytics";
import { withCurrentSearch } from "@/lib/utils";
import {
  SimplerGuide,
  GuideSection,
  GuideStep,
  GuideExplain,
  GuideTip,
} from "@/components/simpler-guide";
import { Jargon } from "@/components/jargon";
import {
  SERVICES,
  CATEGORY_NAMES,
  PRIORITY_NAMES,
  TIER_NAMES,
  getGoogleSsoServices,
  groupByTier,
  type Service,
  type ServiceCategory,
  type ServiceTier,
} from "@/lib/services";
import { TrackedLink } from "@/components/tracked-link";

// Category icons
const CATEGORY_ICONS: Record<ServiceCategory, React.ReactNode> = {
  access: <Shield className="h-5 w-5" />,
  agent: <Bot className="h-5 w-5" />,
  cloud: <Cloud className="h-5 w-5" />,
  devtools: <Wrench className="h-5 w-5" />,
};

// Tier icons and colors
const TIER_ICONS: Record<ServiceTier, React.ReactNode> = {
  essential: <Zap className="h-5 w-5" />,
  recommended: <Sparkles className="h-5 w-5" />,
  optional: <Cloud className="h-5 w-5" />,
};

const TIER_DESCRIPTIONS: Record<ServiceTier, string> = {
  essential: "You need these to start using the system",
  recommended: "Add these after your first project",
  optional: "Set these up when you need them",
};

// Priority badge colors - uses PRIORITY_NAMES from services.ts
function getPriorityBadge(priority: Service["priority"]) {
  const label = PRIORITY_NAMES[priority];
  switch (priority) {
    case "strongly-recommended":
      return (
        <span className="rounded-full bg-[oklch(0.72_0.19_145/0.15)] px-2 py-0.5 text-xs font-medium text-[oklch(0.72_0.19_145)]">
          {label}
        </span>
      );
    case "recommended":
      return (
        <span className="rounded-full bg-[oklch(0.75_0.18_195/0.15)] px-2 py-0.5 text-xs font-medium text-[oklch(0.75_0.18_195)]">
          {label}
        </span>
      );
    case "optional":
      return (
        <span className="rounded-full bg-muted px-2 py-0.5 text-xs font-medium text-muted-foreground">
          {label}
        </span>
      );
  }
}

interface ServiceCardProps {
  service: Service;
  isChecked: boolean;
  onToggle: () => void;
}

function ServiceCard({ service, isChecked, onToggle }: ServiceCardProps) {
  return (
    <div
      className={`group rounded-xl border p-4 transition-all ${
        isChecked
          ? "border-[oklch(0.72_0.19_145/0.5)] bg-[oklch(0.72_0.19_145/0.05)]"
          : "border-border/50 bg-card/50 hover:border-primary/30"
      }`}
    >
      <div className="flex items-start gap-3">
        <Checkbox
          checked={isChecked}
          onCheckedChange={onToggle}
          className="mt-1"
        />
        <div className="min-w-0 flex-1 space-y-2">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-semibold text-foreground">
              {service.name}
            </span>
            <span className="text-xs text-muted-foreground">
              by {service.provider}
            </span>
            {getPriorityBadge(service.priority)}
          </div>
          <p className="text-sm text-muted-foreground">
            {service.shortDescription}
          </p>
          <p className="text-xs text-muted-foreground/80">
            {service.whyNeeded}
          </p>
          <div className="flex flex-wrap gap-2 pt-1">
            {service.supportsGoogleSso && (
              <TrackedLink
                href={service.googleSsoUrl || service.signupUrl}
                trackingId={`service-google-sso-${service.id}`}
                className="inline-flex items-center gap-1.5 rounded-lg border border-[oklch(0.72_0.19_145/0.3)] bg-[oklch(0.72_0.19_145/0.1)] px-2.5 py-1.5 text-xs font-medium text-[oklch(0.72_0.19_145)] transition-colors hover:bg-[oklch(0.72_0.19_145/0.2)]"
              >
                <Sparkles className="h-3 w-3" />
                Sign up with Google
                <ExternalLink className="h-2.5 w-2.5" />
              </TrackedLink>
            )}
            <TrackedLink
              href={service.signupUrl}
              trackingId={`service-signup-${service.id}`}
              className="inline-flex items-center gap-1 rounded-lg border border-border/50 bg-card/50 px-2.5 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:border-primary/30 hover:text-foreground"
            >
              {service.supportsGoogleSso ? "Other signup options" : "Sign up"}
              <ExternalLink className="h-2.5 w-2.5" />
            </TrackedLink>
            <TrackedLink
              href={service.docsUrl}
              trackingId={`service-docs-${service.id}`}
              className="inline-flex items-center gap-1 px-1.5 py-1.5 text-xs text-muted-foreground hover:text-foreground"
            >
              Docs
              <ExternalLink className="h-2.5 w-2.5" />
            </TrackedLink>
          </div>
          {/* Post-install command preview */}
          {service.postInstallCommand && (
            <div className="flex items-center gap-2 pt-2 text-xs text-muted-foreground/70">
              <Terminal className="h-3 w-3 shrink-0" />
              <span>
                After install:{" "}
                <code className="rounded bg-muted/50 px-1.5 py-0.5 font-mono text-[10px] text-muted-foreground">
                  {service.postInstallCommand}
                </code>
              </span>
            </div>
          )}
        </div>
        {isChecked && (
          <Check className="h-5 w-5 shrink-0 text-[oklch(0.72_0.19_145)]" />
        )}
      </div>
    </div>
  );
}

export default function AccountsPage() {
  const router = useRouter();
  const [isNavigating, setIsNavigating] = useState(false);
  const [checkedServices, setCheckedServices] = useState<Set<string>>(
    new Set()
  );

  // Analytics tracking for this wizard step
  const { markComplete } = useWizardAnalytics({
    step: "accounts",
    stepNumber: 7,
    stepTitle: "Set Up Accounts",
  });

  const handleToggle = useCallback((serviceId: string) => {
    setCheckedServices((prev) => {
      const next = new Set(prev);
      if (next.has(serviceId)) {
        next.delete(serviceId);
      } else {
        next.add(serviceId);
      }
      return next;
    });
  }, []);

  const handleContinue = useCallback(() => {
    markComplete({
      accounts_checked: Array.from(checkedServices),
      accounts_count: checkedServices.size,
    });
    markStepComplete(7);
    setIsNavigating(true);
    router.push(withCurrentSearch("/wizard/preflight-check"));
  }, [router, markComplete, checkedServices]);

  const handleSkip = useCallback(() => {
    markComplete({ skipped: true });
    markStepComplete(7);
    setIsNavigating(true);
    router.push(withCurrentSearch("/wizard/preflight-check"));
  }, [router, markComplete]);

  const tierGroups = groupByTier();
  const tierOrder: ServiceTier[] = ["essential", "recommended", "optional"];

  // Count essential services that are checked
  const essentialServices = tierGroups.essential;
  const essentialChecked = essentialServices.filter((s) =>
    checkedServices.has(s.id)
  );

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20">
            <Users className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h1 className="bg-gradient-to-r from-foreground via-foreground to-muted-foreground bg-clip-text text-2xl font-bold tracking-tight text-transparent sm:text-3xl">
              Set up your accounts
            </h1>
            <p className="text-sm text-muted-foreground">~5-10 min</p>
          </div>
        </div>
        <p className="text-muted-foreground">
          Create accounts for the services you&apos;ll use with your{" "}
          <Jargon term="vps">VPS</Jargon>. Do this now while the installer runs
          later.
        </p>
      </div>

      {/* Google SSO tip - uses getGoogleSsoServices() to show count */}
      <AlertCard variant="tip" icon={Sparkles} title="Quick signup with Google">
        {getGoogleSsoServices().length} of {SERVICES.length} services support Google SSO.
        Use the same Google account for all of them to streamline your setup.
      </AlertCard>

      {/* Progress indicator */}
      <div className="rounded-xl border border-border/50 bg-card/50 p-4">
        <div className="flex items-center justify-between">
          <span className="text-sm text-muted-foreground">
            Essential accounts:
          </span>
          <span className="font-medium">
            {essentialChecked.length} / {essentialServices.length}
          </span>
        </div>
        <div className="mt-2 h-2 overflow-hidden rounded-full bg-muted">
          <div
            className="h-full bg-[oklch(0.72_0.19_145)] transition-all"
            style={{
              width: `${
                essentialServices.length > 0
                  ? (essentialChecked.length / essentialServices.length) * 100
                  : 0
              }%`,
            }}
          />
        </div>
      </div>

      {/* Service tiers */}
      {tierOrder.map((tier) => {
        const services = tierGroups[tier];
        if (services.length === 0) return null;

        const isEssential = tier === "essential";
        const tierLabel = TIER_NAMES[tier];
        const tierDesc = TIER_DESCRIPTIONS[tier];

        // Essential tier is always expanded, others are collapsible
        if (isEssential) {
          return (
            <div key={tier} className="space-y-4">
              <div className="flex items-center gap-2">
                <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[oklch(0.72_0.19_145/0.2)] text-[oklch(0.72_0.19_145)]">
                  {TIER_ICONS[tier]}
                </div>
                <div>
                  <h2 className="text-lg font-semibold">{tierLabel}</h2>
                  <p className="text-sm text-muted-foreground">{tierDesc}</p>
                </div>
              </div>
              <div className="space-y-3">
                {services.map((service) => (
                  <ServiceCard
                    key={service.id}
                    service={service}
                    isChecked={checkedServices.has(service.id)}
                    onToggle={() => handleToggle(service.id)}
                  />
                ))}
              </div>
            </div>
          );
        }

        // Recommended and Optional are collapsible
        return (
          <details key={tier} className="group">
            <summary className="flex cursor-pointer items-center gap-2 rounded-lg border border-border/50 bg-card/30 p-3 transition-colors hover:bg-card/50 [&::-webkit-details-marker]:hidden">
              <ChevronDown className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-open:rotate-180" />
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/10 text-primary">
                {TIER_ICONS[tier]}
              </div>
              <div className="flex-1">
                <h2 className="text-base font-semibold">{tierLabel}</h2>
                <p className="text-sm text-muted-foreground">{tierDesc}</p>
              </div>
              <span className="text-sm text-muted-foreground">
                {services.filter((s) => checkedServices.has(s.id)).length} / {services.length}
              </span>
            </summary>
            <div className="mt-4 space-y-3 pl-6">
              {services.map((service) => (
                <ServiceCard
                  key={service.id}
                  service={service}
                  isChecked={checkedServices.has(service.id)}
                  onToggle={() => handleToggle(service.id)}
                />
              ))}
            </div>
          </details>
        );
      })}

      {/* Beginner Guide */}
      <SimplerGuide>
        <div className="space-y-6">
          <GuideExplain term="Why do I need all these accounts?">
            These services work together to give you a powerful development
            environment:
            <br />
            <br />
            <strong>Access:</strong> Tailscale lets you securely connect to your
            VPS from anywhere without complex firewall setup.
            <br />
            <br />
            <strong>AI Agents:</strong> Claude Code, Codex, and Gemini are your
            AI coding assistants. Having multiple gives you different
            perspectives.
            <br />
            <br />
            <strong>Cloud Platforms:</strong> These handle deployment, databases,
            and hosting so you can ship real products.
          </GuideExplain>

          <GuideSection title="How to Sign Up Efficiently">
            <div className="space-y-4">
              <GuideStep number={1} title="Use Google SSO when available">
                Click the green &quot;Sign up with Google&quot; button. This is
                fastest and you won&apos;t need to remember extra passwords.
              </GuideStep>

              <GuideStep number={2} title="Check the box after signing up">
                After you create each account, check the box next to it. This
                helps you track your progress.
              </GuideStep>

              <GuideStep number={3} title="Focus on 'Strongly Recommended' first">
                The green-labeled services are most important. You can skip
                &quot;Optional&quot; ones for now.
              </GuideStep>

              <GuideStep number={4} title="You can come back later">
                Don&apos;t want to create all accounts now? That&apos;s fine!
                Click &quot;Skip for now&quot; and create them after installation.
              </GuideStep>
            </div>
          </GuideSection>

          <GuideTip>
            <strong>Pro tip:</strong> Open each signup link in a new tab
            (Cmd+click on Mac, Ctrl+click on Windows). That way you can create
            multiple accounts quickly without losing your place here.
          </GuideTip>

          <div className="rounded-lg border border-primary/20 bg-primary/5 p-4">
            <Link href="/learn/agent-commands" className="flex items-center gap-3 text-sm">
              <BookOpen className="h-5 w-5 text-primary" />
              <div>
                <span className="font-medium text-foreground">Need help with agent logins?</span>
                <p className="text-muted-foreground">
                  See the Agent Commands lesson for auth tips and shortcuts →
                </p>
              </div>
            </Link>
          </div>
        </div>
      </SimplerGuide>

      {/* Action buttons */}
      <div className="flex flex-col gap-3 pt-4 sm:flex-row sm:justify-end">
        <Button variant="outline" onClick={handleSkip} disabled={isNavigating}>
          Skip for now
        </Button>
        <Button
          onClick={handleContinue}
          disabled={isNavigating}
          size="lg"
          disableMotion
        >
          {isNavigating ? "Loading..." : "Continue to pre-flight check"}
        </Button>
      </div>
    </div>
  );
}
