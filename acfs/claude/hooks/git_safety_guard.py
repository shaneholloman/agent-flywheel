#!/usr/bin/env python3
"""
ACFS Git Safety Guard - Claude Code PreToolUse Hook

Blocks destructive git/filesystem commands before execution to prevent
accidental data loss. Integrates with Claude Code's hook system.

Source: Adapted from misc_coding_agent_tips_and_scripts

Usage:
    This script is called by Claude Code via PreToolUse hook.
    It reads JSON from stdin and outputs deny/allow decisions.

Installation:
    1. Copy to ~/.claude/hooks/git_safety_guard.py
    2. Add to ~/.claude/settings.json:
       {
         "hooks": {
           "PreToolUse": [{
             "matcher": "Bash",
             "hooks": [{"type": "command", "command": "~/.claude/hooks/git_safety_guard.py"}]
           }]
         }
       }
    3. Restart Claude Code
"""

import json
import re
import shlex
import sys

# Shell wrappers we may need to unwrap to analyze the underlying command.
SHELL_WRAPPERS = ("bash", "sh", "zsh", "dash")

# Patterns that should be BLOCKED
DESTRUCTIVE_PATTERNS = [
    # Git: Discard uncommitted changes
    (r"git checkout --\s", "Permanently discards uncommitted changes to tracked files"),
    (r"git checkout\s+\.(?:\s*$|\s*[;&|])", "Discards all uncommitted changes in current directory"),
    (r"git restore\s+(?!--staged)", "Discards uncommitted changes (use --staged to only unstage)"),

    # Git: Hard reset
    (r"git reset --hard", "Destroys all uncommitted modifications and staging"),
    (r"git reset --merge", "Can destroy uncommitted changes during merge"),

    # Git: Dangerous branch operations
    (r"git branch -D", "Force-deletes branch bypassing merge safety checks"),

    # Git: Stash destruction
    (r"git stash drop", "Permanently loses stashed changes"),
    (r"git stash clear", "Permanently loses ALL stashed changes"),
]


SHELL_OPERATORS = ("&&", "||", ";", "|", "\n")


def _basename(token: str) -> str:
    return token.rsplit("/", 1)[-1]


def _has_shell_operators(command: str) -> bool:
    # Compound commands are difficult to analyze safely with lightweight checks.
    # We refuse to auto-approve "dangerous-looking" operations in that case.
    return any(op in command for op in SHELL_OPERATORS)


def _try_shlex_split(command: str) -> list[str] | None:
    try:
        return shlex.split(command, posix=True)
    except ValueError:
        return None


def _strip_common_wrappers(tokens: list[str]) -> list[str]:
    """
    Strip common wrappers like `sudo` and `env` to reach the underlying command.

    This is intentionally conservative and only handles the most common cases.
    If parsing gets ambiguous, we fall back to regex-based blocking.
    """
    def strip_once(current: list[str]) -> list[str]:
        i = 0

        # Strip leading inline environment assignments (e.g., FOO=1 BAR=2 cmd ...).
        # This is common in agent-run commands and would otherwise bypass checks.
        while i < len(current) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", current[i]):
            i += 1

        # Strip leading `env VAR=...` assignments.
        if i < len(current) and _basename(current[i]) == "env":
            i += 1
            while i < len(current):
                t = current[i]
                if t == "--":
                    i += 1
                    break
                if t.startswith("-"):
                    i += 1
                    continue
                if "=" in t and not t.startswith("="):
                    i += 1
                    continue
                break

        # Strip a single leading `sudo ...` wrapper.
        if i < len(current) and _basename(current[i]) == "sudo":
            i += 1
            while i < len(current):
                t = current[i]
                if t == "--":
                    i += 1
                    break
                if not t.startswith("-"):
                    break
                i += 1
                # Options that take a parameter.
                if t in ("-u", "-g", "-h", "-p", "-r", "-t", "-C"):
                    if i < len(current):
                        i += 1

        # Strip a single leading `command ...` / `builtin ...` wrapper.
        # These are common ways to bypass simplistic checks.
        if i < len(current) and _basename(current[i]) in ("command", "builtin"):
            i += 1
            while i < len(current):
                t = current[i]
                if t == "--":
                    i += 1
                    break
                if not t.startswith("-"):
                    break
                i += 1

        return current[i:]

    core = tokens
    # Unwrap repeatedly to handle nested combinations like `sudo env ...` or
    # `command sudo env ...` which would otherwise bypass checks.
    for _ in range(10):
        stripped = strip_once(core)
        if stripped == core:
            break
        core = stripped
    return core


