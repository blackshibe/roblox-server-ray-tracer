--[[
	BlackShibe 15/12/2020
	Code refactored & hastily converted to parallel lua
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local is_parallel = script.Parent:IsA("Actor")

local tracer_data: tracer_data = require(ReplicatedStorage.shared.tracer.data)
local input_module = require(ReplicatedStorage.shared.tracer.inputs)
local util = require(ReplicatedStorage.shared.tracer.util)

local bounds
local log
local status

-- optimization
local stepped = RunService.Stepped
local floor = math.floor
local new_Ray = Ray.new
local materials = Enum.Material
local sky_color = tracer_data.sky_color
local new_udim2 = UDim2.new
local server_request = util.request

-- constants
local local_player = Players.LocalPlayer
local camera = workspace.Camera
local mouse = local_player:GetMouse()
local random = Random.new()
local inputs

if not is_parallel then
	bounds = require(ReplicatedStorage.shared.tracer.bounds)
	log = require(ReplicatedStorage.shared.gui.log)
	status = require(ReplicatedStorage.shared.gui.status)
	inputs = input_module:add_group("ray_tracer")
else
	log = function() end
	status = function() end
end

local output_pixels = {}
local scatter = {
	[materials.ForceField] = 0;
	[materials.Glass] = 0;
	[materials.Metal] = 10;
	[materials.SmoothPlastic] = 45;
	[materials.Plastic] = 80;
	[materials.Neon] = 0;
	[materials.Grass] = 90;
	[materials.Concrete] = 90;
	[materials.Slate] = 60;
	[materials.Fabric] = 360;
	[materials.Wood] = 180;
	[materials.WoodPlanks] = 180;
	[materials.Brick] = 180;
	[materials.DiamondPlate] = 30;
	[materials.Cobblestone] = 120;
}

local formatted_start_time
local size = tracer_data.pixel_size
local wait_line = 0
local wait_each = 120
local start = tick()
local sky_r = sky_color.R * 255
local sky_g = sky_color.G * 255
local sky_b = sky_color.B * 255

local bounds_frame

local raycast_params = RaycastParams.new()
raycast_params.FilterDescendantsInstances = { workspace.ignore }
raycast_params.FilterType = Enum.RaycastFilterType.Blacklist

local Sx
local Sy
local Px
local Py

-- # init world
if not is_parallel then
	assert(workspace.presets:FindFirstChild(tracer_data.preset), "invalid preset")
	local model = workspace.presets[tracer_data.preset]
	model.Parent = workspace

	workspace.presets:Destroy()
	model.parts.Parent = workspace
	model.lights.Parent = workspace
	model:Destroy()

	-- # init gui
	log("...")
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = tracer_data.fov

	-- # force the CFrame
	for _ = 1, 25 do
		camera.CFrame = workspace.ignore.camera.CFrame
		RunService.Heartbeat:Wait()
	end

	-- # init tracer
	server_request({
		["request_type"] = 0;
	})

	-- # pick frame from user input
	status("picking render frame")
	log("pick the frame's position then click LMB")

	bounds_frame = bounds:pick(inputs)
	Sx = bounds_frame.Size.X.Offset
	Sy = bounds_frame.Size.Y.Offset
	Px = bounds_frame.Position.X.Offset
	Py = bounds_frame.Position.Y.Offset
	formatted_start_time = util.getTime()

	server_request({
		["request_type"] = 1;
		["image_size_x"] = bounds_frame.Size.X.Offset;
		["image_size_y"] = bounds_frame.Size.Y.Offset;
		["image_wait_size"] = bounds_frame.Size.Y.Offset
	})

	status("rendering")
	log("rendering")

	util.create_value("Sx", Sx)
	util.create_value("Sy", Sy)
	util.create_value("Px", Px)
	util.create_value("Py", Py)
else
	Sx = ReplicatedStorage.Sx.Value
	Sy = ReplicatedStorage.Sy.Value
	Px = ReplicatedStorage.Px.Value
	Py = ReplicatedStorage.Py.Value
end

--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

-- more micro optimization
local lights = workspace.lights
local ignore = workspace.ignore

--[[

	* FOR CLARIFICATION
	> Sx Sy = pickframe sizes, constant
	> x y = current pixel coordinates inside pickframe, from 0 to [axis size]
	> Px Py = pickframe position, combine with x and y to get current screen coordinates
	> Gx Gy = global x and y
	> Iy Xy = iterator loop x y

--]]

for i, v in pairs(scatter) do
	scatter[i] = v*2
end

local function update(waitMul)
	wait_line += (1 / Sx)
	if wait_line >= wait_each * (waitMul or 1) then
		wait_line = 0
		stepped:Wait()
	end
end

local function getSkyColor(Y)
	return Color3.fromRGB(sky_r - (Y / 1.5), sky_g - (Y / 1.5), sky_b - (Y / 1.5))
end

function getReflectedRay(direction, normal, pos)
	local reflectedNormal = direction - (2 * direction:Dot(normal) * normal)
	local refRay = new_Ray(pos, reflectedNormal * 1000)
	return refRay, reflectedNormal
end

function calculateColor(ray: Ray)

	local result = workspace:Raycast(ray.Origin, ray.Direction * tracer_data.view_distance, raycast_params) or {}
	local skyColor = getSkyColor((result.Position or ray.Origin).Y)
	local normal = (result.Normal or Vector3.new())*0.01
	local position = (result.Position or (ray.Origin+ray.Direction)) + normal
	local part = result.Instance

	local r
	local g
	local b
	local samples = tracer_data.samples
	local bounces = tracer_data.bounces

	if part then
		r = part.Color.R
		g = part.Color.G
		b = part.Color.B

		if part.Material == materials.Neon then
			return { r = r; g = g; b = b  }
		end

		if part.Transparency == 1 then
			local newScreenPointRay = new_Ray(position - (normal*0.1), ray.Direction * tracer_data.view_distance)
			return calculateColor(newScreenPointRay)
		end
	else
		return { r = skyColor.r; g = skyColor.g; b = skyColor.b; }
	end

	return { r = r; g = g; b = b; }
end

-- rendering results
if is_parallel and tonumber(script.Parent.Name)%size==0 then
	local Iy = script.Parent.Name

	task.synchronize()

	local line_pixel = ReplicatedStorage.data.pixel:Clone()
	line_pixel.BackgroundTransparency = 0.1
	line_pixel.Parent = local_player.PlayerGui.ScreenGui

	local c
	local Ix = #output_pixels+1

	local function render()

		Ix = #output_pixels+1

		if #output_pixels >= Sx then
			c:Disconnect()
			return
		end

		--picking the given pixel
		local ray = camera:ScreenPointToRay(Px + Ix, Py + Iy)
		local actualRay = new_Ray(ray.Origin, ray.Direction * tracer_data.view_distance)

		--adding to the cache
		output_pixels[Ix] = calculateColor(actualRay)
	end

	c = RunService.Heartbeat:ConnectParallel(function()
		task.synchronize()

		local end_time = tick()+0.01*0.1
		while tick()<end_time do render() end

		line_pixel.Position = UDim2.fromOffset(Px, Py+Iy)
		line_pixel.Size = UDim2.fromOffset(Ix, 1)
	end)

	while #output_pixels < Sx do wait() end
	c:Disconnect()
	script.Parent.Parent = ReplicatedStorage

	for i, v in pairs(output_pixels) do
		if i > Sx then
			output_pixels[i] = nil
		end
	end

	for i = 0, size-1 do
		server_request({
			["request_type"] = 2;
			["y_row"] = Iy+i;
			["pixel_data"] = HttpService:JSONEncode(output_pixels);
		})
	end

	line_pixel.BackgroundTransparency = 0.7
elseif not is_parallel then
	local packets = 64
	local instances = {}
	for Iy = 1, Sy do
		local actor = Instance.new("Actor")
		actor.Name = Iy

		script:Clone().Parent = actor
		actor.Parent = script.Parent
		instances[#instances+1] = actor

		if #instances>packets then
			repeat
				stepped:Wait()
	
				for i, v in pairs(instances) do
					if v.Parent ~= script.Parent then instances[i] = nil print('removed') end
				end
				print("")
			until #instances<packets
		end
	end
end


if not is_parallel then
	function stop()

		local formattedEndTime = util.getTime()

		server_request({
			["request_type"] = 3;
		})

		status("finished")
		log(" ---  Render Results  --- ")
		log("time elapsed: "..tostring(tick() - start))
		log("frame size: X"..Sx.." Y"..Sy)
		log("start time: "..formatted_start_time)
		log("end time: "..formattedEndTime)

		for i, v in pairs(tracer_data) do
			log(tostring(i).." = "..tostring(v))
		end
	end

	inputs:bindActionBegan("finish_render", nil, "E", true, stop)
else
	script.Parent:Destroy()
end
