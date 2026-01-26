"use client";

import { useCallback, useMemo, useState } from "react";
import {
  Terminal,
  Link2,
  Check,
  Copy,
  Server,
  Monitor,
  Settings2,
  ChevronDown,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import {
  useVPSIP,
  useUserOS,
  useInstallMode,
  useSSHUsername,
  useACFSRef,
  isValidIP,
  type InstallMode,
} from "@/lib/userPreferences";
import { buildCommands, buildShareURL } from "@/lib/commandBuilder";

function LocationBadge({ location }: { location: "local" | "vps" }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider",
        location === "vps"
          ? "bg-[oklch(0.72_0.19_145/0.15)] text-[oklch(0.72_0.19_145)]"
          : "bg-primary/15 text-primary",
      )}
    >
      {location === "vps" ? (
        <Server className="h-2.5 w-2.5" />
      ) : (
        <Monitor className="h-2.5 w-2.5" />
      )}
      {location === "vps" ? "VPS" : "Local"}
    </span>
  );
}

function CommandRow({
  label,
  description,
  command,
  runLocation,
}: {
  label: string;
  description: string;
  command: string;
  runLocation: "local" | "vps";
}) {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(command);
    } catch {
      const ta = document.createElement("textarea");
      ta.value = command;
      ta.style.position = "fixed";
      ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      document.body.removeChild(ta);
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }, [command]);

  return (
    <div className="group rounded-lg border border-border/50 bg-card/50 p-3 transition-colors hover:border-border">
      <div className="mb-2 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-foreground">{label}</span>
          <LocationBadge location={runLocation} />
        </div>
        <span className="text-xs text-muted-foreground">{description}</span>
      </div>
      <div className="flex items-center gap-2">
        <code className="flex-1 overflow-x-auto rounded-md bg-muted/60 px-3 py-2 font-mono text-sm text-foreground">
          {command}
        </code>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 shrink-0"
          onClick={handleCopy}
          aria-label={`Copy ${label} command`}
        >
          {copied ? (
            <Check className="h-4 w-4 text-[oklch(0.72_0.19_145)]" />
          ) : (
            <Copy className="h-4 w-4 text-muted-foreground" />
          )}
        </Button>
      </div>
    </div>
  );
}

function SettingsToggle({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: { value: string; label: string }[];
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-xs text-muted-foreground">{label}:</span>
      <div className="flex rounded-lg border border-border/50 bg-muted/30 p-0.5">
        {options.map((opt) => (
          <button
            key={opt.value}
            type="button"
            onClick={() => onChange(opt.value)}
            className={cn(
              "rounded-md px-2.5 py-1 text-xs font-medium transition-colors",
              value === opt.value
                ? "bg-primary text-primary-foreground shadow-sm"
                : "text-muted-foreground hover:text-foreground",
            )}
          >
            {opt.label}
          </button>
        ))}
      </div>
    </div>
  );
}

