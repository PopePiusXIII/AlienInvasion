# Luau Linter and Rojo Sourcemaps

This repository uses `JohnnyMorganz.luau-lsp` for Luau diagnostics. The language server resolves Roblox-style imports through a Rojo sourcemap.

For example, this import only type-checks when the sourcemap maps `ReplicatedStorage.Shared.GunCore` to a real local file:

```luau
local GunCore = require(game:GetService("ReplicatedStorage").Shared.GunCore)
```

## How the mapping works

A Rojo project defines the Roblox DataModel tree and maps an Instance to a local file with `$path`.

```json
"GunCore": { "$path": "GunCore.luau" }
```

Running this command generates the map used by the language server:

```bash
rojo sourcemap default.project.json --output sourcemap.json
```

`luau-lsp` reports `Unknown require` when the map points at a missing file, a stale map is loaded, or the project path is based on the wrong directory.

## Workspace-folder rule

A `$path` is always relative to the directory containing that project file.

There are two valid project-file locations in this repository:

| Project file location | Correct example for `GunCore` |
| --- | --- |
| Repository root | `"$path": "src/common/GunCore.luau"` |
| `src/place_match` | `"$path": "../common/GunCore.luau"` |
| `src/place_lobby` | `"$path": "../common/GunCore.luau"` |
| `src/common` | `"$path": "GunCore.luau"` |

Do not put `src/common/GunCore.luau` in a project located under `src/common` or `src/place_match`. Rojo would resolve it as a doubled path such as:

```text
src/common/src/common/GunCore.luau
```

That is the usual cause of widespread `Unknown require` errors.

## Per-folder luau-lsp setup

Every folder opened as a VS Code workspace folder should have a `.vscode/settings.json` that refers to files in that same folder:

```json
{
  "luau-lsp.sourcemap.enabled": true,
  "luau-lsp.sourcemap.autogenerate": true,
  "luau-lsp.sourcemap.rojoProjectFile": "default.project.json",
  "luau-lsp.sourcemap.includeNonScripts": true,
  "luau-lsp.sourcemap.sourcemapFile": "sourcemap.json"
}
```

With this configuration, each workspace folder owns:

```text
src/place_match/default.project.json
src/place_match/sourcemap.json
src/place_match/.vscode/settings.json
```

The same pattern applies to `src/place_lobby` and `src/common`.

## Add a common module to match and lobby

Suppose a module is added at:

```text
src/common/RewardService.luau
```

To require it as `ReplicatedStorage.Shared.RewardService`, add a `RewardService` child under `ReplicatedStorage.Shared` in each place's local project file.

In `src/place_match/default.project.json`:

```json
"RewardService": { "$path": "../common/RewardService.luau" }
```

In `src/place_lobby/default.project.json`:

```json
"RewardService": { "$path": "../common/RewardService.luau" }
```

For a repository-root project file, use this instead:

```json
"RewardService": { "$path": "src/common/RewardService.luau" }
```

Regenerate the relevant maps:

```bash
cd src/place_match
rojo sourcemap default.project.json --output sourcemap.json

cd ../place_lobby
rojo sourcemap default.project.json --output sourcemap.json
```

Then the module can be required from either place:

```luau
local RewardService = require(game:GetService("ReplicatedStorage").Shared.RewardService)
```

## Add a shared server-only module

For a common server-only module such as:

```text
src/common/RewardService.luau
```

map it under `ServerScriptService.ServerModules` rather than `ReplicatedStorage.Shared`:

```json
"ServerModules": {
  "$className": "Folder",
  "RewardService": { "$path": "../common/RewardService.luau" }
}
```

Require it on the server with:

```luau
local RewardService = require(game:GetService("ServerScriptService").ServerModules.RewardService)
```

Do not put server-only modules in `ReplicatedStorage`; clients can access anything there.

## Add a new place

For a new place at `src/place_shop`, create this layout:

```text
src/place_shop/
  client/
  server/
  shared/
  default.project.json
  .vscode/settings.json
```

In `src/place_shop/default.project.json`, use paths relative to `src/place_shop`:

```json
{
  "name": "AlienInvasionShop",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": {
        "$className": "Folder",
        "$path": "shared",
        "Framework": { "$path": "../common/Framework.luau" },
        "Logger": { "$path": "../common/Logger.luau" },
        "GunCore": { "$path": "../common/GunCore.luau" },
        "CombatConfig": { "$path": "../common/configs/CombatConfig.luau" }
      }
    },
    "ServerScriptService": {
      "Server": { "$path": "server" },
      "ServerModules": {
        "$className": "Folder",
        "ProfileService": { "$path": "../common/ProfileService.luau" },
        "GunApi": { "$path": "../common/GunApi.luau" },
        "GunMerge": { "$path": "../common/GunMerge.luau" }
      }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "client" }
      }
    }
  }
}
```

Copy the per-folder luau-lsp settings from the earlier section to `src/place_shop/.vscode/settings.json`, then generate a map:

```bash
cd src/place_shop
rojo sourcemap default.project.json --output sourcemap.json
```

Finally add `src/place_shop` as a folder in the VS Code workspace.

## Troubleshooting

1. Build the map from the directory containing the project file:

   ```bash
   rojo sourcemap default.project.json --output sourcemap.json
   ```

2. If Rojo says a `$path` does not exist, check its base directory. `$path` is not relative to the repository unless the project file is in the repository root.

3. Open `sourcemap.json` and search for the required module. Its `filePaths` value must point to the intended existing `.luau` file.

4. After changing a project mapping, regenerate the map. If VS Code still shows old types or old paths, run **Developer: Reload Window** or restart the Luau language server.

5. Type errors that remain after `Unknown require` disappears are usually real code errors. For example, an imported module may not export the type expected by its callers.

## Module export convention

The import syntax must match what the module returns.

A module that returns a function:

```luau
local function mergeGuns()
end

return mergeGuns
```

is called directly:

```luau
local mergeGuns = require(module)
mergeGuns()
```

A module that returns a table:

```luau
local GunMerge = {}

function GunMerge.mergeGuns()
end

return GunMerge
```

is called through its member:

```luau
local GunMerge = require(module)
GunMerge.mergeGuns()
```
