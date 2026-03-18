# Doudizhu WoW 12.0 (Midnight) Project Plan

## Current State (as of 2026-03-18)
- The addon supports host-authoritative 3-player sessions with lobby creation, join flow, state sync, basic bidding, and a playable single-card round loop.
- Local test mode works with two in-process bots. Bots auto-bid and auto-play simple single-card turns; the player still bids and plays manually.
- Core UX is functional, but full 斗地主 rules, scoring, stronger recovery, and richer presentation are still pending.

## Scope
- Build a playable in-game 斗地主 addon for WoW 12.x.
- Target: 3-player multiplayer with a host-authoritative game flow.
- Platform constraints: Lua + WoW UI API, addon chat messaging only.

## Architecture
- `Doudizhu.lua`: addon boot, slash commands, lifecycle.
- `Net.lua`: addon-message protocol, encode/decode, dispatch.
- `Game.lua`: rules engine + session/turn state machine.
- `UI.lua`: table UI, hand display, controls, status.
- Host-authoritative model:
  - Host validates legal game actions.
  - Host broadcasts deterministic state snapshots and events.
  - Clients render and submit intents only.

## Feature List
- [x] Repository scaffold and addon load setup
  - `doudizhu.toc` created for WoW 12.x.
  - Core files in place: `Doudizhu.lua`, `Net.lua`, `Game.lua`, `UI.lua`.

- [x] Slash commands and addon lifecycle
  - Commands available: `/ddz ui`, `/ddz debug`, `/ddz create`, `/ddz join <host>`, `/ddz share`, `/ddz start`, `/ddz local`, `/ddz hand`, `/ddz bid <0-3>`, `/ddz play [index]`, `/ddz pass`, `/ddz state`.

- [x] Multiplayer lobby and join flow
  - Host can create a lobby.
  - Clients can join through whisper flow or party join link.
  - Lobby sync is broadcast to participants.

- [x] Party join-link sharing
  - `/ddz share` and the UI button publish a clickable `[Join Doudizhu]` link.
  - Sharing auto-creates a lobby when the addon is idle.
  - Chat link click handling joins the advertised host.

- [x] Deal and session bootstrapping
  - Deterministic 54-card shuffle.
  - 17 cards per player plus 3 bottom cards.
  - Host distributes public state and private hands.

- [x] Basic bidding
  - Host-authoritative `bid` phase implemented.
  - Players can bid `0-3`.
  - Highest bid determines landlord.
  - Bottom cards are assigned after bidding resolves.
  - If all players pass, the round redeals and bidding restarts.

- [ ] Rob-landlord flow
  - Add rob-landlord phase/rules as a separate feature beyond the current simple bidding flow.
  - Decide final state transitions and UX for rob/counter-rob behavior.

- [x] Basic play loop
  - Turn order, pass handling, and trick reset after two passes.
  - Win detection when a hand reaches zero cards.

- [x] Current validation subset
  - Single-card validation only.
  - A played single must beat the previous single unless starting a fresh trick.

- [ ] Full combo and comparison engine
  - Pairs, triples, straights, bombs, rocket, planes, and attachments.
  - Full comparison logic and regression coverage for all supported combos.

- [ ] Scoring and multipliers
  - Landlord/farmer scoring resolution.
  - Multipliers, bombs, rocket, spring, and round-end summary details.

- [x] State sync and message handling
  - Implemented: lobby, start, bid, play, pass, hand sync, state sync, rejects.
  - Public state sync plus private hand sync are in place.

- [ ] Protocol hardening
  - Feature flags, versioned protocol evolution, sequence numbers, idempotency, and stronger replay safety.

- [x] Version compatibility check
  - Join-time addon version validation is enforced.
  - Host rejects mismatched or missing versions with explicit reasons.
  - Version fields propagate through `join_accept`, `lobby_sync`, `game_start`, and `state_sync`.

