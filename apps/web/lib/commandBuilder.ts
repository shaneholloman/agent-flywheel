/**
 * Command Builder
 *
 * Generates personalized SSH, installer, and post-install commands
 * based on user preferences (IP, OS, username, mode, ref).
 *
 * @see bd-31ps.4 for the full spec
 */

import type { OperatingSystem, InstallMode } from "./userPreferences";

const INSTALL_URL =
  "https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/install.sh";

export interface CommandBuilderInputs {
  ip: string;
  os: OperatingSystem;
  username: string;
  mode: InstallMode;
  ref: string | null;
}

export interface GeneratedCommand {
  id: string;
  label: string;
  description: string;
  command: string;
  windowsCommand?: string;
  runLocation: "local" | "vps";
}

function sshKeyPath(os: OperatingSystem): string {
  return os === "windows"
    ? "$HOME\\.ssh\\acfs_ed25519"
    : "~/.ssh/acfs_ed25519";
}

function sshKeyPathWindows(): string {
  return "$HOME\\.ssh\\acfs_ed25519";
}

/**
 * Build all personalized commands from user inputs.
 */
export function buildCommands(inputs: CommandBuilderInputs): GeneratedCommand[] {
  const { ip, os, username, mode, ref } = inputs;
  const keyPath = sshKeyPath(os);
  const keyPathWin = sshKeyPathWindows();

  const commands: GeneratedCommand[] = [];

  // 1. SSH as root (first-time setup)
  commands.push({
    id: "ssh-root",
    label: "SSH as root",
    description: "First-time connection with your VPS password",
    command: `ssh root@${ip}`,
    runLocation: "local",
  });

  // 2. Installer
  const refEnv = ref ? `ACFS_REF="${ref}" ` : "";
  const cacheBust = "$(date +%s)";
  const installerBase = `curl -fsSL "${INSTALL_URL}?${cacheBust}" | bash -s -- --yes --mode ${mode}`;
  commands.push({
    id: "installer",
    label: "Run installer",
    description: `Install ACFS in ${mode} mode${ref ? ` pinned to ${ref}` : ""}`,
    command: `${refEnv}${installerBase}`,
    runLocation: "vps",
  });

  // 3. SSH as configured user (post-install, key-based)
  commands.push({
    id: "ssh-user",
    label: `SSH as ${username}`,
    description: "Key-based login after installer completes",
    command: `ssh -i ${keyPath} ${username}@${ip}`,
    windowsCommand: `ssh -i ${keyPathWin} ${username}@${ip}`,
    runLocation: "local",
  });

  // 4. Doctor check
  commands.push({
    id: "doctor",
    label: "Health check",
    description: "Verify all tools installed correctly",
    command: "acfs doctor",
    runLocation: "vps",
  });

  // 5. Onboard
  commands.push({
    id: "onboard",
    label: "Start tutorial",
    description: "Launch the interactive onboarding",
    command: "onboard",
    runLocation: "vps",
  });

  return commands;
}

/**
 * Build a shareable URL with all command builder state encoded as query params.
 */
export function buildShareURL(inputs: CommandBuilderInputs): string {
  if (typeof window === "undefined") return "";
  const url = new URL(window.location.href);
  url.searchParams.set("ip", inputs.ip);
  url.searchParams.set("os", inputs.os);
  if (inputs.username !== "ubuntu") {
    url.searchParams.set("user", inputs.username);
  } else {
    url.searchParams.delete("user");
  }
  url.searchParams.set("mode", inputs.mode);
  if (inputs.ref) {
    url.searchParams.set("ref", inputs.ref);
  } else {
    url.searchParams.delete("ref");
  }
  return url.toString();
}
