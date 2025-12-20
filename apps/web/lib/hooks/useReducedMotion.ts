"use client";

import { useSyncExternalStore } from "react";

const PREFERS_REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";

function subscribe(callback: () => void) {
  if (typeof window === "undefined") return () => {};

  const mediaQuery = window.matchMedia(PREFERS_REDUCED_MOTION_QUERY);
  const handler = () => callback();

  // Modern API (all current browsers)
  mediaQuery.addEventListener("change", handler);
  return () => mediaQuery.removeEventListener("change", handler);
}

function getSnapshot() {
  if (typeof window === "undefined") return false;
  return window.matchMedia(PREFERS_REDUCED_MOTION_QUERY).matches;
}

function getServerSnapshot() {
  return false;
}

/**
 * Hook to detect user's reduced motion preference.
 * Respects the `prefers-reduced-motion` media query for accessibility.
 *
 * @returns boolean - true if user prefers reduced motion
 *
 * @example
 * const prefersReducedMotion = useReducedMotion();
 * const animation = prefersReducedMotion ? {} : { y: [20, 0], opacity: [0, 1] };
 */
export function useReducedMotion(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

/**
 * Returns animation props that respect reduced motion preferences.
 * Use this to wrap animation objects for accessible animations.
 *
 * @param animation - The animation properties when motion is enabled
 * @returns The animation or an empty object if reduced motion is preferred
 *
 * @example
 * const fadeUp = useAccessibleAnimation({ y: 20, opacity: 0 });
 * <motion.div initial={fadeUp} animate={{ y: 0, opacity: 1 }} />
 */
export function useAccessibleAnimation<T extends object>(animation: T): T | Record<string, never> {
  const prefersReducedMotion = useReducedMotion();
  return prefersReducedMotion ? {} : animation;
}
