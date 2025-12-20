'use client';

import { useEffect, useRef, useCallback } from 'react';
import {
  WizardStep,
  trackWizardStep,
  trackWizardStepComplete,
  trackWizardAbandonment,
  trackConversion,
  trackFunnelStepEnter,
  trackFunnelStepComplete,
  trackFunnelDropoff,
} from '@/lib/analytics';

interface UseWizardAnalyticsOptions {
  step: WizardStep;
  stepNumber: number;
  stepTitle: string;
  totalSteps?: number;
}

/**
 * Hook for tracking wizard step analytics with full funnel instrumentation
 * Automatically tracks step views, time spent, funnel progression, and provides helpers
 */
export function useWizardAnalytics({
  step,
  stepNumber,
  stepTitle,
  totalSteps = 10,
}: UseWizardAnalyticsOptions) {
  const startTime = useRef<number>(0);
  const hasTrackedView = useRef<boolean>(false);
  const isCompleted = useRef<boolean>(false);

  // Track step view on mount
  useEffect(() => {
    if (hasTrackedView.current) return;
    hasTrackedView.current = true;

    startTime.current = Date.now();

    // Track legacy wizard step event
    trackWizardStep(step, stepNumber, {
      total_steps: totalSteps,
      progress_percentage: Math.round((stepNumber / totalSteps) * 100),
    });

    // Track funnel step entry (comprehensive funnel tracking)
    trackFunnelStepEnter(stepNumber, step, stepTitle);

    // Track wizard start conversion on first step
    if (stepNumber === 1) {
      trackConversion('wizard_start');
    }
  }, [step, stepNumber, stepTitle, totalSteps]);

  // Calculate time spent
  const getTimeSpent = useCallback((): number => {
    return Math.floor((Date.now() - startTime.current) / 1000);
  }, []);

  // Track step completion
  const markComplete = useCallback((additionalData?: Record<string, unknown>) => {
    if (isCompleted.current) return;
    isCompleted.current = true;

    const timeSpent = getTimeSpent();

    // Track legacy event
    trackWizardStepComplete(step, stepNumber, timeSpent);

    // Track funnel step completion
    trackFunnelStepComplete(stepNumber, step, {
      step_title: stepTitle,
      ...additionalData,
    });
  }, [step, stepNumber, stepTitle, getTimeSpent]);

  // Track abandonment
  const markAbandoned = useCallback((reason?: string) => {
    trackWizardAbandonment(step, stepNumber, reason);
    trackFunnelDropoff(reason);
  }, [step, stepNumber]);

  // Track potential abandonment on unmount
  useEffect(() => {
    const handleBeforeUnload = () => {
      if (!isCompleted.current) {
        trackFunnelDropoff('page_exit');
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
    };
  }, []);

  return {
    getTimeSpent,
    markComplete,
    markAbandoned,
  };
}

export default useWizardAnalytics;
