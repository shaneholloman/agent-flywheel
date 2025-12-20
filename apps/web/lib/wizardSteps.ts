/**
 * Wizard Steps Configuration
 *
 * Defines the 10 steps of the ACFS setup wizard.
 * Each step guides beginners from "I have a laptop" to "fully configured VPS".
 * Uses TanStack Query for React state management with localStorage persistence.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";

export interface WizardStep {
  /** Step number (1-10) */
  id: number;
  /** Short title for the step */
  title: string;
  /** Longer description of what happens in this step */
  description: string;
  /** URL slug for this step (e.g., "os-selection") */
  slug: string;
}

export const WIZARD_STEPS: WizardStep[] = [
  {
    id: 1,
    title: "Choose Your OS",
    description: "Select whether you're using Mac or Windows",
    slug: "os-selection",
  },
  {
    id: 2,
    title: "Install Terminal",
    description: "Get a proper terminal application set up",
    slug: "install-terminal",
  },
  {
    id: 3,
    title: "Generate SSH Key",
    description: "Create your SSH key pair for secure VPS access",
    slug: "generate-ssh-key",
  },
  {
    id: 4,
    title: "Rent a VPS",
    description: "Choose and sign up for a VPS provider",
    slug: "rent-vps",
  },
  {
    id: 5,
    title: "Create VPS Instance",
    description: "Launch your VPS and attach your SSH key",
    slug: "create-vps",
  },
  {
    id: 6,
    title: "SSH Into Your VPS",
    description: "Connect to your VPS for the first time",
    slug: "ssh-connect",
  },
  {
    id: 7,
    title: "Run ACFS Installer",
    description: "Paste and run the one-liner to install everything",
    slug: "run-installer",
  },
  {
    id: 8,
    title: "Reconnect as Ubuntu",
    description: "Switch from root to your ubuntu user",
    slug: "reconnect-ubuntu",
  },
  {
    id: 9,
    title: "ACFS Status Check",
    description: "Verify everything installed correctly",
    slug: "status-check",
  },
  {
    id: 10,
    title: "Launch Onboarding",
    description: "Start the interactive tutorial",
    slug: "launch-onboarding",
  },
];

/** Total number of wizard steps */
export const TOTAL_STEPS = WIZARD_STEPS.length;

/** Get a step by its ID (1-indexed) */
export function getStepById(id: number): WizardStep | undefined {
  return WIZARD_STEPS.find((step) => step.id === id);
}

/** Get a step by its URL slug */
export function getStepBySlug(slug: string): WizardStep | undefined {
  return WIZARD_STEPS.find((step) => step.slug === slug);
}

/** localStorage key for storing completed steps */
export const COMPLETED_STEPS_KEY = "acfs-wizard-completed-steps";

// Query keys for TanStack Query
export const wizardStepsKeys = {
  completedSteps: ["wizardSteps", "completed"] as const,
};

/** Get completed steps from localStorage */
export function getCompletedSteps(): number[] {
  if (typeof window === "undefined") return [];
  const stored = localStorage.getItem(COMPLETED_STEPS_KEY);
  if (!stored) return [];
  try {
    const parsed = JSON.parse(stored);
    if (Array.isArray(parsed)) {
      return parsed.filter((n): n is number => typeof n === "number");
    }
  } catch {
    // Invalid JSON, ignore
  }
  return [];
}

/** Save completed steps to localStorage */
export function setCompletedSteps(steps: number[]): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(COMPLETED_STEPS_KEY, JSON.stringify(steps));
}

/** Mark a step as completed (pure function, returns new array) */
export function addCompletedStep(currentSteps: number[], stepId: number): number[] {
  if (currentSteps.includes(stepId)) {
    return currentSteps;
  }
  const newSteps = [...currentSteps, stepId];
  newSteps.sort((a, b) => a - b);
  return newSteps;
}

// --- React Hooks using TanStack Query ---

/**
 * Hook to get and manage completed wizard steps.
 * Uses TanStack Query for state management with localStorage persistence.
 */
export function useCompletedSteps(): [number[], (stepId: number) => void] {
  const queryClient = useQueryClient();

  const { data: steps } = useQuery({
    queryKey: wizardStepsKeys.completedSteps,
    queryFn: getCompletedSteps,
    staleTime: Infinity,
    gcTime: Infinity,
  });

  const mutation = useMutation({
    mutationFn: async (stepId: number) => {
      const currentSteps = getCompletedSteps();
      const newSteps = addCompletedStep(currentSteps, stepId);
      setCompletedSteps(newSteps);
      return newSteps;
    },
    onSuccess: (newSteps) => {
      queryClient.setQueryData(wizardStepsKeys.completedSteps, newSteps);
    },
  });

  const markComplete = useCallback(
    (stepId: number) => {
      mutation.mutate(stepId);
    },
    [mutation]
  );

  return [steps ?? [], markComplete];
}

/**
 * Imperatively mark a step as complete (for use outside React components).
 * Note: If used, you should invalidate the query in components that depend on it.
 */
export function markStepComplete(stepId: number): number[] {
  const completed = getCompletedSteps();
  const newSteps = addCompletedStep(completed, stepId);
  if (newSteps !== completed) {
    setCompletedSteps(newSteps);
  }
  return newSteps;
}
