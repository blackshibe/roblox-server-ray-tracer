local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local console = ReplicatedStorage.data.log.main
local sample = ReplicatedStorage.data.log.sample

local local_player = Players.LocalPlayer

local screen_gui = Instance.new("ScreenGui")
local drawing = false
local iDrawersWaiting = 0
local drawersWaiting = {}

console.Parent = screen_gui
screen_gui.Parent = local_player.PlayerGui

--- what the jf9we9j-fewfj9-wefj-ewf is this function
function printToConsole(message)

	local wait_for
	iDrawersWaiting += 1
	drawersWaiting[iDrawersWaiting] = wait_for

	if drawing then
		repeat RunService.Heartbeat:Wait() until drawersWaiting[1] == wait_for
	end

	local text = sample:Clone()
	text.Text = message
	text.Parent = console.DrawSpace

	for _, v in pairs(console.DrawSpace:GetChildren()) do
		v.Position = v.Position + (sample.Size - UDim2.new(sample.Size.X.Scale, sample.Size.X.Offset, 0, 0))
	end

	iDrawersWaiting -= 1

	for i in pairs(drawersWaiting) do
		local E = (#drawersWaiting - i) + 1
		drawersWaiting[E] = drawersWaiting[E + 1]
	end
end

return printToConsole
