# Doudizhu WoW 12.0 (Midnight) Project Plan

## Implementation Status (as of 2026-02-19)
### Done
- Repository and addon scaffold:
  - `doudizhu.toc` created for WoW 12.x.
  - Core files in place: `Doudizhu.lua`, `Net.lua`, `Game.lua`, `UI.lua`.
- Addon lifecycle and commands:
  - Slash commands: `/ddz ui`, `/ddz debug`, `/ddz create`, `/ddz join <host>`, `/ddz share`, `/ddz start`, `/ddz local`, `/ddz hand`, `/ddz play [index]`, `/ddz pass`, `/ddz state`.
- Multiplayer lobby/join (host-authoritative):
  - Host can create a lobby.
  - Clients can send join requests; host accepts/rejects.
  - Lobby sync to participants.
- Party join-link sharing:
  - `/ddz share` and UI button share clickable `[Join Doudizhu]` link in party chat.
  - If current state is `idle`, sharing auto-creates a new lobby first.
  - Click handler joins host from chat link.
- Round setup and core loop (MVP subset):
  - Deterministic shuffle and deal (54 cards, 17 each + 3 bottom).
  - Temporary landlord assignment (first seat).
  - Turn order, play/pass flow, trick reset after 2 passes.
  - Win detection when hand is empty.
- Validation (current rule subset):
  - Single-card validation only (must beat previous single unless fresh trick).
- State sync:
  - Message types implemented for lobby/state/hand/action/game start/rejections.
  - Public state sync + private hand sync.
- Addon version compatibility:
  - Strict join-time version check implemented.
  - Host rejects incompatible join requests with a clear mismatch reason.
  - Version field is now propagated in `join_accept`, `lobby_sync`, `game_start`, and `state_sync`.
- UI:
  - Main window with controls for create/join/share/start/local/play/pass.
  - Clickable card tiles, selected-card highlight, `Play Selected`.
  - Moveable frame with persisted position in `DoudizhuDB.uiPosition`.
- Local test mode:
  - `/ddz local` or UI `Local Test`.
  - Two in-process bots (`DDZ_BOT_A`, `DDZ_BOT_B`) that only play lowest valid single or pass.

### In Progress
- Multiplayer gameplay is playable as a technical MVP subset, but still missing full 斗地主 rules and bidding.
- UI has functional card interaction but not production-grade polish (animations, table visualization, richer states).

### Not Started / Deferred
- Full combo/rules engine (pairs, triples, straights, bombs, rocket, attachments).
- Proper bidding/call-rob landlord phase and landlord determination logic.
- Scoring and multipliers.
- Reconnect/rejoin recovery beyond basic sync.
- Protocol hardening (versioning, sequencing, idempotency).
- ~~Add strict addon version compatibility checks (join-time validation + clear mismatch error).~~
- Automated tests and replay tooling.

## Scope
- Build a playable in-game 斗地主 addon for WoW 12.x.
- Target: 3-player multiplayer with host-authoritative state for MVP.
- Platform constraints: Lua + WoW UI API, addon chat messaging only.

## Assumptions
- Initial release supports the English client first, then localization.
- MVP prioritizes correctness and sync over visual polish.
- Group contexts: party/raid + optional whisper fallback for invites.

## Architecture
- `Doudizhu.lua`: addon boot, slash commands, lifecycle.
- `Net.lua`: addon-message protocol, encode/decode, dispatch.
- `Game.lua`: rules engine + session/turn state machine.
- `UI.lua`: table UI, hand display, controls, status.
- Host-authoritative model:
  - Host validates legal game actions.
  - Host broadcasts deterministic state snapshots and events.
  - Clients render and submit intents only.

## Multiplayer MVP (Phase 1)
### Goals
- 3 players can complete a full round in one session using the supported MVP rule subset.
- All gameplay-critical actions are validated by host.
- Clients recover from minor packet loss via state sync.

### MVP Features
- Lobby:
  - Create room, join via whisper flow, basic 3-seat participant list.
  - Share clickable party join link.
- Dealing:
  - Deterministic deck shuffle using host seed.
  - 17 cards per player + 3 bottom cards.
