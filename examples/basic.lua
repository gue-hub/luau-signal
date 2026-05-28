-- Basic Signal usage example.

local Signal = require(game.ReplicatedStorage.Signal)

local playerScored = Signal.new()

-- Persistent listener.
local conn = playerScored:Connect(function(playerName, points)
	print(("%s scored %d points"):format(playerName, points))
end)

-- One-shot listener.
playerScored:Once(function(playerName)
	print(playerName .. " was the first to score!")
end)

-- Fire it.
playerScored:Fire("Alice", 10) -- prints both lines
playerScored:Fire("Bob", 5)    -- prints only the persistent one

-- Wait inline (yields the current thread until the next fire).
task.spawn(function()
	local name, points = playerScored:Wait()
	print(("waited and got: %s / %d"):format(name, points))
end)

task.wait(1)
playerScored:Fire("Carol", 7)

-- Clean up.
conn:Disconnect()
playerScored:Destroy()
