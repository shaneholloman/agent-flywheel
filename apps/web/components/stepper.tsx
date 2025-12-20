"use client";

import { useCallback } from "react";
import { Check, Circle } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  WIZARD_STEPS,
  useCompletedSteps,
  type WizardStep,
} from "@/lib/wizardSteps";

export interface StepperProps {
  /** Current active step (1-indexed) */
  currentStep: number;
  /** Callback when a step is clicked */
  onStepClick?: (step: number) => void;
  /** Additional class names for the container */
  className?: string;
}

interface StepItemProps {
  step: WizardStep;
  isActive: boolean;
  isCompleted: boolean;
  isClickable: boolean;
  onClick?: () => void;
}

function StepItem({
  step,
  isActive,
  isCompleted,
  isClickable,
  onClick,
}: StepItemProps) {
  return (
    <button
      type="button"
      onClick={isClickable ? onClick : undefined}
      disabled={!isClickable}
      className={cn(
        "group relative flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-all duration-200",
        isActive && "bg-primary/10 shadow-sm",
        isClickable && !isActive && "hover:bg-muted/50",
        !isClickable && "cursor-not-allowed opacity-40"
      )}
      aria-current={isActive ? "step" : undefined}
    >
      {/* Connection line to next step */}
      <div className="absolute left-[22px] top-[42px] h-[calc(100%-16px)] w-px bg-gradient-to-b from-border/50 to-transparent" />

      {/* Step indicator */}
      <div
        className={cn(
          "relative z-10 flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-medium transition-all duration-300",
          isCompleted && "bg-[oklch(0.72_0.19_145)] text-[oklch(0.15_0.02_145)] shadow-sm shadow-[oklch(0.72_0.19_145/0.3)]",
          isActive && !isCompleted && "bg-primary text-primary-foreground shadow-sm shadow-primary/30 animate-glow-pulse",
          !isActive && !isCompleted && "bg-muted text-muted-foreground"
        )}
      >
        {isCompleted ? (
          <Check className="h-4 w-4" strokeWidth={2.5} />
        ) : isActive ? (
          <Circle className="h-3 w-3 fill-current" />
        ) : (
          <span className="font-mono text-xs">{step.id}</span>
        )}
      </div>

      {/* Step text */}
      <div className="min-w-0 flex-1">
        <div
          className={cn(
            "truncate text-sm font-medium transition-colors",
            isActive && "text-foreground",
            isCompleted && "text-muted-foreground",
            !isActive && !isCompleted && "text-muted-foreground"
          )}
        >
          {step.title}
        </div>
        {isActive && (
          <div className="mt-0.5 text-xs text-primary">In progress</div>
        )}
        {isCompleted && (
          <div className="mt-0.5 text-xs text-[oklch(0.72_0.19_145)]">Complete</div>
        )}
      </div>

      {/* Hover effect */}
      {isClickable && !isActive && (
        <div className="absolute inset-0 rounded-xl border border-transparent transition-colors group-hover:border-border/50" />
      )}
    </button>
  );
}

/**
 * Stepper component for wizard navigation.
 *
 * Shows all wizard steps in a vertical list with:
 * - Current step highlighted with glow
 * - Completed steps with green checkmarks
 * - Connection lines between steps
 * - Click navigation to completed steps only
 */
export function Stepper({ currentStep, onStepClick, className }: StepperProps) {
  const [completedSteps] = useCompletedSteps();

  const handleStepClick = useCallback(
    (stepId: number) => {
      if (onStepClick) {
        onStepClick(stepId);
      }
    },
    [onStepClick]
  );

  return (
    <nav
      className={cn("flex flex-col", className)}
      aria-label="Wizard steps"
    >
      {WIZARD_STEPS.map((step, index) => {
        const isActive = step.id === currentStep;
        const isCompleted = completedSteps.includes(step.id);
        // Can click if step is completed or if it's the next step after last completed
        const highestCompleted = Math.max(0, ...completedSteps);
        const isClickable = isCompleted || step.id <= highestCompleted + 1;
        const isLastStep = index === WIZARD_STEPS.length - 1;

        return (
          <div key={step.id} className={cn(!isLastStep && "pb-1")}>
            <StepItem
              step={step}
              isActive={isActive}
              isCompleted={isCompleted}
              isClickable={isClickable}
              onClick={() => handleStepClick(step.id)}
            />
          </div>
        );
      })}
    </nav>
  );
}

/**
 * Mobile-friendly bottom navigation version of the stepper.
 * Shows a compact progress bar with dots and current step info.
 */
export function StepperMobile({
  currentStep,
  onStepClick,
  className,
}: StepperProps) {
  const [completedSteps] = useCompletedSteps();

  const currentStepData = WIZARD_STEPS.find((s) => s.id === currentStep);
  const progress = (completedSteps.length / WIZARD_STEPS.length) * 100;

  return (
    <div className={cn("space-y-3", className)}>
      {/* Progress bar with gradient */}
      <div className="h-1 w-full overflow-hidden rounded-full bg-muted">
        <div
          className="h-full bg-gradient-to-r from-primary via-[oklch(0.7_0.2_330)] to-primary transition-all duration-500"
          style={{ width: `${progress}%`, backgroundSize: "200% 100%" }}
        />
      </div>

      {/* Step dots */}
      <div className="flex items-center justify-center gap-1.5">
        {WIZARD_STEPS.map((step) => {
          const isActive = step.id === currentStep;
          const isCompleted = completedSteps.includes(step.id);
          const highestCompleted = Math.max(0, ...completedSteps);
          const isClickable = isCompleted || step.id <= highestCompleted + 1;

          return (
            <button
              key={step.id}
              type="button"
              onClick={isClickable && onStepClick ? () => onStepClick(step.id) : undefined}
              disabled={!isClickable}
              className={cn(
                "relative h-2 w-2 rounded-full transition-all duration-300",
                isCompleted && "bg-[oklch(0.72_0.19_145)]",
                isActive && !isCompleted && "bg-primary scale-125",
                !isActive && !isCompleted && "bg-muted-foreground/30",
                isClickable && "cursor-pointer",
                !isClickable && "cursor-not-allowed"
              )}
              aria-label={`Go to step ${step.id}: ${step.title}`}
            >
              {/* Active step ring */}
              {isActive && (
                <span className="absolute inset-[-3px] animate-ping rounded-full bg-primary/40" />
              )}
            </button>
          );
        })}
      </div>

      {/* Current step label */}
      {currentStepData && (
        <div className="text-center">
          <span className="text-sm font-medium text-foreground">
            {currentStepData.title}
          </span>
        </div>
      )}
    </div>
  );
}

export type { WizardStep };