- Bidding:
  - Temporary landlord assignment placeholder (first seat).
  - Full call/rob flow pending.
- Play loop:
  - Turn order and pass handling.
  - Single-card validation and beat comparison.
  - Win detection and round-end summary.
- Sync:
  - Lobby sync, state sync, and private hand sync.
  - Protocol hardening (versioning/sequence ids) pending.
- Basic UI:
  - Hand card tiles with click-to-select and play selected.
  - Core action controls (Create/Join/Share/Start/Play/Pass/Local Test).
  - ~~Add graphical card faces (BLP/TGA asset pipeline + texture mapping).~~
- Persistence:
  - UI frame position persistence implemented.

### MVP Deliverables
- `v0.1.0-alpha`: local simulation + protocol smoke tests.
- `v0.2.0-alpha`: host/client multiplayer playable round (single-card subset).
- `v0.3.0-beta`: full 斗地主 rules pass + UX stabilization + packaging.

### MVP Acceptance Criteria
- 3 players can create/join/start and finish rounds in current rule subset without blocking errors.
- Invalid single-card actions are rejected consistently across clients.
- Local bot mode can complete rounds without network dependencies.

## Advanced Features (Phase 2+)
- Gameplay extensions:
  - Full scoring system, multipliers, bombs/spring logic display.
  - Configurable rule variants.
- Social and QoL:
  - Friend/guild invite flow, quick rematch, spectator mode.
  - Reconnect support after disconnect.
- UX upgrades:
  - Drag-select cards, combo suggestions, keyboard shortcuts.
  - ~~Add graphical card faces and fallback behavior when textures are missing.~~
  - Better animations, audio cues, and end-of-round timeline.
- AI and solo:
  - Bot backfill for missing players.
  - Offline training mode vs 2 bots.
- Competitive and analytics:
  - Session history, stats, ELO-like internal ranking.
  - Anti-cheat telemetry (timing/anomaly checks on host).
- Localization:
  - zhCN/zhTW/enUS string tables.

## Technical Work Breakdown
## 1. Rules Engine
- Define card representation and sort ordering.
- Implement combo parser and classifier.
- Extend `canBeat(lastPlay, nextPlay, context)` from single-card to full rules with tests.

## 2. Network Protocol
- Existing schema implemented for join/lobby/start/play/pass/state/hand sync.
- Add protocol version and feature flags.
- Add idempotency keys and sequence numbers.

## 3. Session State Machine
- Current effective states: `IDLE -> LOBBY -> PLAY -> ENDED`.
- Target states: `IDLE -> LOBBY -> DEAL -> BID -> PLAY -> ROUND_END`.
- Enforce legal transitions; reject out-of-state messages.

## 4. UI Layer
- Lobby controls, clickable hand-card widgets, and action controls implemented.
- Add seat frames, timers, trick history, and interaction locks by phase.

## 5. Reliability
- Heartbeat + stale host detection.
- Snapshot resync endpoint and local state checksum compare.

## 6. QA and Tooling
- Local deterministic replay logs.
- Scripted regression tests for combo classification.
- Manual 3-client test checklist per release.
- Improve `/ddz local` bot strategy to exercise combo comparison paths (pair/triple/straight/bomb) instead of single-only behavior.

## Milestones and Timeline (suggested)
- Completed:
  - Scaffold + protocol baseline.
  - Lobby/join flow and basic sync.
  - Play loop (single-card subset), clickable hand UI, local bot mode, party join links.
- Next:
  - Full bidding + full combo validation.
  - Scoring/multipliers and stronger sync/recovery.
  - Packaging and beta hardening.

## Risks and Mitigations
- Risk: addon message size/rate limits.
- Mitigation: compact payload format + throttled sync.
- Risk: desync from race conditions.
- Mitigation: host-authoritative model + sequence enforcement.
- Risk: UI complexity delaying MVP.
- Mitigation: keep MVP visuals minimal, upgrade in Phase 2.

## Definition of Done (MVP)
- Installable addon with `.toc` for WoW 12.x.
- Multiplayer 3-player round is fully playable for the full 斗地主 rule set.
- No blocking errors in common flow (create, join, play, finish, rematch).
