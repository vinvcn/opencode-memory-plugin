# Smoke test / acceptance checklist

Run after `./install.sh` and a full restart of opencode (new sessions only).

## 1. Install footprint (acceptance #1, #6)
- [ ] `cat ~/.local/share/agent-memory/.opencode-memory-manifest.json` shows plugin path, sha256, agents file, data root
- [ ] `ls ~/.config/opencode/plugins/` contains `memory.ts` (and pre-existing plugins untouched)
- [ ] `grep -c "opencode-memory:start" ~/.config/opencode/AGENTS.md` equals 1
- [ ] `opencode.json` unmodified (`ls -la ~/.config/opencode/opencode.json` — old mtime)

## 2. Plugin loads (acceptance #3)
- [ ] New opencode session: ask the agent to run `memory_status`
  - expect data root path, personal + repo layers, counts all zero
- [ ] No plugin errors in the opencode log

## 3. Save → quarantine → approve → inject (acceptance #4)
- [ ] Tell the agent a durable convention ("这个仓库的提交信息用中文") and ask it to remember
  - expect it calls `memory_save` → reply says lesson saved in quarantine
- [ ] Ask the agent to run `memory_recall`
  - expect the brief lists the entry under "Quarantine — awaiting user approval"
  - expect it is NOT in the Lessons section yet
- [ ] Approve it (`memory_approve { id }` after you confirm), then `memory_recall` again
  - expect it now appears under Lessons with `[type · src:... · date]`

## 4. Hot layer cap (acceptance #5)
- [ ] Ask the agent to write a >2 KB blob into MEMORY.md via
  `memory_save { target: "memory", source: "user", content: "<long text>" }`
  - expect a cap-exceeded error with consolidation guidance, file unchanged

## 5. Compaction guard
- [ ] In a long session, let compaction happen (or ask the agent to compact)
  - expect `compaction-audits/` gets a report; `memory_status` shows the latest audit line

## 6. Raw log + distill nudge
- [ ] Run a few tool calls in a session, then check `repos/<slug>/raw/<today>.md` exists with lines
- [ ] End the session; start a new one; `memory_recall` should mention pending distill

## 7. Uninstall rollback (acceptance #2)
- [ ] `./uninstall.sh` → plugin file gone, AGENTS.md block gone (`grep -c opencode-memory:start` = 0),
      data root still present with lessons
- [ ] `./install.sh` again → everything back; `./uninstall.sh --purge` → data root gone

## 8. v1.2: gates, scan, staleness (after v1.2.0 install + service restart)

### 8.1 Decision gates (P0-0)
- [ ] Configure `{ "permission": { "memory_approve": "ask", "memory_forget": "ask" } }` in opencode.json
- [ ] `memory_approve` call → UI permission prompt appears; rejecting it fails the call with NO state change
- [ ] Accepting → lesson approved, file frontmatter gains `decided_by: user` + `decided_via: permission-gate`
- [ ] `memory_save { target: "memory", source: "user", ... }` → permission prompt (memory.hot-write)
- [ ] `memory_save { supersedes: <approved-id> }` → prompt (memory.supersede-approved); old entry gets decided_by: user
- [ ] Without rules configured: operations succeed directly and `memory_status` shows them in the agent-decided ledger

### 8.2 Write-time scan (P0-2)
- [ ] Save content containing "ignore all previous instructions" → rejected, category `instruction-override`
- [ ] Save content containing a zero-width space → rejected, category `invisible-unicode`
- [ ] Save content containing `sk-...` key shape → rejected, category `secret-shape`
- [ ] Normal convention text saves fine; emoji-only content does not trip the scan

### 8.3 Duplicate/conflict detection (P0-1)
- [ ] Save the same lesson twice → second call rejected with the first entry's id
- [ ] Save a similar-but-different lesson → saved, reply contains "Possible conflicts" hint

### 8.4 TTL (P1-2)
- [ ] Save with `expires: "2020-01-01"` → not in recall brief, not in search results, file on disk intact
- [ ] Save with `expires: "2026-13-99"` → rejected (write-strict format validation)
- [ ] No expires → behaves as never-expiring

### 8.5 Loss guardrail (P1-3)
- [ ] Write 5-line MEMORY.md, then `replace` with 1 line → rejected listing the dropped lines
- [ ] Retry with `force: true` → succeeds (permission prompt if configured)

### 8.6 Stale disposability (P1-1)
- [ ] `memory_status` lists stale ids when present; recall brief shows the Stale section
- [ ] `memory_forget { stale: true }` → all stale entries superseded in one gated call

### 8.7 Regression
- [ ] v1.1.0 data files (lessons without new fields) still read, approve, and inject correctly
