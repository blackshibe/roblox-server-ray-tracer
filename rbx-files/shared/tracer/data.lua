workspace:WaitForChild("data")

local data = {}

--- defines what tree_data will contain
--- appropiate value must be findable inside workspace.data
local data_instances = {
	"preset";
	"fov";
	"bounces";
	"samples";
	"batch_size";

	"view_distance";
	"shading_enabled";

	"sky_strength";
	"sky_color";

	"fog_color";
	"fog_fade_in";
	"fog_fade_out";
}

for _, name in pairs(data_instances) do
	local value = workspace.data:WaitForChild(name)
	data[name] = value.Value

	value.Changed:Connect(function(new)
		data[name] = new
	end)
end


return data