workspace:WaitForChild("data")

local data = {}
local data_instances = {
	"preset";
	"fov";
	"bounces";
	"samples";
	"view_distance";
	"sky_color";
	"batch_size";
	"shading_enabled";
	"sky_strength"
}

for _, name in pairs(data_instances) do
	local value = workspace.data:WaitForChild(name)
	data[name] = value.Value

	value.Changed:Connect(function(new)
		data[name] = new
	end)
end


return data