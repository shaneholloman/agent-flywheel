"use client";

import { useCallback, useState } from "react";
import { useRouter } from "next/navigation";
import { Apple, Monitor, Sparkles, Laptop, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { markStepComplete } from "@/lib/wizardSteps";
import {
  useUserOS,
  useDetectedOS,
  type OperatingSystem,
} from "@/lib/userPreferences";

interface OSCardProps {
  icon: React.ReactNode;
  title: string;
  description: string;
  selected: boolean;
  detected?: boolean;
  onClick: () => void;
}

function OSCard({ icon, title, description, selected, detected, onClick }: OSCardProps) {
  return (
    <button
      type="button"
      className={cn(
        "group relative flex w-full flex-col items-center gap-4 rounded-2xl border p-8 text-center transition-all duration-300",
        selected
          ? "border-primary bg-primary/10 shadow-lg shadow-primary/10"
          : "border-border/50 bg-card/50 hover:border-primary/30 hover:bg-card/80 hover:shadow-md"
      )}
      onClick={onClick}
      role="radio"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onClick();
        }
      }}
      aria-checked={selected}
    >
      {/* Detected badge */}
      {detected && (
        <div className={cn(
          "absolute -top-2 left-1/2 -translate-x-1/2 rounded-full px-3 py-0.5 text-xs font-medium transition-all",
          selected
            ? "bg-primary text-primary-foreground"
            : "bg-primary/20 text-primary"
        )}>
          {selected ? "Selected" : "Detected"}
        </div>
      )}

      {/* Selected glow */}
      {selected && (
        <>
          <div className="absolute inset-0 rounded-2xl bg-gradient-to-b from-primary/20 to-transparent opacity-50" />
          <div className="absolute -inset-px rounded-2xl bg-gradient-to-b from-primary/50 to-primary/0 opacity-0 transition-opacity group-hover:opacity-100" />
        </>
      )}

      {/* Icon */}
      <div
        className={cn(
          "relative flex h-20 w-20 items-center justify-center rounded-2xl transition-all duration-300",
          selected
            ? "bg-primary text-primary-foreground shadow-lg shadow-primary/30"
            : "bg-muted text-muted-foreground group-hover:bg-muted/80 group-hover:text-foreground"
        )}
      >
        {icon}
        {selected && (
          <Sparkles className="absolute -right-1 -top-1 h-5 w-5 text-[oklch(0.78_0.16_75)] animate-pulse" />
        )}
      </div>

      {/* Text */}
      <div className="relative">
        <h3 className="text-xl font-bold tracking-tight transition-colors text-foreground">
          {title}
        </h3>
        <p className="mt-1 text-sm text-muted-foreground">
          {description}
        </p>
      </div>

      {/* Selection indicator */}
      {selected && (
        <div className="absolute bottom-4 right-4 flex h-6 w-6 items-center justify-center rounded-full bg-primary text-primary-foreground animate-scale-in">
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
          </svg>
        </div>
      )}
    </button>
  );
}

export default function OSSelectionPage() {
  const router = useRouter();
  const [storedOS, setStoredOS] = useUserOS();
  const detectedOS = useDetectedOS();
  const [isNavigating, setIsNavigating] = useState(false);

  // Use stored OS if available, otherwise use detected OS
  const selectedOS = storedOS ?? detectedOS;

  // Select OS without navigating
  const handleSelectOS = useCallback(
    (os: OperatingSystem) => {
      setStoredOS(os);
    },
    [setStoredOS]
  );

  // Navigate only when Continue is clicked
  const handleContinue = useCallback(() => {
    if (selectedOS) {
      markStepComplete(1);
      setIsNavigating(true);
      router.push("/wizard/install-terminal");
    }
  }, [selectedOS, router]);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="space-y-2">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20">
            <Laptop className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h1 className="bg-gradient-to-r from-foreground via-foreground to-muted-foreground bg-clip-text text-2xl font-bold tracking-tight text-transparent sm:text-3xl">
              What computer are you using?
            </h1>
            <p className="text-sm text-muted-foreground">
              ~30 sec
            </p>
          </div>
        </div>
        <p className="text-muted-foreground">
          This helps us show you the right commands and instructions.
        </p>
      </div>

      {/* OS Options */}
      <div className="grid gap-6 sm:grid-cols-2" role="radiogroup" aria-label="Select your operating system">
        <OSCard
          icon={<Apple className="h-10 w-10" />}
          title="Mac"
          description="macOS, MacBook, iMac, Mac Mini, Mac Studio"
          selected={selectedOS === "mac"}
          detected={detectedOS === "mac"}
          onClick={() => handleSelectOS("mac")}
        />
        <OSCard
          icon={<Monitor className="h-10 w-10" />}
          title="Windows"
          description="Windows 10, Windows 11"
          selected={selectedOS === "windows"}
          detected={detectedOS === "windows"}
          onClick={() => handleSelectOS("windows")}
        />
      </div>

      {/* Tip */}
      <div className="rounded-xl border border-border/30 bg-muted/30 p-4">
        <p className="text-sm text-muted-foreground">
          <span className="font-medium text-foreground">Tip:</span> Your operating system was automatically detected. Click to confirm or select the other option.
        </p>
      </div>

      {/* Continue button */}
      <div className="flex justify-end pt-4">
        <Button
          onClick={handleContinue}
          disabled={!selectedOS || isNavigating}
          size="lg"
          className="group"
        >
          {isNavigating ? (
            <>
              <div className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-primary-foreground border-t-transparent" />
              Loading...
            </>
          ) : (
            <>
              Continue
              <ChevronRight className="ml-1 h-4 w-4 transition-transform group-hover:translate-x-0.5" />
            </>
          )}
        </Button>
      </div>
    </div>
  );
}
