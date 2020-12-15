local ReplicatedStorage = game:GetService("ReplicatedStorage")

local util = {}

function util.lerp(a, b, t)
	return a + (b - a) * t
end

function util.map(value, in_min, in_max, out_min, out_max): number
	return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
end

function  util.getTime()
	local date = os.date("!*t")
	return ("%02d:%02d %s"):format(((date.hour % 24) - 1) % 12 + 1, date.min, date.hour > 11 and "PM" or "AM")
end

function util.request(...)
	ReplicatedStorage.send_request:InvokeServer(...)
end

function util.create_value(name, value)
	local v = Instance.new("NumberValue")
	v.Name = name
	v.Value = value
	v.Parent = ReplicatedStorage
end

return util