export function CommandBuilderPanel() {
  const [vpsIP] = useVPSIP();
  const [os] = useUserOS();
  const [mode, setMode] = useInstallMode();
  const [username, setUsername] = useSSHUsername();
  const [ref, setRef] = useACFSRef();
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [shareCopied, setShareCopied] = useState(false);
  const [localIP, setLocalIP] = useState("");
  const [ipError, setIpError] = useState<string | null>(null);

  const effectiveIP = vpsIP || localIP;
  const effectiveOS = os || "mac";

  const commands = useMemo(() => {
    if (!effectiveIP) return null;
    return buildCommands({
      ip: effectiveIP,
      os: effectiveOS,
      username,
      mode,
      ref,
    });
  }, [effectiveIP, effectiveOS, username, mode, ref]);

  const handleShare = useCallback(async () => {
    if (!effectiveIP) return;
    const url = buildShareURL({
      ip: effectiveIP,
      os: effectiveOS,
      username,
      mode,
      ref,
    });
    try {
      await navigator.clipboard.writeText(url);
    } catch {
      // silent fail
    }
    setShareCopied(true);
    setTimeout(() => setShareCopied(false), 2000);
  }, [effectiveIP, effectiveOS, username, mode, ref]);

  const handleIPChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const val = e.target.value.trim();
      setLocalIP(val);
      if (val && !isValidIP(val)) {
        setIpError("Enter a valid IP (e.g., 203.0.113.42)");
      } else {
        setIpError(null);
      }
    },
    [],
  );

  return (
    <div className="space-y-4 rounded-xl border border-border/50 bg-card/30 p-5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Terminal className="h-4 w-4 text-primary" />
          <h3 className="text-sm font-semibold text-foreground">
            Your Commands
          </h3>
        </div>
        {effectiveIP && (
          <Button
            variant="ghost"
            size="sm"
            onClick={handleShare}
            className="h-7 gap-1.5 text-xs text-muted-foreground"
          >
            {shareCopied ? (
              <Check className="h-3 w-3 text-[oklch(0.72_0.19_145)]" />
            ) : (
              <Link2 className="h-3 w-3" />
            )}
            {shareCopied ? "Copied!" : "Share link"}
          </Button>
        )}
      </div>

      {/* IP input (only if no IP stored from wizard) */}
      {!vpsIP && (
        <div>
          <label className="text-xs text-muted-foreground" htmlFor="cb-ip">
            VPS IP address
          </label>
          <input
            id="cb-ip"
            type="text"
            value={localIP}
            onChange={handleIPChange}
            placeholder="203.0.113.42"
            className={cn(
              "mt-1 w-full rounded-lg border bg-muted/40 px-3 py-2 font-mono text-sm text-foreground placeholder:text-muted-foreground/50 focus:outline-none focus:ring-2 focus:ring-primary/40",
              ipError ? "border-destructive" : "border-border/50",
            )}
          />
          {ipError && (
            <p className="mt-1 text-xs text-destructive">{ipError}</p>
          )}
        </div>
      )}

      {/* Mode toggle */}
      <div className="flex flex-wrap items-center gap-4">
        <SettingsToggle
          label="Mode"
          options={[
            { value: "vibe", label: "Vibe" },
            { value: "safe", label: "Safe" },
          ]}
          value={mode}
          onChange={(v) => setMode(v as InstallMode)}
        />

        <button
          type="button"
          onClick={() => setShowAdvanced(!showAdvanced)}
          className="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground transition-colors"
        >
          <Settings2 className="h-3 w-3" />
          Advanced
          <ChevronDown
            className={cn(
              "h-3 w-3 transition-transform",
              showAdvanced && "rotate-180",
            )}
          />
        </button>
      </div>

      {/* Advanced settings */}
      {showAdvanced && (
        <div className="space-y-3 rounded-lg border border-border/30 bg-muted/20 p-3">
          <div>
            <label className="text-xs text-muted-foreground" htmlFor="cb-user">
              SSH username
            </label>
            <input
              id="cb-user"
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="ubuntu"
              className="mt-1 w-full rounded-md border border-border/50 bg-muted/40 px-3 py-1.5 font-mono text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-primary/40"
            />
          </div>
          <div>
            <label className="text-xs text-muted-foreground" htmlFor="cb-ref">
              Pin to git ref{" "}
              <span className="text-muted-foreground/50">(optional)</span>
            </label>
            <input
              id="cb-ref"
              type="text"
              value={ref || ""}
              onChange={(e) => setRef(e.target.value || null)}
              placeholder="main"
              className="mt-1 w-full rounded-md border border-border/50 bg-muted/40 px-3 py-1.5 font-mono text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-primary/40"
            />
          </div>
        </div>
      )}

      {/* Commands list */}
      {commands ? (
        <div className="space-y-2">
          {commands.map((cmd) => (
            <CommandRow
              key={cmd.id}
              label={cmd.label}
              description={cmd.description}
              command={
                effectiveOS === "windows" && cmd.windowsCommand
                  ? cmd.windowsCommand
                  : cmd.command
              }
              runLocation={cmd.runLocation}
            />
          ))}
        </div>
      ) : (
        <p className="py-4 text-center text-sm text-muted-foreground">
          Enter your VPS IP to generate personalized commands.
        </p>
      )}
    </div>
  );
}
