/**
 * User Preferences Storage
 *
 * Handles localStorage persistence of user choices during the wizard.
 * Uses TanStack Query for React state management with localStorage persistence.
 */

import { useQuery } from "@tanstack/react-query";
import { useCallback, useEffect, useState } from "react";
import { safeGetItem, safeSetItem } from "./utils";

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
  const stored = safeGetItem(OS_KEY);
  if (stored === "mac" || stored === "windows") {
    return stored;
  }
  return null;
}

/**
 * Save the user's operating system selection to localStorage.
 */
export function setUserOS(os: OperatingSystem): void {
  safeSetItem(OS_KEY, os);
}

/**
 * Detect the user's OS from the browser's user agent.
 * Returns null if detection fails or on server-side.
 */
export function detectOS(): OperatingSystem | null {
  if (typeof window === "undefined") return null;

  const ua = navigator.userAgent.toLowerCase();

  // If the user is on a phone/tablet, we can't reliably infer the OS of the
  // computer they'll use for the terminal/VPS steps. Force an explicit choice.
  if (ua.includes("iphone") || ua.includes("ipad") || ua.includes("ipod") || ua.includes("android")) {
    return null;
  }

  if (ua.includes("win")) return "windows";

  // Avoid mis-detecting iOS user agents that contain "like Mac OS X".
  if (ua.includes("mac") && !ua.includes("like mac os x")) return "mac";
  return null;
}

/**
 * Get the user's VPS IP address from localStorage.
 */
export function getVPSIP(): string | null {
  return safeGetItem(VPS_IP_KEY);
}

/**
 * Save the user's VPS IP address to localStorage.
 * Only saves if the IP is valid to prevent storing malformed data.
 * Returns true if saved successfully, false otherwise.
 */
export function setVPSIP(ip: string): boolean {
  const normalized = ip.trim();
  if (!isValidIP(normalized)) {
    return false;
  }
  return safeSetItem(VPS_IP_KEY, normalized);
}

/**
 * Validate an IP address (basic IPv4 validation).
 */
export function isValidIP(ip: string): boolean {
  const normalized = ip.trim();
  const pattern = /^(\d{1,3}\.){3}\d{1,3}$/;
  if (!pattern.test(normalized)) return false;

  const parts = normalized.split(".");
  return parts.every((part) => {
    const num = parseInt(part, 10);
    return num >= 0 && num <= 255;
  });
}

// --- React Hooks for User Preferences ---
// Using local state + effects for SSR-safe localStorage access.
// Also provides a `loaded` boolean so callers can avoid redirect races.

/**
 * Hook to get and set the user's operating system.
 * Uses SSR-safe localStorage loading + an explicit `loaded` flag.
 */
export function useUserOS(): [OperatingSystem | null, (os: OperatingSystem) => void, boolean] {
  const [userOSState, setUserOSState] = useState<{
    os: OperatingSystem | null;
    loaded: boolean;
  }>({ os: null, loaded: false });

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- localStorage access must happen after mount (SSR-safe)
    setUserOSState({ os: getUserOS(), loaded: true });
  }, []);

  const setOS = useCallback((newOS: OperatingSystem) => {
    setUserOS(newOS);
    setUserOSState({ os: newOS, loaded: true });
  }, []);

  return [userOSState.os, setOS, userOSState.loaded];
}

/**
 * Hook to get and set the VPS IP address.
 * Uses SSR-safe localStorage loading + an explicit `loaded` flag.
 */
export function useVPSIP(): [string | null, (ip: string) => void, boolean] {
  const [vpsIPState, setVpsIPState] = useState<{
    ip: string | null;
    loaded: boolean;
  }>({ ip: null, loaded: false });

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- localStorage access must happen after mount (SSR-safe)
    setVpsIPState({ ip: getVPSIP(), loaded: true });
  }, []);

  const setIP = useCallback((newIP: string) => {
    if (setVPSIP(newIP)) {
      setVpsIPState({ ip: newIP, loaded: true });
    }
  }, []);

  return [vpsIPState.ip, setIP, vpsIPState.loaded];
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
 * Returns true on client, false on server.
 */
export function useMounted(): boolean {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- hydration detection
    setMounted(true);
  }, []);

  return mounted;
}
