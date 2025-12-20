"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import { Check, AlertCircle, Server, ChevronDown, HardDrive } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { DetailsSection } from "@/components/alert-card";
import { cn } from "@/lib/utils";
import { markStepComplete } from "@/lib/wizardSteps";
import { useVPSIP, isValidIP } from "@/lib/userPreferences";

const CHECKLIST_ITEMS = [
  { id: "ubuntu", label: "Selected Ubuntu 25.x (or newest Ubuntu available)" },
  { id: "ssh", label: "Pasted my SSH public key" },
  { id: "created", label: "Created the VPS and waited for it to start" },
  { id: "copied-ip", label: "Copied the IP address" },
];

interface ProviderGuideProps {
  name: string;
  steps: string[];
  isExpanded: boolean;
  onToggle: () => void;
}

function ProviderGuide({
  name,
  steps,
  isExpanded,
  onToggle,
}: ProviderGuideProps) {
  return (
    <div className={cn(
      "rounded-xl border transition-all duration-200",
      isExpanded
        ? "border-primary/30 bg-card/80"
        : "border-border/50 bg-card/50"
    )}>
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full items-center justify-between p-3 text-left"
      >
        <span className="font-medium text-foreground">{name} specific steps</span>
        <ChevronDown
          className={cn(
            "h-4 w-4 text-muted-foreground transition-transform duration-200",
            isExpanded && "rotate-180"
          )}
        />
      </button>
      {isExpanded && (
        <div className="border-t border-border/50 px-3 pb-3 pt-2">
          <ol className="list-decimal space-y-1 pl-5 text-sm text-muted-foreground">
            {steps.map((step, i) => (
              <li key={i}>{step}</li>
            ))}
          </ol>
        </div>
      )}
    </div>
  );
}

const PROVIDER_GUIDES = [
  {
    name: "OVH",
    steps: [
      'Click "Order" on your chosen VPS plan',
      'Under "Image", select Ubuntu 25.04 (or latest)',
      'Under "SSH Key", click "Add a key" and paste your public key',
      "Complete the order and wait for activation email",
      "Copy the IP address from your control panel",
    ],
  },
  {
    name: "Contabo",
    steps: [
      'After ordering, go to "Your services" > "VPS control"',
      'Click "Reinstall" and select Ubuntu 25.x',
      'Under "SSH Key", paste your public key',
      "Wait for the reinstallation to complete",
      "Copy the IP address shown in the control panel",
    ],
  },
  {
    name: "Hetzner",
    steps: [
      'In Cloud Console, click "Add Server"',
      'Select your location and Ubuntu 25.04 image',
      'Under "SSH Keys", add your public key',
      'Click "Create & Buy Now"',
      "Copy the IP address once the server is running",
    ],
  },
];