def _unwrap_shell_c_command(command: str) -> str | None:
    """
    If the command is wrapped in a shell invocation like `bash -c '...'`, return
    the inner command string. Otherwise return None.

    This blocks trivial bypasses like:
      bash -c "rm -rf /"
      sudo bash -lc "git push --force"
    """
    tokens = _try_shlex_split(command)
    if not tokens:
        return None

    core = _strip_common_wrappers(tokens)
    if not core:
        return None

    shell = _basename(core[0])
    if shell not in SHELL_WRAPPERS:
        return None

    # Find an option token that includes `c` (e.g., -c, -lc, -xec).
    i = 1
    while i < len(core):
        t = core[i]
        if t == "--":
            i += 1
            break
        if not t.startswith("-") or t == "-":
            break
        if t.startswith("--"):
            i += 1
            continue
        if "c" in t[1:]:
            return core[i + 1] if i + 1 < len(core) else None
        i += 1

    return None


def _check_rm_recursive_force(command: str) -> tuple[bool, str]:
    """
    Block `rm` with recursive+force flags unless every target is in temp dirs.

    Allowed prefixes:
    - /tmp/
    - /var/tmp/
    """
    # For compound commands we can't reliably prove safety, so we conservatively
    # block any recursive+force deletion.
    if _has_shell_operators(command):
        if re.search(
            r"\brm\b[^\n]*(?:\s--recursive\b|\s-[^\n]*r)[^\n]*(?:\s--force\b|\s-[^\n]*f)",
            command,
            re.IGNORECASE,
        ):
            return True, "Recursive forced deletion (rm -rf) in a compound command is blocked"
        return False, ""

    tokens = _try_shlex_split(command)
    if not tokens:
        if re.search(
            r"\brm\b[^\n]*(?:\s--recursive\b|\s-[^\n]*r)[^\n]*(?:\s--force\b|\s-[^\n]*f)",
            command,
            re.IGNORECASE,
        ):
            return True, "Recursive forced deletion (rm -rf) could not be parsed safely"
        return False, ""

    core = _strip_common_wrappers(tokens)
    if not core:
        return False, ""

    cmd = core[0]
    if cmd.endswith("/rm"):
        cmd = "rm"
    if cmd != "rm":
        return False, ""

    recursive = False
    force = False
    args: list[str] = []
    end_of_options = False

    for t in core[1:]:
        # After an explicit `--`, everything is an operand (even if it starts with '-').
        if end_of_options:
            args.append(t)
            continue

        if t == "--":
            end_of_options = True
            continue

        # `rm` accepts options interspersed with operands, so we keep parsing options
        # until an explicit `--` is seen.
        if t.startswith("--"):
            if t == "--recursive":
                recursive = True
            elif t == "--force":
                force = True
            continue

        if t.startswith("-") and t != "-":
            flags = t[1:].lower()
            recursive = recursive or ("r" in flags)
            force = force or ("f" in flags)
            continue

        args.append(t)

    if not (recursive and force):
        return False, ""

    if not args:
        return True, "Recursive forced deletion (rm with -r/-f) without any target path"

    # Intentionally do not treat $TMPDIR/${TMPDIR} as "safe" here. TMPDIR is
    # often unset on Linux (making "$TMPDIR/foo" expand to "/foo"), and it can
    # be overridden in ways that are hard to safely reason about pre-exec (e.g.,
    # via nested shells).
    safe_prefixes = ("/tmp/", "/var/tmp/")
    for path in args:
        if not any(path.startswith(prefix) for prefix in safe_prefixes):
            return True, "Recursive forced deletion (rm -rf) outside temporary directories"
        if any(seg == ".." for seg in path.split("/")):
            return True, "Recursive forced deletion (rm -rf) with path traversal ('..') is not allowed"

    return False, ""


def _check_git_force_push(command: str) -> tuple[bool, str]:
    """Block force pushes unless explicitly using --force-with-lease."""
    if _has_shell_operators(command):
        if re.search(r"\bgit\b[^\n]*\bpush\b", command, re.IGNORECASE) and re.search(
            r"(?:--force(?!-with-lease)\b|\b-f\b|\+\w+|--force-with-lease\b)",
            command,
            re.IGNORECASE,
        ):
            return True, "Force push flags in a compound command are blocked"
        return False, ""

    tokens = _try_shlex_split(command)
    if not tokens:
        # If we can't parse, we fail safe: block explicit force push markers.
        if re.search(r"\bgit\b[^\n]*\bpush\b", command, re.IGNORECASE) and re.search(
            r"(?:--force(?!-with-lease)\b|\b-f\b|\+\w+)",
            command,
            re.IGNORECASE,
        ):
            return True, "Force push could not be parsed safely"
        return False, ""

    core = _strip_common_wrappers(tokens)
    if len(core) < 2:
        return False, ""

    # Accept both `git ...` and explicit paths like `/usr/bin/git ...`.
    if _basename(core[0]) != "git":
        return False, ""

    # Skip common git global options to find the subcommand (e.g., `git -C repo push ...`).
    i = 1
    while i < len(core):
        t = core[i]
        if t == "--":
            i += 1
            break
        if not t.startswith("-"):
            break
        i += 1
        if t in ("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"):
            if i < len(core):
                i += 1

    if i >= len(core) or core[i] != "push":
        return False, ""

    args = core[i + 1 :]

    has_force_with_lease = any(
        t == "--force-with-lease" or t.startswith("--force-with-lease=") for t in args
    )
    has_explicit_force = any(t in ("--force", "-f") for t in args)
    has_plus_refspec = any(t.startswith("+") and len(t) > 1 for t in args)

    if (has_explicit_force or has_plus_refspec) and not has_force_with_lease:
        return True, "Force push rewrites remote history (use --force-with-lease if you must)"

    if has_force_with_lease and (has_explicit_force or has_plus_refspec):
        return True, "Refusing ambiguous force push flags; use only --force-with-lease"

    return False, ""


