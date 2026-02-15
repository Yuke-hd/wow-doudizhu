# Repository Guidelines

## Project Structure & Module Organization
- Root contains all addon source files for WoW:
  - `doudizhu.toc`: addon metadata and load order.
  - `Doudizhu.lua`: addon bootstrap, slash commands, lifecycle hooks.
  - `Net.lua`: addon message protocol and dispatch.
  - `Game.lua`: session state, turn logic, validation, local bot mode.
  - `UI.lua`: game window, card rendering, interaction controls.
  - `PROJECT_PLAN.md`: roadmap and implementation status.
- Keep new modules flat at root unless a clear need emerges (for example `media/` for card textures, `tests/` for future harness scripts).

## Build, Test, and Development Commands
- No build step is required; copy/update files directly in the addon folder.
- Common local workflow:
  - `git status` - check pending changes.
  - `git diff` - review edits before commit.
  - `git add . && git commit -m "..."` - record changes.
  - `git push -u origin main` - publish branch/upstream.
- In-game validation:
  - `/reload` after edits.
  - `/ddz ui` to open UI.
  - `/ddz local` to run local bot test mode.
  - `/ddz share` to verify party join link flow.

## Coding Style & Naming Conventions
- Language: Lua (WoW API). Use 4-space indentation and keep functions small.
- Naming:
  - Public addon APIs: `DDZ.Game.*`, `DDZ.UI.*`, `DDZ.Net.*`.
  - Local helpers: `local function PascalCaseOrVerbNoun()`.
  - Constants: uppercase local names (for example `PREFIX`).
- Prefer explicit state transitions and guard clauses for invalid game actions.

## Testing Guidelines
- Current testing is manual (no automated framework yet).
- Validate at minimum:
  - 3-player join/start flow.
  - Single-card play/pass turn logic.
  - Local bot mode completion.
  - UI move/persist behavior across `/reload`.
- If adding automated tests later, place them in `tests/` and name files `*_spec.lua`.

## Commit & Pull Request Guidelines
- Existing history uses short, direct messages (`initial commit`).
- Use concise imperative commits, optionally scoped:
  - `game: add pass reset logic`
  - `ui: add selectable card textures`
- PRs should include:
  - Summary of behavior changes.
  - Manual test steps executed.
  - Screenshots/GIFs for UI changes.
  - Notes on protocol/message compatibility if network behavior changed.

## Documentation Update Rule
- After implementing any feature, update both `AGENTS.md` and `PROJECT_PLAN.md` in the same branch before merge.
- `AGENTS.md` should capture contributor-facing workflow or behavior changes.
- `PROJECT_PLAN.md` should reflect implementation status (completed, in progress, or deferred) and strike through completed TODO items where applicable.

## Recent Implemented Work
- Branch: `feature/combo-validation`.
- Gameplay validation expanded from single-card only to combo-based validation:
  - `single`, `pair`, `triple`, `triple+single`, `triple+pair`
  - `straight`, `pair straight`, `plane`, `plane+single`, `plane+pair`
  - `bomb`, `rocket`, `four+two`, `four+two pairs`
- Host-side comparison rules now enforce combo type/length/count/rank checks.
- UI updated for multi-card selection:
  - Click to toggle multiple cards.
  - `Play Selected` submits all selected cards.
  - Selection line shows combo preview or invalid-combo reason.
- Slash usage updated: `/ddz play 1,2,3` for combo index play.
