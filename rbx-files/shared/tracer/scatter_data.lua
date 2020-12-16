local ReplicatedStorage = game:GetService("ReplicatedStorage")

local util = require(ReplicatedStorage.shared.tracer.util)

local scatter = {
	[Enum.Material.Metal] = {
		70; function(x, y, z)
			return 0.15+math.noise(x*1, y*1, z*1)*0.01
		end
	};
	[Enum.Material.Concrete] = {
		70; function(x, y, z)
			return util.lerp(math.noise(x*5, y*5, z*5)*0.04, math.noise(x*15, y*15, z*15)*0.4, 0.2)
		end
	};
	[Enum.Material.Plastic] = {
		70; function(x, y, z)
			return math.noise(x*1, y*1, z*1)*0.01
		end
	};
	[Enum.Material.Grass] = {
		90; function(x, y, z)
			return math.noise(x*10, y*10, z*10)*0.5
		end
	};
}

return scatter