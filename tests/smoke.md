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