export default function CreateVPSPage() {
  const router = useRouter();
  const [storedIP, setStoredIP] = useVPSIP();
  const [checkedItems, setCheckedItems] = useState<Set<string>>(new Set());
  const [ipAddress, setIpAddress] = useState(storedIP ?? "");
  const [ipError, setIpError] = useState<string | null>(null);
  const [expandedProvider, setExpandedProvider] = useState<string | null>(null);
  const [isNavigating, setIsNavigating] = useState(false);

  const handleCheckItem = useCallback((itemId: string, checked: boolean) => {
    setCheckedItems((prev) => {
      const next = new Set(prev);
      if (checked) {
        next.add(itemId);
      } else {
        next.delete(itemId);
      }
      return next;
    });
  }, []);

  const handleIpChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const value = e.target.value;
      setIpAddress(value);
      setIpError(null);

      if (value && !isValidIP(value)) {
        setIpError("Please enter a valid IP address (e.g., 192.168.1.1)");
      }
    },
    []
  );

  const handleContinue = useCallback(() => {
    if (!ipAddress) {
      setIpError("Please enter your VPS IP address");
      return;
    }
    if (!isValidIP(ipAddress)) {
      setIpError("Please enter a valid IP address");
      return;
    }

    setStoredIP(ipAddress);
    markStepComplete(5);
    setIsNavigating(true);
    router.push("/wizard/ssh-connect");
  }, [ipAddress, router, setStoredIP]);

  const allChecked = CHECKLIST_ITEMS.every((item) =>
    checkedItems.has(item.id)
  );
  const canContinue = allChecked && ipAddress && !ipError;

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20">
            <HardDrive className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h1 className="bg-gradient-to-r from-foreground via-foreground to-muted-foreground bg-clip-text text-2xl font-bold tracking-tight text-transparent sm:text-3xl">
              Create your VPS instance
            </h1>
            <p className="text-sm text-muted-foreground">
              ~5 min
            </p>
          </div>
        </div>
        <p className="text-muted-foreground">
          Launch your VPS and attach your SSH key. Follow the checklist below.
        </p>
      </div>

      {/* Universal checklist */}
      <div className="rounded-xl border border-border/50 bg-card/50 p-4">
        <h2 className="mb-4 flex items-center gap-2 font-semibold text-foreground">
          <Server className="h-5 w-5 text-primary" />
          Setup checklist
        </h2>
        <div className="space-y-3">
          {CHECKLIST_ITEMS.map((item) => (
            <label
              key={item.id}
              className="flex cursor-pointer items-center gap-3"
            >
              <Checkbox
                checked={checkedItems.has(item.id)}
                onCheckedChange={(checked) =>
                  handleCheckItem(item.id, checked === true)
                }
              />
              <span
                className={cn(
                  "text-sm transition-all",
                  checkedItems.has(item.id)
                    ? "text-muted-foreground line-through"
                    : "text-foreground"
                )}
              >
                {item.label}
              </span>
            </label>
          ))}
        </div>
      </div>

      {/* Provider-specific guides */}
      <div className="space-y-3">
        <h2 className="font-semibold">Need help with your provider?</h2>
        {PROVIDER_GUIDES.map((provider) => (
          <ProviderGuide
            key={provider.name}
            name={provider.name}
            steps={provider.steps}
            isExpanded={expandedProvider === provider.name}
            onToggle={() =>
              setExpandedProvider((prev) =>
                prev === provider.name ? null : provider.name
              )
            }
          />
        ))}
      </div>

      {/* IP Address input */}
      <div className="space-y-3">
        <h2 className="font-semibold text-foreground">Your VPS IP address</h2>
        <p className="text-sm text-muted-foreground">
          Enter the IP address of your new VPS. You&apos;ll find this in your
          provider&apos;s control panel after the VPS is created.
        </p>
        <div className="space-y-2">
          <input
            type="text"
            value={ipAddress}
            onChange={handleIpChange}
            placeholder="e.g., 192.168.1.100"
            className={cn(
              "w-full rounded-xl border bg-background px-4 py-3 font-mono text-sm outline-none transition-all",
              "focus:border-primary focus:ring-2 focus:ring-primary/20",
              ipError
                ? "border-destructive focus:border-destructive focus:ring-destructive/20"
                : "border-border/50"
            )}
          />
          {ipError && (
            <p className="flex items-center gap-1 text-sm text-destructive">
              <AlertCircle className="h-4 w-4" />
              {ipError}
            </p>
          )}
          {ipAddress && !ipError && isValidIP(ipAddress) && (
            <p className="flex items-center gap-1 text-sm text-[oklch(0.72_0.19_145)]">
              <Check className="h-4 w-4" />
              Valid IP address
            </p>
          )}
        </div>
      </div>

      {/* Continue button */}
      <div className="flex justify-end pt-4">
        <Button
          onClick={handleContinue}
          disabled={!canContinue || isNavigating}
          size="lg"
        >
          {isNavigating ? "Loading..." : "Continue to SSH"}
        </Button>
      </div>
    </div>
  );
}
