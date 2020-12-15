---offloaded logic for no reason
local frame = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local log = require(ReplicatedStorage.shared.gui.log)
local status = require(ReplicatedStorage.shared.gui.status)

local bounds_frame = ReplicatedStorage.data.boundary:Clone()
local local_player = Players.LocalPlayer
local mouse = local_player:GetMouse()

function frame:pick(group)

	local current_boundary = 1

	local x1 = 0
	local y1 = 0

	local x2 = 0
	local y2 = 0

	group:bindActionBegan("select", "MouseButton1", nil, true, function()
		if current_boundary == 1 then

			bounds_frame.Parent = local_player.PlayerGui.ScreenGui
			current_boundary += 1
			x1 = mouse.X
			y1 = mouse.Y

			while current_boundary == 2 do
				x2 = mouse.X
				y2 = mouse.Y

				bounds_frame.Position = UDim2.new(0,x1,0,y1)
				bounds_frame.Size = UDim2.new(0,x2 - x1,0,y2- y1)
				bounds_frame.text.Text = tostring("X "..bounds_frame.Size.X.Offset.." : Y "..bounds_frame.Size.Y.Offset)

				RunService.RenderStepped:Wait()
			end

			if y2 < y1 then
				local s_y1 = y1

				y1 = y2
				y2 = s_y1
			end

			if x2 < x1 then
				local s_x1 = x1

				x1 = x2
				x2 = s_x1
			end

			bounds_frame.Position = UDim2.new(0,x1,0,y1)
			bounds_frame.Size = UDim2.new(0,x2 - x1,0,y2- y1)
			bounds_frame.text.Text = tostring("X "..bounds_frame.Size.X.Offset.." : Y "..bounds_frame.Size.Y.Offset)

		else
			current_boundary += 1
			group:unbindAction("select")
		end
	end)

	while current_boundary < 3 do
		RunService.Heartbeat:Wait()
	end

	return bounds_frame
end

return frame

