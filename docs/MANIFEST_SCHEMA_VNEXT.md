# ACFS Manifest Schema vNext Reference

Internal maintainer reference for the manifest-driven installer system.

**Version:** 2.0.0
**Bead:** mjt.3.6
**Last Updated:** 2025-12-21

## Overview

The ACFS manifest (`acfs.manifest.yaml`) is the single source of truth for all tools installed by the Agentic Coding Flywheel Setup. This document describes the schema vNext fields, validation rules, and maintainer workflows.

## Manifest Structure

```yaml
version: 2                # Schema version
name: agentic_coding_flywheel_setup
id: acfs                  # Short identifier (lowercase alphanumeric + underscores)

defaults:
  user: ubuntu            # Target user for installation
  workspace_root: /data/projects
  mode: vibe              # Installation mode (vibe|safe)

modules:
  - id: shell.zsh
    description: ...
    # ... module fields
```

## Module Fields Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier. Format: `category.name` or `category.subcategory.name`. Must match `/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/` |
| `description` | string | Human-readable description (non-empty) |
| `verify` | string[] | Commands to verify installation succeeded (at least one required) |

### Execution Context Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `run_as` | enum | `target_user` | Execution context for install/verify. Options: `target_user`, `root`, `current` |
| `phase` | int | 1 | Execution phase (1-10). Lower phases run first |
| `category` | string | (none) | Category grouping for layout/display |

**run_as Values:**
- `target_user` - Run as the configured target user (defaults.user)
- `root` - Run with root privileges (sudo)
- `current` - Run as the current shell user

**Phase Guidelines:**
- Phase 1: Base apt packages
- Phase 2: User normalization
- Phase 3: Filesystem setup
- Phase 4: Shell configuration
- Phase 5: CLI tools
- Phase 6: Language runtimes + shell tools (atuin, zoxide, ast-grep)
- Phase 7: AI agents (Claude, Codex, Gemini)
- Phase 8: Cloud tools + databases (Vault, PostgreSQL, Wrangler, Supabase, Vercel)
- Phase 9: Stack tools (ntm, mcp_agent_mail, cass, etc.)
- Phase 10: ACFS utilities (onboard, doctor)

### Installation Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `install` | string[] | `[]` | Shell commands to run during installation |
| `verified_installer` | object | (none) | Reference to upstream installer with checksum verification |
| `installed_check` | object | (none) | Command to check if already installed (skip logic) |
| `generated` | bool | `true` | If false, module is orchestration-only (no bash function generated) |

**verified_installer Schema:**
```yaml
verified_installer:
  tool: bun              # Key in checksums.yaml
  runner: bash           # Executable (bash, sh)
  args: []               # Additional arguments
```

**installed_check Schema:**
```yaml
installed_check:
  run_as: target_user    # Context for the check
  command: "command -v zsh && test -f ~/.zshrc"
```

### Selection/Filtering Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `optional` | bool | `false` | If true, failures are warnings not errors |
| `enabled_by_default` | bool | `true` | If false, must be explicitly enabled |
| `dependencies` | string[] | `[]` | Module IDs this module depends on |
| `tags` | string[] | `[]` | Tags for higher-level selection (`--only agents`) |
| `aliases` | string[] | `[]` | Alternative names for this module |

**Common Tags:**
- `critical` - Required for base functionality
- `recommended` - Should install unless explicitly skipped
- `optional` - Nice to have, not required
- `orchestration` - Handled by orchestrator, not generated
- `shell-ux` - Affects shell experience
- `cli-modern` - Modern CLI tool replacements
- `cloud` - Cloud provider integrations
- `db` - Database tools

### Metadata Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `notes` | string[] | `[]` | Maintainer notes (not executed) |
| `docs_url` | string | (none) | URL to external documentation |

## Examples

### Standard Module (apt packages)

```yaml
- id: cli.modern
  description: Modern CLI tools
  category: cli
  phase: 5
  run_as: root
  optional: false
  enabled_by_default: true
  tags: [recommended, cli-modern]
  dependencies:
    - base.system
  installed_check:
    run_as: current
    command: "command -v rg && command -v fzf"
  install:
    - apt-get install -y ripgrep fzf tmux
  verify:
    - rg --version
    - fzf --version
```

### Verified Installer Module

```yaml
- id: lang.bun
  description: Bun JavaScript runtime
  category: lang
  phase: 6
  run_as: target_user
  optional: false
  enabled_by_default: true
  tags: [recommended, lang-runtime]
  dependencies:
    - base.system
  verified_installer:
    tool: bun
    runner: bash
    args: []
  installed_check:
    run_as: target_user
    command: "command -v bun"
  install: []  # Empty - handled by verified_installer
  verify:
    - bun --version
```

### Orchestration-Only Module

```yaml
- id: users.ubuntu
  description: Ensure ubuntu user exists with proper permissions
  category: users
  phase: 2
  run_as: root
  optional: false
  enabled_by_default: true
  generated: false  # No bash function generated
  tags: [orchestration, critical]
  notes:
    - "Ensure user ubuntu exists with home /home/ubuntu"
    - "Write /etc/sudoers.d/90-ubuntu-acfs for passwordless sudo"
  install: []
  verify:
    - id ubuntu
    - sudo -n true
```

### Optional Cloud Tool (Legacy Pattern)

