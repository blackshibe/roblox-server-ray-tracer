local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local console = ReplicatedStorage.data.status.main
local local_player = Players.LocalPlayer

local screen_gui = Instance.new("ScreenGui")
console.Parent = screen_gui
screen_gui.Parent = local_player.PlayerGui

function setStatus(status)
	local text = console.Status
	text.Text = status
end

return setStatus
