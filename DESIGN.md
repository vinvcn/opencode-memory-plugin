# opencode-memory — design decisions

Version 1.0.0 · 2026-10-29 · research backing: `~/Documents/Last30Days/pluggable-agent-memory-for-opencode-raw-v3.md`

## The five-step loop this implements

1. **Capture** — `tool.execute.after` appends a capped, append-only line per tool
   call into `raw/YYYY-MM-DD.md` (skips the plugin's own tools; 256 KB/day cap).
2. **Distill** — the agent itself distills raw activity into typed lessons via
   `memory_save` before ending a session. A pending-distill marker (written at
   `session.idle`) plus the AGENTS.md contract surfaces the nudge. v1 deliberately
   avoids a background LLM: distillation runs on the session's own model.
3. **Inject** — pull model: the managed AGENTS.md block + tool descriptions make
   the agent call `memory_recall` at task start. The brief carries provenance
   labels and is framed as EXTERNAL MATERIAL.
4. **Prune** — supersede chains (new knowledge links to the old entry, nothing
   silently deleted), 30-day decay for low-hit approved lessons, 2 KB hard cap
   on MEMORY.md with fail-loud overflow (forces consolidation, Hermes-verified
   pattern: `~/.hermes/memories/MEMORY.md` caps at 2,200 chars).
5. **Approve** — quarantine by default; approval is a user decision surfaced in
   the recall brief (≤3 at a time). Nothing unapproved is ever injected.

## Why these mechanisms (OpenCode v2.0.21 API reality)

- **Pull injection, not push.** The v2.0.21 plugin API exposes no system-prompt
  hook. Passive injection is therefore implemented as a marker-delimited managed
  block in `~/.config/opencode/AGENTS.md` (installed/removed by the scripts,
  recorded in the manifest). This deviates from the original "touch nothing but
  the plugin" plan; the block is visible, delimited, and exactly removable.
- **Compaction defense is two-sided.**
  - *Prevention*: `experimental.session.compacting` pushes provenance rules into
    the compaction context (reduce, not fix — prompt rules cannot restore
    provenance that flattening destroyed, arXiv 2610.29869 E3).
  - *Detection*: on `session.compacted`, the plugin fetches session messages via
    the SDK client, extracts genuine user turns, and runs a light
    provenance-contrast check on the latest assistant message
    (approval-attributing sentences must be grounded by a 10-char normalized
    window in real user turns). Findings land in `compaction-audits/` and are
    surfaced in the next recall brief. This mirrors the paper's E9 defense
    (77% catch / 2% collateral at full strength) in deliberately weaker,
    honest-heuristic form.
- **E16-informed contract**: the audit report and the injection brief tell the
  agent that its own voiced verification/refusal reasoning is the most
  forgery-resistant content — encourage voicing it.

## Threat model this design accepts and mitigates

| Threat | Mitigation |
|---|---|
| Laundered approval survives compaction as user voice | compaction prompt rules + post-compaction audit + injection framing ("verify approvals against the real conversation") |
| Tool/web output poisoned into hot memory | `memory_save target:"memory"` requires `source:"user"`; unconfirmed observations must go through quarantine lessons |
| Memory bloat / stale facts steering sessions | 2 KB hot-layer cap (fail-loud), supersede chains, 30-day low-hit decay |
| Over-trusting recalled content | provenance labels on every lesson; recall brief states it is not user voice |
| Secrets in persistent files | AGENTS.md contract forbids it; raw log is local-only and capped |

## V2 port (v1.1.0, 2026-10-29)

OpenCode v2.0.21 rejects the V1 plugin shape (`SchemaError(Missing key at ["default"])` in
`~/.local/share/opencode/log/opencode.log`); the plugin is rewritten on `@opencode/plugin`
(V2 SDK, auto-installed by install.sh, npmmirror fallback when the default registry is
unreachable). Mapping and upgrades over the V1 build:

| Concern | V1 (v1.0.0) | V2 (v1.1.0) |
|---|---|---|
| Entrypoint | `export const MemoryPlugin = async (ctx) => hooks` | `export default Plugin.define({ id, setup })` |
| Passive injection | managed AGENTS.md block + pull via `memory_recall` | **`ctx.session.hook("context")` → `event.system.push`** (real system-injection channel; rules + compact brief ≤3600 chars on every agent-loop call) |
| Compaction guard | `experimental.session.compacting` + post-hoc fetch | `ctx.session.hook("compaction")`: `event.messages` IS the transcript (audit needs no fetch) + best-effort `event.system` push |
| Raw logging | `tool.execute.after` V1 hook | `ctx.tool.hook("execute.after")` (`event.tool/status/result`) |
| Idle marker | V1 event bus | `ctx.event.subscribe({ types: ["session.idle"] })` + AbortController cleanup |
| Tool input | zod-style `tool.schema` | JSON Schema objects, execute returns `{ content }` |
| Session → project directory | hook context carried it | `ctx.session.get({sessionID})` → defensive `directory ?? worktree ?? project.*` extraction, cached per session, last-known fallback |
| Logging | `client.app.log` | `console.log/error` (no app.log in V2 ctx docs) |

The managed AGENTS.md block remains but its role changed: it is the standing *contract*
(memory is auto-injected; verify approvals; distill before ending), not the injection channel.
Passive injection now comes from the `context` hook — this closes the biggest V1 deviation.
Known limits: `session.idle` event type name is assumed (unknown types are ignored with a
server-log warning); `SessionInfo.directory` is read defensively across shape variants.

## Data model

```
$AGENT_MEMORY_HOME (~/.local/share/agent-memory)
├── personal/                    cross-project layer
│   ├── MEMORY.md                user-curated hot layer (≤2048 B, fail-loud)
│   ├── lessons/*.md             frontmatter-typed entries
│   ├── raw/YYYY-MM-DD.md        append-only tool activity log
│   └── compaction-audits/       audit reports
└── repos/<basename>-<hash8>/    per-project layer (same structure)
```

Lesson frontmatter: `id, type (convention|decision|dead-end|preference|fact),
source (user|agent|tool:<name>), date, confidence, status
(quarantine|approved|superseded), supersedes, superseded_reason, hits, last_hit,
title`.

## Upgrade path — Hindsight (trigger: cross-harness use, >100 lessons needing
semantic retrieval, or distill quality below bar)

Frontmatter maps 1:1 onto Hindsight bank items:

| opencode-memory | Hindsight |
|---|---|
| lesson body | memory text |
| `source` | provenance/observation source |
| `date` | timestamp |
| `type` | memory kind/tag |
| `status=approved` | only these are exported |
| `personal/` vs `repos/<slug>/` | bank `personal` vs bank `repo-<slug>` |

Export: `cat $AGENT_MEMORY_HOME/{personal,repos/*/}/lessons/*.md`, then
`hindsight.retain(bank, text)` per approved lesson. Uninstall first or run both
side by side (Hindsight's one-install wires opencode independently).

## Non-goals (v1)

- No vector/semantic search (keyword only), no background distillation LLM,
  no sync across machines, no multi-user isolation.
