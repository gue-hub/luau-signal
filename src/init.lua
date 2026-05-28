--[[
	Signal — a lightweight signal/event class for Luau.

	Drop-in alternative to BindableEvent with a friendlier API and lower
	overhead. Handler invocations reuse a single coroutine via the free-runner
	thread pattern, so synchronous Fire() allocates nothing per handler unless
	a handler yields.

	API
	---
		Signal.new() -> Signal
		Signal:Connect(handler: (...any) -> ()) -> Connection
		Signal:Once(handler: (...any) -> ())    -> Connection
		Signal:Wait()                           -> ...any
		Signal:Fire(...)                        -> ()
		Signal:FireDeferred(...)                -> ()
		Signal:DisconnectAll()                  -> ()
		Signal:Destroy()                        -> () -- alias for DisconnectAll

		Connection.Connected: boolean
		Connection:Disconnect() -> ()
		Connection:Destroy()    -> () -- alias for Disconnect

	Notes
	-----
		Fire walks the handler list at the moment of firing. Handlers that
		disconnect themselves during Fire are skipped on subsequent iterations.
		Handlers connected during Fire are NOT invoked by that same Fire call.
--]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

-- Free runner thread: a coroutine that we keep reusing across handler calls
-- so that Fire() does not have to allocate a fresh thread per handler.
local freeRunnerThread: thread? = nil

local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquired = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	freeRunnerThread = acquired
end

local function runEventHandlerInFreeThread(...)
	acquireRunnerThreadAndCallEventHandler(...)
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

function Connection.new(signal, fn)
	return setmetatable({
		Connected = true,
		_signal = signal,
		_fn = fn,
		_next = false,
	}, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false

	local signal = self._signal
	if signal._handlerListHead == self then
		signal._handlerListHead = self._next
	else
		local prev = signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end

Connection.Destroy = Connection.Disconnect

function Signal.new()
	return setmetatable({
		_handlerListHead = false,
	}, Signal)
end

function Signal:Connect(fn)
	assert(type(fn) == "function", "Signal:Connect expects a function, got " .. type(fn))
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		connection._next = self._handlerListHead
	end
	self._handlerListHead = connection
	return connection
end

function Signal:Once(fn)
	assert(type(fn) == "function", "Signal:Once expects a function, got " .. type(fn))
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	local item = self._handlerListHead
	while item do
		if item.Connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
			end
			task.spawn(freeRunnerThread :: thread, item._fn, ...)
		end
		item = item._next
	end
end

function Signal:FireDeferred(...)
	local item = self._handlerListHead
	while item do
		if item.Connected then
			task.defer(item._fn, ...)
		end
		item = item._next
	end
end

function Signal:DisconnectAll()
	local item = self._handlerListHead
	while item do
		item.Connected = false
		item = item._next
	end
	self._handlerListHead = false
end

Signal.Destroy = Signal.DisconnectAll

return Signal
