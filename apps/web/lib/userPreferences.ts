/**
 * User Preferences Storage
 *
 * Handles localStorage persistence of user choices during the wizard.
 * Uses TanStack Query for React state management with localStorage persistence.
 */

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useCallback } from "react";

export type OperatingSystem = "mac" | "windows";

const OS_KEY = "acfs-user-os";
const VPS_IP_KEY = "acfs-vps-ip";

// Query keys for TanStack Query
export const userPreferencesKeys = {
  userOS: ["userPreferences", "os"] as const,
  vpsIP: ["userPreferences", "vpsIP"] as const,
  detectedOS: ["userPreferences", "detectedOS"] as const,
};

/**
 * Get the user's selected operating system from localStorage.
 */
export function getUserOS(): OperatingSystem | null {
  if (typeof window === "undefined") return null;
  const stored = localStorage.getItem(OS_KEY);
  if (stored === "mac" || stored === "windows") {
    return stored;
  }
  return null;
}

/**
 * Save the user's operating system selection to localStorage.
 */
export function setUserOS(os: OperatingSystem): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(OS_KEY, os);
}

/**
 * Detect the user's OS from the browser's user agent.
 * Returns null if detection fails or on server-side.
 */
export function detectOS(): OperatingSystem | null {
  if (typeof window === "undefined") return null;

  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes("mac")) return "mac";
  if (ua.includes("win")) return "windows";
  return null;
}

/**
 * Get the user's VPS IP address from localStorage.
 */
export function getVPSIP(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(VPS_IP_KEY);
}

/**
 * Save the user's VPS IP address to localStorage.
 */
export function setVPSIP(ip: string): void {
  if (typeof window === "undefined") return;
  localStorage.setItem(VPS_IP_KEY, ip);
}

/**
 * Validate an IP address (basic IPv4 validation).
 */
export function isValidIP(ip: string): boolean {
  const pattern = /^(\d{1,3}\.){3}\d{1,3}$/;
  if (!pattern.test(ip)) return false;

  const parts = ip.split(".");
  return parts.every((part) => {
    const num = parseInt(part, 10);
    return num >= 0 && num <= 255;
  });
}

// --- React Hooks using TanStack Query ---

/**
 * Hook to get and set the user's operating system.
 * Uses TanStack Query for state management with localStorage persistence.
 */
export function useUserOS(): [OperatingSystem | null, (os: OperatingSystem) => void] {
  const queryClient = useQueryClient();

  const { data: os } = useQuery({
    queryKey: userPreferencesKeys.userOS,
    queryFn: getUserOS,
    staleTime: Infinity,
    gcTime: Infinity,
  });

  const mutation = useMutation({
    mutationFn: async (newOS: OperatingSystem) => {
      setUserOS(newOS);
      return newOS;
    },
    onSuccess: (newOS) => {
      queryClient.setQueryData(userPreferencesKeys.userOS, newOS);
    },
  });

  const setOS = useCallback(
    (newOS: OperatingSystem) => {
      mutation.mutate(newOS);
    },
    [mutation]
  );

  return [os ?? null, setOS];
}

/**
 * Hook to get and set the VPS IP address.
 * Uses TanStack Query for state management with localStorage persistence.
 */
export function useVPSIP(): [string | null, (ip: string) => void] {
  const queryClient = useQueryClient();

  const { data: ip } = useQuery({
    queryKey: userPreferencesKeys.vpsIP,
    queryFn: getVPSIP,
    staleTime: Infinity,
    gcTime: Infinity,
  });

  const mutation = useMutation({
    mutationFn: async (newIP: string) => {
      setVPSIP(newIP);
      return newIP;
    },
    onSuccess: (newIP) => {
      queryClient.setQueryData(userPreferencesKeys.vpsIP, newIP);
    },
  });

  const setIP = useCallback(
    (newIP: string) => {
      mutation.mutate(newIP);
    },
    [mutation]
  );

  return [ip ?? null, setIP];
}

/**
 * Hook to get the detected OS (from user agent).
 * Only runs on client side.
 */
export function useDetectedOS(): OperatingSystem | null {
  const { data: detectedOS } = useQuery({
    queryKey: userPreferencesKeys.detectedOS,
    queryFn: detectOS,
    staleTime: Infinity,
    gcTime: Infinity,
  });

  return detectedOS ?? null;
}

/**
 * Hook to track if the component is mounted (client-side hydrated).
 * Returns true once the component is mounted on the client.
 */
export function useMounted(): boolean {
  const { data: isMounted } = useQuery({
    queryKey: ["mounted"],
    queryFn: () => true,
    staleTime: Infinity,
    gcTime: Infinity,
  });

  return isMounted ?? false;
}
