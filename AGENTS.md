# AGENTS.md

Roblox game built with **Rojo 7.7.0** (managed by Rokit). Luau only. No npm/package manager, no
test runner, no lint/formatter/CI config in this repo.

## Commands
- `rojo serve` — sync `src/` into the already-open Studio place. This is the normal dev loop; Studio
  is usually already connected (a `__Rojo_SessionLock` exists in ServerStorage). Files sync live.
- `rojo build -o "Brainrot_RNG.rbxlx"` — build a place from scratch (see warning below).
- `rokit install` — install the pinned `rojo` toolchain if missing.

## Critical: the repo only covers part of the place
`default.project.json` maps only three paths:
- `src/shared`   -> `ReplicatedStorage.Shared` (ModuleScripts)
- `src/client`   -> `ReplicatedStorage.Client` (one `Script`, `RunContext = Client`)
- `src/server`   -> `ServerStorage.Server` (one `Script`, `RunContext = Server`)

Everything else exists **only in the Studio place file** (`.rbxlx` is gitignored) and is NOT in `src`:
`ReplicatedStorage.Datas`, `ReplicatedStorage.Remote` (all RemoteEvents), `ReplicatedStorage.Assets`
(UI/part/sound templates), `ReplicatedStorage.TopBar`, `ReplicatedStorage.QuickZone`, and all
Workspace/ServerStorage world content.

Consequences:
- You cannot find or edit `Datas`, `Remote`, or asset templates in `src`. Create/edit those with the
  Studio MCP tools, not via Rojo.
- `rojo build` alone produces a non-functional place. Do not rebuild from scratch; serve against the
  existing place.

## Module system (unusual — read before adding modules)
`src/server/init.server.luau` and `src/client/init.server.luau` are identical bootstraps. Each
`require`s every ModuleScript under its own tree plus `ReplicatedStorage.Shared`, stores it in the
global `shared` table keyed by the module **filename**, then calls `init()` on every module, then
`task.defer(start())` on every module.

- Access any module as `shared.<Name>` (`shared.Config`, `shared.Event`, `shared.DataStore`). No
  `require` for repo modules.
- Names must be unique per side (client = client tree + Shared; server = server tree + Shared).
  Duplicate filenames silently overwrite — there are existing benign collisions (`Object`, `Class`).
- `init()` runs for all modules before any `start()`; order is nondeterministic (`pairs`). Put
  cross-module wiring in `init`, runtime hooks in `start`, and never assume another module's `init`
  ran first.
- Module template: `local self = {}` + `function self.init()` + `function self.start()` +
  `return self`; publish API by assigning `self.<fn>`. Several files are placeholder no-ops.
- Third-party libs (`QuickZone`, `TopBar`, `DialogModule`) and `ReplicatedStorage.Datas.*` are
  required directly by path, not through `shared`.
- Client mirrors server state: server pushes full player data over `ReplicatedStorage.Remote.SetPlayerData`;
  the client caches it in `shared.PlayerDataHandler` and UI modules read from there.

## Development Rules
- Before modifying non-trivial code, read the relevant existing code and understand its callers and dependencies.
- Prefer the smallest change that solves the requested problem. Do not rewrite, refactor, or "clean up" unrelated code unless explicitly requested.
- Reuse existing systems and utilities when possible. Do not introduce a new abstraction or parallel system without a clear reason.
- Do not inspect, modify, or test Studio content unless I explicitly ask you to do so. If Studio access is necessary to complete the task, ask me first.

## Verification
- No automated tests. Normally verify changes by inspecting the code. Only use Studio playtesting (`start_stop_play`) or Studio Output (`get_console_output`) when I explicitly request Studio testing. Structural changes (new/renamed modules or remotes) may need a playtest restart; plain code edits sync live via `rojo serve`.
- Some comments are in Chinese; no formatter is enforced — match surrounding style.
