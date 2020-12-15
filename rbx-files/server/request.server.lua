local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local end_request_batch_size = workspace.data.batch_size.Value

local sending = false
local end_request_data = {}
local serializing = false
local url = "http://localhost:5000"
local data_types = {
    "clearServer",
    "init",
    "writePixelRow",
    "writeToImage"
}

local function receiveRequest(player, fields)

	while sending do RunService.Heartbeat:Wait() end
	sending = true
	local data = ""

	-- # write pixel request
	if fields.request_type == 2 and not serializing then
		end_request_data[fields.y_row] = fields.pixel_data
		sending = false
		return
	end

	-- # finish render
	if fields.request_type == 3 then

		-- # send remaining pixels
		warn("sending")
		sending = false
		serializing = true

		local end_request_batch_data = {}
		local start = 1

		for i = 1, #end_request_data, 1 do

			end_request_batch_data[#end_request_batch_data+1] = end_request_data[i]

			if i%end_request_batch_size == 0 or (#end_request_data-i) < end_request_batch_size then

				receiveRequest(nil, {
					["request_type"] = 2;
					["y_row"] = i;
					["pixel_data"] = HttpService:JSONEncode(end_request_batch_data);
				})

				warn(start.."-"..i)
				end_request_batch_data = {}
				start = i
			end
		end
	end

	warn("sending: ".. data_types[fields["request_type"] + 1])

	for k, v in pairs(fields) do
		data = data .. ("&%s=%s"):format(
			HttpService:UrlEncode(k),
			HttpService:UrlEncode(v)
		)
	end
	data = data:sub(2) -- Remove the first &

	-- TODO: catch errors
	print(HttpService:PostAsync(url, data, Enum.HttpContentType.ApplicationUrlEncoded, false))

	sending = false
end

ReplicatedStorage.send_request.OnServerInvoke = receiveRequest