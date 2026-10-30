# opencode-memory

Long-term, self-evolving memory for [OpenCode](https://opencode.ai) agents
(v2.x, V2 plugin API). Pure local files, zero external services, one install
script to manage everything.

The agent remembers across sessions through three layers: a user-curated hot
file (`MEMORY.md`, hard-capped), typed lessons with provenance (`lessons/*.md`,
quarantine → approval → injected), and an append-only raw activity log. A
distill loop turns raw session activity into lessons; an approval gate keeps
unconfirmed observations out of future sessions; supersede chains handle
outdated facts; and every compaction summary is audited against real user
turns (provenance guard, inspired by arXiv 2610.29869).

## Install

```bash
cd ~/projects/opencode-memory
./install.sh                 # global: plugin + AGENTS.md block + data root
./install.sh --link          # live-edit mode (plugin symlinks back to src/)
./install.sh --project .     # additionally install into one project
./install.sh --data-dir /path  # custom data root
```

Installed footprint (all recorded in a manifest for exact rollback):

| Item | Path |
|---|---|
| Plugin | `~/.config/opencode/plugins/memory.ts` |
| V2 plugin SDK | `~/.config/opencode/node_modules/@opencode/plugin` (npm, npmmirror fallback) |
| Standing instructions | `~/.config/opencode/AGENTS.md` (marker-delimited block) |
| Data root | `~/.local/share/agent-memory/` (+ manifest inside) |
| Data-root pointer | only with `--data-dir` |

`opencode.json` is never touched. Restart opencode so new sessions load the plugin.

## Uninstall

```bash
./uninstall.sh          # removes plugin + managed block; KEEPS your memory data
./uninstall.sh --purge  # also deletes the data root
```

## Use

In any opencode session:

- `memory_recall` — load curated memory for this scope (call once at task start;
  the AGENTS.md contract asks the agent to do this automatically)
- `memory_save` — persist a lesson (lands in quarantine) or update `MEMORY.md`
  (requires `source: "user"` — only user-confirmed conventions go there)
- `memory_approve` — approve quarantine entries after the user confirms
- `memory_forget` — retire a lesson (superseded, chain kept)
- `memory_search` — keyword search across lessons
- `memory_status` — counts, quarantine queue, compaction audit findings

Self-evolution loop: raw session activity is logged → the agent distills durable
lessons before ending a session → entries wait in quarantine → you approve →
approved lessons are injected into future sessions (with provenance labels) →
hits/decay statistics retire what stops being useful.

## Layout

```
src/memory.ts    the whole plugin (hooks + tools + distill contract)
install.sh       manages the install footprint, idempotent
uninstall.sh     exact rollback from the manifest
tests/smoke.md   manual acceptance checklist
DESIGN.md        decisions, threat model, upgrade path (Hindsight)
```

## FAQ

**Where is my memory?** `$AGENT_MEMORY_HOME` or `~/.local/share/agent-memory/`
(`personal/` for cross-project preferences, `repos/<slug>/` per project).
Plain Markdown — you can read and edit everything.

**Does it phone home?** No. No network calls, no telemetry, no LLM keys. The
only model usage is your own session's model doing distillation via the tools.

**How do I migrate to Hindsight later?** Lesson frontmatter maps 1:1 to
Hindsight bank items (see DESIGN.md). Export is `cat repos/*/lessons/*.md`.
