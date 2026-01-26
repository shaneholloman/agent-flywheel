"use client";

/**
 * HelpPanel — Contextual "Need help?" dialog for the wizard.
 *
 * Shows step-specific troubleshooting, tips, and a debug info export.
 * Uses the native <dialog> element for built-in focus trap and Escape handling.
 *
 * @see bd-1yfv
 */

import { useCallback, useRef, useState } from "react";
import {
  HelpCircle,
  X,
  Copy,
  Check,
  ChevronRight,
  Lightbulb,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { STEP_HELP, getDebugInfo, type StepHelp } from "@/lib/stepHelp";

const DEFAULT_HELP: StepHelp = {
  commonIssues: [],
  tips: [
    "Make sure you're following the steps in order.",
    "If a command fails, try running it again — transient errors are common.",
    "Check that you're running commands in the right place (local terminal vs. VPS).",
  ],
};

interface HelpPanelProps {
  currentStep: number;
}

export function HelpPanel({ currentStep }: HelpPanelProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [copied, setCopied] = useState(false);

  const help = STEP_HELP[currentStep] ?? DEFAULT_HELP;
  const hasIssues = help.commonIssues.length > 0;
  const hasTips = help.tips.length > 0;

  const openDialog = useCallback(() => {
    dialogRef.current?.showModal();
  }, []);

  const closeDialog = useCallback(() => {
    dialogRef.current?.close();
  }, []);

  const copyDebugInfo = useCallback(async () => {
    const info = getDebugInfo(currentStep);
    try {
      await navigator.clipboard.writeText(info);
    } catch {
      // Fallback for older browsers / non-HTTPS
      const textarea = document.createElement("textarea");
      textarea.value = info;
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      document.body.removeChild(textarea);
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }, [currentStep]);

  return (
    <>
      {/* Trigger button */}
      <Button
        variant="ghost"
        size="sm"
        onClick={openDialog}
        className="gap-1.5 text-muted-foreground hover:text-foreground"
        aria-label="Need help?"
      >
        <HelpCircle className="h-4 w-4" />
        <span className="hidden sm:inline">Need help?</span>
      </Button>

      {/* Dialog */}
      <dialog
        ref={dialogRef}
        className="m-auto w-full max-w-lg rounded-xl border border-border bg-background p-0 text-foreground shadow-2xl backdrop:bg-black/50 backdrop:backdrop-blur-sm"
        onClick={(e) => {
          // Close on backdrop click
          if (e.target === dialogRef.current) closeDialog();
        }}
      >
        <div className="flex max-h-[80vh] flex-col">
          {/* Header */}
          <div className="flex items-center justify-between border-b border-border/50 px-6 py-4">
            <h2 className="flex items-center gap-2 text-lg font-semibold">
              <HelpCircle className="h-5 w-5 text-primary" />
              Step {currentStep} Help
            </h2>
            <button
              onClick={closeDialog}
              className="flex h-8 w-8 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
              aria-label="Close"
            >
              <X className="h-4 w-4" />
            </button>
          </div>

          {/* Scrollable content */}
          <div className="flex-1 overflow-y-auto px-6 py-4 space-y-6">
            {/* Common Issues */}
            {hasIssues && (
              <section>
                <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                  Common Issues
                </h3>
                <div className="space-y-3">
                  {help.commonIssues.map((issue) => (
                    <details
                      key={issue.symptom}
                      className="group rounded-lg border border-border/50 bg-muted/30"
                    >
                      <summary className="flex cursor-pointer items-center gap-2 px-4 py-3 text-sm font-medium text-foreground">
                        <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-open:rotate-90" />
                        {issue.symptom}
                      </summary>
                      <div className="border-t border-border/30 px-4 py-3 text-sm text-muted-foreground">
                        {issue.solution}
                      </div>
                    </details>
                  ))}
                </div>
              </section>
            )}

            {/* Tips */}
            {hasTips && (
              <section>
                <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                  Tips
                </h3>
                <ul className="space-y-2">
                  {help.tips.map((tip) => (
                    <li
                      key={tip}
                      className="flex items-start gap-2 text-sm text-muted-foreground"
                    >
                      <Lightbulb className="mt-0.5 h-4 w-4 shrink-0 text-[oklch(0.75_0.15_85)]" />
                      {tip}
                    </li>
                  ))}
                </ul>
              </section>
            )}

            {/* Debug Info */}
            <section className="rounded-lg border border-border/50 bg-muted/20 p-4">
              <h3 className="mb-2 text-sm font-semibold text-muted-foreground">
                Share Debug Info
              </h3>
              <p className="mb-3 text-xs text-muted-foreground">
                Copy this information when asking for help — it helps us
                diagnose the issue faster.
              </p>
              <Button
                variant="outline"
                size="sm"
                onClick={copyDebugInfo}
                className="gap-1.5"
              >
                {copied ? (
                  <>
                    <Check className="h-3.5 w-3.5 text-[oklch(0.72_0.19_145)]" />
                    Copied
                  </>
                ) : (
                  <>
                    <Copy className="h-3.5 w-3.5" />
                    Copy Debug Info
                  </>
                )}
              </Button>
            </section>
          </div>
        </div>
      </dialog>
    </>
  );
}
