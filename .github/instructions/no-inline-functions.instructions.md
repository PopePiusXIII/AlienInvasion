---
applyTo: "**/*.luau"
description: "Luau style rules. Use when creating or editing Luau code."
---

Never write inline or anonymous functions in Luau.

Define every callback and closure as a named local function outside the calling expression, then pass that function by name.

Bad:
```luau
remote.OnClientEvent:Connect(function(value)
	handle(value)
end)
```

Good:
```luau
local function onRemoteEvent(value)
	handle(value)
end

remote.OnClientEvent:Connect(onRemoteEvent)
```

This includes event listeners, task callbacks, root callbacks, and callbacks passed to UI helpers. Only use an inline function when the user explicitly asks for one.