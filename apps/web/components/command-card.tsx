"use client";

import { useState, useCallback, useSyncExternalStore } from "react";
import { Check, Copy, Terminal } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { cn } from "@/lib/utils";
import { useDetectedOS, useUserOS } from "@/lib/userPreferences";

export interface CommandCardProps {
  /** The default command to display */
  command: string;
  /** Mac-specific command (if different from default) */
  macCommand?: string;
  /** Windows-specific command (if different from default) */
  windowsCommand?: string;
  /** Description text shown above the command */
  description?: string;
  /** Whether to show the "I ran this" checkbox */
  showCheckbox?: boolean;
  /** Unique ID for persisting checkbox state in localStorage */
  persistKey?: string;
  /** Callback when checkbox is checked */
  onComplete?: () => void;
  /** Additional class names */
  className?: string;
}

type OS = "mac" | "windows" | "linux";

type CheckedState = boolean | "indeterminate";

const COMPLETION_KEY_PREFIX = "acfs-command-";
const completionListenersByKey = new Map<string, Set<() => void>>();

function getCompletionKey(persistKey: string | undefined): string | null {
  return persistKey ? `${COMPLETION_KEY_PREFIX}${persistKey}` : null;
}

function emitCompletionChange(key: string) {
  const listeners = completionListenersByKey.get(key);
  if (!listeners) return;
  listeners.forEach((listener) => listener());
}

function subscribeToCompletion(key: string, callback: () => void) {
  if (typeof window === "undefined") {
    return () => {}; // No-op on server
  }

  const listeners = completionListenersByKey.get(key) ?? new Set();
  listeners.add(callback);
  completionListenersByKey.set(key, listeners);

  const handleStorage = (e: StorageEvent) => {
    if (e.key === key) callback();
  };
  window.addEventListener("storage", handleStorage);

  return () => {
    const set = completionListenersByKey.get(key);
    if (set) {
      set.delete(callback);
      if (set.size === 0) {
        completionListenersByKey.delete(key);
      }
    }
    window.removeEventListener("storage", handleStorage);
  };
}

function getCompletionSnapshot(key: string | null): boolean {
  if (!key || typeof window === "undefined") return false;
  return localStorage.getItem(key) === "true";
}

export function CommandCard({
  command,
  macCommand,
  windowsCommand,
  description,
  showCheckbox = false,
  persistKey,
  onComplete,
  className,
}: CommandCardProps) {
  const [copied, setCopied] = useState(false);

  const [storedOS] = useUserOS();
  const detectedOS = useDetectedOS();
  const os: OS = storedOS ?? detectedOS ?? "mac";

  // Use useSyncExternalStore for completion state
  const completionKey = getCompletionKey(persistKey);
  const completed = useSyncExternalStore(
    (callback) => {
      if (!completionKey) return () => {};
      return subscribeToCompletion(completionKey, callback);
    },
    () => getCompletionSnapshot(completionKey),
    () => false // Server snapshot
  );

  // Get the appropriate command for the current OS
  const displayCommand = (() => {
    if (os === "mac" && macCommand) return macCommand;
    if (os === "windows" && windowsCommand) return windowsCommand;
    return command;
  })();

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(displayCommand);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback for older browsers
      const textarea = document.createElement("textarea");
      textarea.value = displayCommand;
      textarea.style.position = "fixed";
      textarea.style.opacity = "0";
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      document.body.removeChild(textarea);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  }, [displayCommand]);

  const handleCheckboxChange = useCallback(
    (checked: CheckedState) => {
      const isChecked = checked === true;

      if (completionKey && typeof window !== "undefined") {
        localStorage.setItem(completionKey, isChecked ? "true" : "false");
        emitCompletionChange(completionKey);
      }

      if (isChecked && onComplete) {
        onComplete();
      }
    },
    [completionKey, onComplete]
  );

  return (
    <Card className={cn("overflow-hidden", className)}>
      {description && (
        <p className="px-4 pt-4 text-sm text-muted-foreground">{description}</p>
      )}
      <div className="flex items-stretch">
        <div className="flex flex-1 items-center gap-2 bg-muted/50 px-4 py-3">
          <Terminal className="h-4 w-4 shrink-0 text-muted-foreground" />
          <code className="flex-1 break-all font-mono text-sm">
            {displayCommand}
          </code>
        </div>
        <Button
          variant="ghost"
          size="icon"
          className="h-auto w-12 shrink-0 rounded-none border-l"
          onClick={handleCopy}
          aria-label={copied ? "Copied!" : "Copy command"}
        >
          {copied ? (
            <Check className="h-4 w-4 text-green-500" />
          ) : (
            <Copy className="h-4 w-4" />
          )}
        </Button>
      </div>
      {showCheckbox && (
        <div className="flex items-center gap-2 border-t px-4 py-3">
          <Checkbox
            id={persistKey || "command-completed"}
            checked={completed}
            onCheckedChange={handleCheckboxChange}
          />
          <label
            htmlFor={persistKey || "command-completed"}
            className="cursor-pointer text-sm text-muted-foreground"
          >
            I ran this command
          </label>
        </div>
      )}
    </Card>
  );
}
