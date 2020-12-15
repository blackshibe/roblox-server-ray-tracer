---@class inputService
local moduleData = {}
local UserInputService = game:GetService("UserInputService")

function moduleData:getGroup(groupName)
	assert(moduleData[groupName], "group not found: "..groupName)
	return moduleData[groupName]
end

function moduleData:add_group(groupName)
	
	local group
	local userInputEvent
	local userInputEvent2

	if moduleData[groupName] then moduleData[groupName]:kill() end
	moduleData[groupName] = {}
	group = moduleData[groupName]

	group.actions = {}
	group.actions.began = {}
	group.actions.ended = {}

	local function inputEvent(group, inputType, gameProcessed)


		for _, data in pairs(group) do

			if inputType.UserInputType == data.inputType
				and data.keyCode
				and inputType.KeyCode == Enum.KeyCode[data.keyCode]
				and (not gameProcessed or data.ignoreGameProcessed)
			then
				data.boundFunction()
			elseif inputType.UserInputType == data.inputType and not data.keyCode and (not gameProcessed or data.ignoreGameProcessed) then
				data.boundFunction()
			end

		end

	end

	function group:kill()
		userInputEvent:Disconnect()
		userInputEvent2:Disconnect()
		moduleData[groupName] = nil
	end

	function group:clear()

		for name in pairs(group.actions.began) do
			group:unbindAction(name)
		end

		for name in pairs(group.actions.ended) do
			group:unbindAction(name)
		end
	end

	function group:unbindAction(actionName)

		group.actions.began[actionName] = nil
		group.actions.ended[actionName] = nil
	end

	function group:bindActionBegan(actionName, inputType, keyCode, ignoreGameProcessed, boundFunction)

		if inputType then
			inputType = Enum.UserInputType[inputType]
		else
			inputType = Enum.UserInputType.Keyboard
		end

		if group.actions.began[actionName] then
			group.actions.began[actionName] = nil
			-- error(actionName.." input already exists")
		end

		if not group.actions.began[actionName] then
			group.actions.began[actionName] = {}
		end

		group.actions.began[actionName] = {

			actionName = actionName;
			boundFunction = boundFunction;
			inputType = inputType;
			keyCode = keyCode;
			ignoreGameProcessed = ignoreGameProcessed;
			Disconnect = function()
				group[actionName].actions.began[actionName] = nil
			end

		}

	end

	function group:bindActionEnded(actionName, inputType, keyCode, ignoreGameProcessed, boundFunction)

		if inputType then
			inputType = Enum.UserInputType[inputType]
		else
			inputType = Enum.UserInputType.Keyboard
		end

		if group.actions.began[actionName] then
			error(actionName.." input already exists")
		end

		if not group.actions.ended[actionName] then
			group.actions.ended[actionName] = {}
		end

		group.actions.ended[actionName] = {

			boundFunction = boundFunction;
			inputType = inputType;
			keyCode = keyCode;
			ignoreGameProcessed = ignoreGameProcessed;
			Disconnect = function()
				group.actions.ended[actionName][actionName] = nil
			end

		}

	end

	userInputEvent = UserInputService.InputBegan:Connect(function(...) inputEvent(group.actions.began, ...) end)
	userInputEvent2 = UserInputService.InputEnded:Connect(function(...) inputEvent(group.actions.ended, ...) end)

	return group
end

moduleData:add_group("randomInputs")

return moduleData