- [x] Functional game UI
  - Controls for create, join, share, start, local test, bid, play, and pass.
  - Clickable hand cards and selected-card submission.
  - Movable frame with saved position in `DoudizhuDB.uiPosition`.
  - Dynamic layout adjustments reduce overlap between status/info, hand, and bottom controls.

- [x] Show last played cards in the UI
  - Add a dedicated UI area for the most recent play.
  - Show player name, cards played, and relevant combo summary.

- [x] Render recent plays as card tiles for all three players
  - Track each player's most recent actual play in synced game state.
  - Display those plays in the UI with compact card visuals above the hand area.

- [x] Add player identity cues to the recent-play rows
  - Show player names in class color when the addon can resolve roster class data.
  - Mark the active turn with `<` and the landlord with a red `$` directly in the recent-play section.

- [x] Stabilize recent-play row layout
  - Keep each recent-play row at a fixed single-line height so the hand area does not jump.
  - Vertically center the player name and row markers within that fixed lane.

- [ ] Handle long recent-play combos without clipping
  - Wrap, compress, or truncate long straights and other large combos so the full play remains understandable.
  - Keep the recent-play rows readable within the current frame width.

- [x] Use suit symbols in card labels
  - Render suits as `♠`, `♣`, `♥`, and `♦` in shared card text formatting.
  - Keep existing red/black coloring for heart and diamond cards.

- [x] Document PR workflow expectations
  - When asked to raise a PR, update local `main` first and rebase the working branch onto `main`.
  - Write both the PR title and description in Chinese.

- [x] Add GitHub Actions Lua syntax CI
  - Run on `push` and `pull_request`.
  - Validate all repository `*.lua` files with Lua 5.1 `loadfile`.

- [ ] Expand CI beyond syntax-only validation
  - Add automated regression checks for combo classification/comparison once a test harness exists.
  - Consider validating `.toc` consistency and addon version metadata in CI.

- [x] Add a Chinese README for players and contributors
  - Document installation, slash commands, multiplayer flow, local bot mode, and current feature scope.

- [ ] Expand README troubleshooting and UI screenshot coverage
  - Add common multiplayer failure cases, version-mismatch troubleshooting, and curated screenshots/GIFs for key flows.

- [ ] Show a short multi-turn trick history in the UI
  - Preserve the most recent plays and passes instead of only the latest play.
  - Keep the history compact so it does not crowd the hand and action controls.

- [ ] Richer table UI
  - Seat frames, timers, trick history, stronger phase-specific interaction locks, and better table presentation.

- [x] Local bot test mode
  - `/ddz local` starts a player-plus-two-bot session.
  - Bots auto-bid.
  - Bots currently play the lowest valid single or pass.

- [ ] Stronger bot behavior
  - Extend `/ddz local` bot logic to exercise pair/triple/straight/bomb paths after full combo support lands.
  - Improve bidding heuristics once the full ruleset is in place.

- [ ] Reconnect and recovery
  - Rejoin after disconnect.
  - Snapshot resync and stronger recovery from minor desyncs.

- [ ] Automated tests and tooling
  - Regression tests for combo classification and comparison.
  - Replay tooling and deterministic debug logs.

- [ ] Polish and platform extras
  - Friend/guild invite flow, rematch flow, spectator support.
  - Better animations, audio cues, and end-of-round presentation.
  - Localization support (`zhCN`, `zhTW`, `enUS`).

## Manual Validation Checklist
- 3-player create/join/start flow.
- Join-time version compatibility rejection path.
- Bidding flow, landlord determination, and bottom-card assignment.
- Single-card play/pass turn logic.
- Local bot mode completion.
- UI move/persist behavior across `/reload`.

## Risks and Mitigations
- Risk: addon message size/rate limits.
- Mitigation: compact payload format + throttled sync.
- Risk: desync from race conditions.
- Mitigation: host-authoritative model + stronger sequence enforcement.
- Risk: UI complexity delaying gameplay work.
- Mitigation: keep the table UX incremental and prioritize rules/sync correctness first.