def _check_git_clean(command: str) -> tuple[bool, str]:
    """Block git clean that deletes files (force without dry-run)."""
    reason = "Permanently removes untracked files"

    if _has_shell_operators(command):
        if not re.search(r"\bgit\b[^\n]*\bclean\b", command, re.IGNORECASE):
            return False, ""
        if re.search(r"(?:\s--dry-run\b|\s-[^\s\n]*n[^\s\n]*)", command, re.IGNORECASE):
            return False, ""
        if re.search(r"(?:\s--force\b|\s-[^\n]*f)", command, re.IGNORECASE):
            return True, reason
        return False, ""

    tokens = _try_shlex_split(command)
    if not tokens:
        if re.search(r"\bgit\b[^\n]*\bclean\b", command, re.IGNORECASE) and re.search(
            r"(?:\s--force\b|\s-[^\n]*f)", command, re.IGNORECASE
        ):
            if not re.search(r"(?:\s--dry-run\b|\s-[^\s\n]*n[^\s\n]*)", command, re.IGNORECASE):
                return True, reason
        return False, ""

    core = _strip_common_wrappers(tokens)
    if len(core) < 2:
        return False, ""
    if _basename(core[0]) != "git":
        return False, ""

    # Skip common git global options to find the subcommand (e.g., `git -C repo clean ...`).
    i = 1
    while i < len(core):
        t = core[i]
        if t == "--":
            i += 1
            break
        if not t.startswith("-"):
            break
        i += 1
        if t in ("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"):
            if i < len(core):
                i += 1

    if i >= len(core) or core[i] != "clean":
        return False, ""

    args = core[i + 1 :]
    has_force = False
    has_dry_run = False
    end_of_options = False

    for t in args:
        if end_of_options:
            continue
        if t == "--":
            end_of_options = True
            continue
        if t == "--dry-run" or t == "-n":
            has_dry_run = True
            continue
        if t == "--force":
            has_force = True
            continue
        if t.startswith("--"):
            continue
        if t.startswith("-") and t != "-":
            flags = t[1:]
            has_force = has_force or ("f" in flags)
            has_dry_run = has_dry_run or ("n" in flags)
            continue

    if has_force and not has_dry_run:
        return True, reason
    return False, ""


def check_destructive(command: str) -> tuple[bool, str]:
    """
    Check if command matches a destructive pattern.

    Returns:
        (is_blocked, reason) - True if command should be blocked
    """
    commands_to_check = [command]
    current = command
    for _ in range(3):
        inner = _unwrap_shell_c_command(current)
        if not inner or inner in commands_to_check:
            break
        commands_to_check.append(inner)
        current = inner

    for candidate in commands_to_check:
        blocked, reason = _check_rm_recursive_force(candidate)
        if blocked:
            return True, reason

        blocked, reason = _check_git_force_push(candidate)
        if blocked:
            return True, reason

        blocked, reason = _check_git_clean(candidate)
        if blocked:
            return True, reason

        for pattern, reason in DESTRUCTIVE_PATTERNS:
            if re.search(pattern, candidate, re.IGNORECASE):
                return True, reason
    return False, ""


def main():
    try:
        # Read hook input from stdin
        input_data = sys.stdin.read()
        if not input_data.strip():
            # No input = allow
            sys.exit(0)

        hook_input = json.loads(input_data)

        # Only check Bash tool
        tool_name = hook_input.get("tool_name", "")
        if tool_name != "Bash":
            sys.exit(0)

        # Get the command
        tool_input = hook_input.get("tool_input", {})
        command = tool_input.get("command", "")

        if not command:
            sys.exit(0)

        # Check for destructive patterns
        is_blocked, reason = check_destructive(command)

        if is_blocked:
            # Output denial in Claude Code hook format
            response = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"BLOCKED by ACFS git_safety_guard.py\n\n"
                        f"Reason: {reason}\n\n"
                        f"Command: {command}\n\n"
                        "If you really need to run this command, ask the user for explicit permission."
                    )
                }
            }
            print(json.dumps(response))
            sys.exit(0)

        # Command is allowed
        sys.exit(0)

    except json.JSONDecodeError:
        # Invalid JSON = allow (don't block on parsing errors)
        sys.exit(0)
    except Exception:
        # Any other error = allow (fail open for usability)
        sys.exit(0)


if __name__ == "__main__":
    main()