```yaml
- id: cloud.gcloud
  description: Google Cloud CLI
  category: cloud
  phase: 8
  run_as: root
  optional: true          # Failures are warnings
  enabled_by_default: false  # Must be explicitly requested
  tags: [cloud, optional]
  dependencies:
    - base.system
  installed_check:
    run_as: current
    command: "command -v gcloud"
  install:
    # NOTE: curl|bash is a legacy pattern. New modules should use
    # verified_installer with checksums.yaml for security.
    - curl https://sdk.cloud.google.com | bash
  verify:
    - gcloud --version
```

## Validation Rules

The manifest is validated at parse time. Validation runs in order:

### 1. Schema Validation (Zod)

- All required fields must be present
- Field types must match schema
- Module IDs must match pattern: `/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/`
- Phase must be 1-10
- At least one verify command required

**Error Example:**
```
Module ID must be lowercase with dots (e.g., "shell.zsh", "lang.bun")
```

### 2. Dependency Existence

Every dependency must reference an existing module ID.

**Error Example:**
```
[MISSING_DEPENDENCY] Module "lang.bun" depends on "base.core" which does not exist
  → Check spelling or add the missing module
```

### 3. Cycle Detection

Dependencies must form a DAG (no cycles).

**Error Example:**
```
[DEPENDENCY_CYCLE] Dependency cycle detected: a → b → c → a
  → Remove one dependency to break the cycle
```

### 4. Phase Ordering

Dependencies must be in the same or earlier phase.

**Error Example:**
```
[PHASE_VIOLATION] Module "shell.zsh" (phase 4) depends on "agents.claude" (phase 7)
  → Move dependency to earlier phase or move module to later phase
```

### 5. Function Name Uniqueness

Generated function names must be unique. IDs `lang.bun` and `lang_bun` both generate `install_lang_bun`.

**Error Example:**
```
[FUNCTION_NAME_COLLISION] Module "lang_bun" generates function "install_lang_bun"
which collides with "lang.bun"
  → Rename one of the colliding modules to use a different ID
```

### 6. Reserved Names

Generated functions must not shadow orchestrator functions.

**Reserved Names:**
- `install_all`, `install_base`, `install_lang`, `install_tools`, etc.
- `log_step`, `log_error`, `log_success`, etc.
- `acfs_require_contract`, `acfs_security_init`
- Shell builtins: `main`, `usage`, `init`, `run`, `exec`, `exit`, `test`

**Error Example:**
```
[RESERVED_NAME_COLLISION] Module "all" generates function "install_all"
which is a reserved orchestrator name
  → Rename the module to avoid the reserved function name
```

## Maintainer Workflows

### Adding a New Module

1. **Choose ID**: Use `category.name` format (e.g., `tools.lazygit`)
2. **Set Phase**: Match dependency phase requirements
3. **Define Dependencies**: List module IDs this depends on
4. **Add installed_check**: For idempotent skip-if-present logic
5. **Add install Commands**: Or use verified_installer for upstream scripts
6. **Add verify Commands**: At least one required
7. **Validate**: Run the generator in dry-run mode to check for errors
8. **Regenerate**: Run the generator to update bash scripts

```bash
# Validate manifest (dry-run shows errors without writing files)
cd packages/manifest && bun run generate:dry

# Generate bash scripts
cd packages/manifest && bun run generate
```

### Modifying an Existing Module

1. **Check Dependents**: Find modules that depend on this one
2. **Update Carefully**: Changes affect generation output
3. **Validate**: Ensure no phase/dependency violations introduced
4. **Regenerate**: Update generated scripts

```bash
# Find modules that depend on a specific module (e.g., lang.bun)
grep -B15 -- "- lang.bun" acfs.manifest.yaml | grep "^  - id:"
```

### Debugging Validation Errors

```bash
cd packages/manifest

# Dry-run: validates manifest and shows what would be generated (no file writes)
bun run generate:dry

# Full generation: validates and writes files to scripts/generated/
bun run generate
```

## Generated Output

The generator produces:
- `scripts/generated/install_<category>.sh` - Category-based install scripts (e.g., `install_lang.sh`, `install_cli.sh`)
- `scripts/generated/install_all.sh` - Orchestrator that calls category scripts in phase order
- `scripts/generated/manifest_index.sh` - Module metadata for runtime queries
- `scripts/generated/doctor_checks.sh` - Health check functions

### Function Naming

Module ID `lang.bun` generates:
- Function: `install_lang_bun()`
- Location: Inside `scripts/generated/install_lang.sh` (grouped by category)

### Execution Model

```bash
# Generated orchestrator pseudocode
install_all() {
  # Phase 1
  install_base_system || handle_error

  # Phase 2
  install_users_ubuntu || handle_error

  # ... continues by phase
}
```

## File Locations

| Path | Description |
|------|-------------|
| `acfs.manifest.yaml` | Source of truth manifest |
| `packages/manifest/src/schema.ts` | Zod schema definitions |
| `packages/manifest/src/types.ts` | TypeScript type definitions |
| `packages/manifest/src/validate.ts` | Validation logic |
| `packages/manifest/src/generate.ts` | Bash script generator |
| `scripts/generated/` | Generated bash scripts (committed to git) |
| `checksums.yaml` | Verified installer checksums |

## Related Beads

- `mjt.3.1` - Implement schema vNext fields (Zod + TS types)
- `mjt.3.2` - Add manifest validation (deps, cycles, phases)
- `mjt.3.3` - Add function name collision + reserved-name validation
- `mjt.3.4` - Migrate acfs.manifest.yaml to schema vNext
- `mjt.3.5` - Migrate remote installers to verified_installer
- `mjt.3.6` - Document schema vNext (this document)
