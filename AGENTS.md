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
  - Join-time version compatibility rejection path (mismatched host/client versions).
  - Single-card play/pass turn logic.
  - Local bot mode completion.
  - UI move/persist behavior across `/reload`.
- If adding automated tests later, place them in `tests/` and name files `*_spec.lua`.

## Commit & Pull Request Guidelines
- Existing history uses short, direct messages (`initial commit`).
- Use concise imperative commits, optionally scoped:
  - `game: add pass reset logic`
  - `ui: add selectable card textures`
- Don't commit directly to `main` branch
- Branch name should follow `<branch type>/<branch name>`, eg:
  - `feature/combo-validation`
  - `bugfix/fix-game-logic`
- PRs should include:
  - Summary of behavior changes.
  - Notes on protocol/message compatibility if network behavior changed.
- When asked to raise a PR for the current branch changes:
  - Update local `main` first.
  - Rebase the current branch onto `main`.
  - Open the PR with both title and description written in Chinese.

## Documentation Update Rule
- After implementing any feature, update both `AGENTS.md` and `PROJECT_PLAN.md` in the same branch before merge.
- `AGENTS.md` should capture contributor-facing workflow or behavior changes.
- `PROJECT_PLAN.md` should be maintained as a checkbox-based feature list using Markdown checkboxes (`- [x]` and `- [ ]`).
- Do not rewrite or replace existing feature-list entries in `PROJECT_PLAN.md` unless explicitly asked.
- When a listed roadmap item is implemented, check it off and add a new follow-up item for remaining scope instead of mutating the original item into a different requirement.
- Do not reintroduce status buckets such as `In Progress` or `Not Started / Deferred` unless explicitly requested.
- Do not reintroduce outdated stage wording such as `MVP` unless explicitly requested.

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
- UI now shows a dedicated `Last Played` section above `My Hand`:
  - Displays synced recent plays for all three players, not just the current trick leader.
  - Recent plays are rendered as compact card tiles, and the hand area is positioned lower to keep the section readable.
  - Recent-play names use class color when roster class data is available; bots stay on the default color.
  - The active player row shows `<`, and the landlord row shows a red `$`, in the recent-play section.
  - Recent-play rows keep a fixed single-line height, with the name and row markers vertically centered.
  - Shared card labels use suit symbols (`♠`, `♣`, `♥`, `♦`) instead of letter suits.
- Lobby sync now clears stale `lastPlay` and `recentPlays` state when entering a new lobby or bidding flow.
- Slash usage updated: `/ddz play 1,2,3` for combo index play.
- Roadmap note added: expand `/ddz local` bot behavior to cover combo-type comparison paths (not only singles).
- Strict addon version compatibility check added at join-time:
  - Client includes `version` in `join_request`.
  - Host rejects missing/mismatched versions with explicit reason.
  - Host sync messages now include `version` (`join_accept`, `lobby_sync`, `game_start`, `state_sync`).
