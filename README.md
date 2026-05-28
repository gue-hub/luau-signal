# Signal

A lightweight signal/event class for Luau — drop-in alternative to `BindableEvent` with a friendlier API and lower overhead.

```lua
local sig = Signal.new()

sig:Connect(function(value)
    print("got", value)
end)

sig:Fire(42) --> got 42
```

## Why

`BindableEvent` is fine, but it allocates a fresh thread per handler invocation and serialises arguments. For in-Lua eventing — gameplay systems, internal pub/sub, custom service signals — a pure-Lua signal is faster and lets you pass any value (tables, functions, mixed types) without copying.

This module uses the **free-runner thread pattern**: a single coroutine is reused across handler calls, so a non-yielding handler costs effectively zero allocations.

## Install

### Wally

```toml
[dependencies]
Signal = "rumin/signal@1.0.0"
```

### Manual

Copy `src/` into your project and rename it to `Signal`. Or point Rojo at the included `default.project.json` to mount the folder as a `ModuleScript`.

## API

### `Signal.new() -> Signal`

Create a new signal.

### `Signal:Connect(handler) -> Connection`

Register a handler. Returns a `Connection`. Handlers connected during a `Fire` call are not invoked by that same call.

### `Signal:Once(handler) -> Connection`

Like `Connect`, but the handler is disconnected after the first invocation.

### `Signal:Wait() -> ...any`

Yield the current thread until the next `Fire`. Returns the arguments that were fired.

### `Signal:Fire(...)`

Invoke every connected handler synchronously, in connection order (newest first). Each handler runs on a reused coroutine; if a handler yields, subsequent handlers get a fresh coroutine.

### `Signal:FireDeferred(...)`

Like `Fire`, but each handler is dispatched via `task.defer` — runs after the current resumption cycle completes.

### `Signal:DisconnectAll()` / `Signal:Destroy()`

Disconnect every handler. The signal remains usable; `Destroy` is just an alias for symmetry with Roblox conventions.

### `Connection.Connected: boolean`

Read-only flag.

### `Connection:Disconnect()` / `Connection:Destroy()`

Disconnect this handler. Safe to call multiple times.

## Example

```lua
local Signal = require(ReplicatedStorage.Signal)

local playerScored = Signal.new()

local conn = playerScored:Connect(function(name, points)
    print(("%s scored %d points"):format(name, points))
end)

playerScored:Once(function(name)
    print(name .. " was the first to score!")
end)

playerScored:Fire("Alice", 10) -- prints both lines
playerScored:Fire("Bob", 5)    -- only the persistent one
conn:Disconnect()
```

See [`examples/basic.lua`](examples/basic.lua) for a fuller walkthrough.

## Behaviour notes

- **Iteration safety.** Disconnecting a handler during `Fire` is safe; the disconnected handler is skipped on the same pass. Handlers added during `Fire` are not invoked until the next `Fire`.
- **Argument passthrough.** Arguments are passed through `task.spawn`, so any Lua value works (tables stay as references, no serialisation).
- **Yielding handlers.** A handler may yield. The next handler runs on a fresh coroutine; the yielded handler eventually resumes independently.

## License

MIT — see [LICENSE](LICENSE).
