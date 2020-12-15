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

--> lower to decrease chance of crashes
local target_actors = 12
local ms_budget = 1/target_actors

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
	[materials.Ice] = 20;
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
local bounds_frame
local start = tick()
local sky_r = sky_color.R * 255
local sky_g = sky_color.G * 255
local sky_b = sky_color.B * 255

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

local function getSkyColor(Y)
	return Color3.fromRGB(sky_r - (Y / 1.5), sky_g - (Y / 1.5), sky_b - (Y / 1.5))
end

local function getReflectedRay(direction, normal, pos)
	local reflectedNormal = direction - (2 * direction:Dot(normal) * normal)
	local refRay = new_Ray(pos, reflectedNormal * 1000)
	return refRay, reflectedNormal
end

local function calculateColor(ray: Ray, x, y)

	local screen_y_map = util.map(y, 0, Sy, 0, 1)
	local result = workspace:Raycast(ray.Origin, ray.Direction * tracer_data.view_distance, raycast_params) or {}
	local skyColor = getSkyColor((result.Position or ray.Origin).Y):Lerp(tracer_data.fog_color, screen_y_map)

	local normal = (result.Normal or Vector3.new())
	local position = (result.Position or (ray.Origin+ray.Direction)) + normal*0.01
	local part = result.Instance
	local material = result.Material

	local r
	local g
	local b

	local samples = tracer_data.samples
	local bounces = tracer_data.bounces
	local shading_enabled = tracer_data.shading_enabled

	-- # albedo
	if part then
		r = part.Color.R
		g = part.Color.G
		b = part.Color.B

		if part.Material == materials.Neon then
			local strength = part.strength.Value
			return { r = r*strength; g = g*strength; b = b*strength  }
		end

		if part.Transparency == 1 then
			local newScreenPointRay = new_Ray(position - (normal*0.1), ray.Direction * tracer_data.view_distance)
			return calculateColor(newScreenPointRay, x, y)
		end
	else
		r = skyColor.r
		g = skyColor.g
		b = skyColor.b
	end

	-- # shading
	if shading_enabled and part then

		local shadow_r = 0
		local shadow_g = 0
		local shadow_b = 0
		local shadow_average_sample_size = 1
		local light_strength = 0

		for _ = 1, bounces do
			for _ = 1,samples do

				local rot = math.rad(90)
				local direction = CFrame.fromOrientation(random:NextNumber(-rot, rot),random:NextNumber(-rot, rot),random:NextNumber(-rot, rot)).LookVector * 100

				local f_result = workspace:Raycast(position, direction, raycast_params) or {}
				local f_part = f_result.Instance

				if f_part then
					if f_part.Parent == lights then
						shadow_average_sample_size = shadow_average_sample_size + 1
						shadow_r += (f_part.Color.R)
						shadow_g += (f_part.Color.G)
						shadow_b += (f_part.Color.B)
						light_strength += f_part.strength.Value
					end
				else
					shadow_r += sky_r/255
					shadow_g += sky_g/255
					shadow_b += sky_b/255
					shadow_average_sample_size = shadow_average_sample_size + 1
					light_strength += tracer_data.sky_strength
				end
			end
		end

		r *= (shadow_r / shadow_average_sample_size)
		g *= (shadow_g / shadow_average_sample_size)
		b *= (shadow_b / shadow_average_sample_size)

		-- TODO: this but transparency
		local reflection_r = 1
		local reflection_g = 1
		local reflection_b = 1
		local ref = 0
		if part then
			ref = part.Reflectance
			if part.Reflectance ~= 0 then
				local reflect_ray = getReflectedRay(ray.Direction, normal, position)
				local color = calculateColor(reflect_ray, x, y)
				reflection_r = color.r
				reflection_g = color.g
				reflection_b = color.b
			end
		end

		r *= (((light_strength) / samples) / bounces) + (reflection_r * ref)
		g *= (((light_strength) / samples) / bounces) + (reflection_g * ref)
		b *= (((light_strength) / samples) / bounces) + (reflection_b * ref)
	end

	-- # fog
	local distance_to_camera = (position - workspace.Camera.CFrame.Position).Magnitude
	local fog_fade_out = tracer_data.fog_fade_out
	local fog_fade_in = tracer_data.fog_fade_in

	local factor = math.clamp(util.map(distance_to_camera, fog_fade_out, fog_fade_in, 0, 1), 0, 1)
	r = util.lerp(r, tracer_data.fog_color.r, factor)
	g = util.lerp(g, tracer_data.fog_color.g, factor)
	b = util.lerp(b, tracer_data.fog_color.b, factor)

	return { r = r; g = g; b = b }
end

-- # rendering results
if is_parallel and tonumber(script.Parent.Name) then
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

		-- # picking the given pixel
		local ray = camera:ScreenPointToRay(Px + Ix, Py + Iy)
		local actualRay = new_Ray(ray.Origin, ray.Direction * tracer_data.view_distance)

		-- # adding to the cache and compressing
		local output = calculateColor(actualRay, Ix, Iy)
		output.r = tostring(output.r):sub(1, 5)
		output.g = tostring(output.g):sub(1, 5)
		output.b = tostring(output.b):sub(1, 5)
		output_pixels[Ix] = output
	end

	c = RunService.Heartbeat:ConnectParallel(function()
		task.synchronize()

		-- # render without causing major lag
		local end_time = tick()+ms_budget
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

	server_request({
		["request_type"] = 2;
		["y_row"] = Iy+1;
		["pixel_data"] = HttpService:JSONEncode(output_pixels);
	})

	line_pixel.BackgroundTransparency = 0.7
elseif not is_parallel then
	local instances = {}
	for Iy = 1, Sy do
		local actor = Instance.new("Actor")
		actor.Name = Iy

		script:Clone().Parent = actor
		actor.Parent = script.Parent
		instances[#instances+1] = actor

		-- # always have as many actors as there are target_actors allowed
		if #instances>target_actors then
			repeat
				stepped:Wait()
				for i, v in pairs(instances) do
					if v.Parent ~= script.Parent then instances[i] = nil end
				end
			until #instances<target_actors
		end
	end
end

if not is_parallel then
	function stop()

		local end_time = util.getTime()

		inputs:kill()
		server_request({
			["request_type"] = 3;
		})

		status("finished")
		log(" ---  Render Results  --- ")
		log("time elapsed: "..tostring(tick() - start))
		log("frame size: X"..Sx.." Y"..Sy)
		log("start time: "..formatted_start_time)
		log("end time: "..end_time)

		for i, v in pairs(tracer_data) do
			log(tostring(i).." = "..tostring(v))
		end
	end

	inputs:bindActionBegan("finish_render", nil, "E", true, stop)
else
	script.Parent:Destroy()
end
