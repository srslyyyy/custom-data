local localData = {} -- store our local (non-synced data)
local syncedData = {} -- store our synced data
local privateData = {} -- store our private data
local bufferData = { {}, {} } -- store our data which will be processed via timer
local batchData = { {}, {} } -- store our data which will be processed via function
local playerElements = createElement("playerElement", "playerElements") -- this element will hold our players which are ready to accept events, it's solution for "Server triggered client-side event onClientDoSomeMagic, but event is not added client-side.". We would need that aswell for binding handlers.
local otherElements = createElement("otherElement", "otherElements") -- this element will do the same, but it's desired for non-player elements
local sendBufferWithData = false -- store reference to buffer function

--[[
/***************************************************

***************************************************\
]]

function getCustomData(pElement, pKey, pType, pRequester)
	local cachedTable = pType == "local" and localData or pType == "synced" and syncedData or pType == "private" and privateData or {}

	if pType == "private" then
		cachedTable = privateData[pRequester]

		if cachedTable then
			cachedTable = cachedTable[pElement]
		end
	else
		cachedTable = cachedTable[pElement]
	end

	if cachedTable then -- check if such index exists?
		local allData = pKey == nil -- do we need whole data or certain key?

		return allData and cachedTable or cachedTable[pKey] -- return requested data
	end

	return nil
end

--[[
/***************************************************

***************************************************\
]]

function getElementsByKey(pKey, pValue, pType, pRequester, pMultipleResults)
	local cachedTable = pType == "local" and localData or pType == "synced" and syncedData or pType == "private" and privateData or {}
	local requestedElements = pMultipleResults and {} or false
	local doesHaveData = false

	for element, _ in pairs(cachedTable) do -- loop through all elements
		doesHaveData = getCustomData(element, pKey, pType, pRequester) -- search for the elements which meets conditions

		if doesHaveData then -- if so

			if pValue and pValue ~= doesHaveData then -- in case if we wanna filter also by value
				return false
			end

			if pMultipleResults then -- if we wanna multiple results
				requestedElements[#requestedElements + 1] = element
			else -- otherwise
				requestedElements = element
				break
			end
		end
	end

	return requestedElements -- return requested elements
end

--[[
/***************************************************

***************************************************\
]]

function setCustomData(pElement, pKey, pValue, pType, pReceivers, pSyncer, pEvent, pBuffer, pTimeout)
	local cachedTable = pType == "local" and localData or pType == "synced" and syncedData or pType == "private" and privateData

	if cachedTable then
		local privateType = pType == "private"
		local needSync = pType ~= "local"
		local elementData = false

		if privateType then
			local processAsTable = type(pReceivers) == "table"
			local playerData = false
			local oldPlayerValue = false

			if processAsTable then
				local playersCount = #pReceivers
				local playerElement = false

				for playerID = 1, playersCount do
					playerElement = pReceivers[playerID]
					playerData = privateData[playerElement]

					if playerData then
						elementData = playerData[pElement]

						if elementData then
							oldPlayerValue = elementData[pKey]

							if pValue ~= oldPlayerValue then
								elementData[pKey] = pValue
							else
								pReceivers[playerID] = nil
							end
						else
							playerData[pElement] = { [pKey] = pValue }
						end
					else
						privateData[playerElement] = { [pElement] = { [pKey] = pValue } }
					end
				end
			else
				playerData = privateData[pReceivers]

				if playerData then
					elementData = playerData[pElement]

					if elementData then
						oldPlayerValue = elementData[pKey]

						if pValue ~= oldPlayerValue then
							elementData[pKey] = pValue
						else
							return false
						end
					else
						playerData[pElement] = { [pKey] = pValue }
					end
				else
					privateData[pReceivers] = { [pElement] = { [pKey] = pValue} }
				end
			end
		else
			pReceivers = playerElements
			elementData = cachedTable[pElement]

			if not elementData then
				cachedTable[pElement] = { [pKey] = pValue }
			else
				local oldValue = elementData[pKey]

				if oldValue ~= pValue then
					elementData[pKey] = pValue
				else
					return false
				end
			end
		end
		
		if needSync then

			if pBuffer then

				if pTimeout == -1 then
					local targetBatch = batchData[pType == "synced" and 1 or pType == "private" and 2]
					local existingBatch = targetBatch[pBuffer]

					if existingBatch then
						local batchSize = #existingBatch + 1

						existingBatch[batchSize] = {pElement, pKey, pType, pValue, pEvent, pSyncer, pReceivers}
					else
						targetBatch[pBuffer] = { {pElement, pKey, pType, pValue, pEvent, pSyncer, pReceivers} }
					end

					return true
				else
					local targetBuffer = bufferData[pType == "synced" and 1 or pType == "private" and 2]
					local existingBuffer = targetBuffer[pBuffer]

					if existingBuffer then
						local bufferSize = #existingBuffer + 1

						existingBuffer[bufferSize] = {pElement, pKey, pType, pValue, pEvent, pSyncer}
					else
						targetBuffer[pBuffer] = { {pElement, pKey, pType, pValue, pEvent, pSyncer} }

						setTimer(sendBufferWithData, pTimeout, 1, pBuffer, pType, pReceivers, pSyncer)
					end

					return true
				end
			else
				local validReceivers = isElement(pReceivers) or type(pReceivers) == "table"
				
				if validReceivers then
					pSyncer = isElement(pSyncer) and pSyncer or playerElements

					triggerClientEvent(pReceivers, "onClientReceiveData", pSyncer, false, pElement, pKey, pType, pValue, pEvent, pSyncer)

					return true
				end
			end
		end
	end

	return false
end

--[[
/***************************************************

***************************************************\
]]

function forceBatchDataSync(pQueue, pType)
	local targetBatch = false

	if pType then
		targetBatch = batchData[pType == "synced" and 1 or pType == "private" and 2]

		if pQueue then
			local dataQueue = targetBatch[pQueue] -- check if it exists

			if dataQueue then
				dataQueue = dataQueue[1] -- move us to 1st index

				if dataQueue then
					local receiversList = dataQueue[7] -- get our data
					local validReceivers = isElement(receiversList) or type(receiversList) == "table" -- make sure that receiver is a valid element or array table

					if validReceivers then
						local syncerElement = dataQueue[6] -- get our data

						syncerElement = isElement(syncerElement) and syncerElement or playerElements -- sanity check to avoid errors

						triggerClientEvent(receiversList, "onClientReceiveData", syncerElement, true, targetBatch[pQueue]) -- send as batched data
					end

					targetBatch[pQueue] = nil -- clear our queue

					return true
				end
			end
		else
			local dataPackage = false
			local receiversList = false
			local validReceivers = false
			local syncerElement = false

			for queueName, queueData in pairs(targetBatch) do
				dataPackage = queueData[1]

				if dataPackage then
					receiversList = dataPackage[7] -- get our data
					validReceivers = isElement(receiversList) or type(receiversList) == "table" -- make sure that receiver is a valid element or array table

					if validReceivers then
						syncerElement = dataPackage[6] -- get our data

						syncerElement = isElement(syncerElement) and syncerElement or playerElements -- sanity check to avoid errors

						triggerClientEvent(receiversList, "onClientReceiveData", syncerElement, true, queueData) -- send as batched data
					end
				end
			end

			targetBatch = {} -- reset batch table

			return true
		end
	else
		local dataPackage = false
		local receiversList = false
		local validReceivers = false
		local syncerElement = false
		local tempBatch = false

		for batchType = 1, 2 do
			tempBatch = batchData[batchType]

			for queueName, queueData in pairs(tempBatch) do

				if queueName == pQueue or not pQueue then
					dataPackage = queueData[1]

					if dataPackage then
						receiversList = dataPackage[7] -- get our data
						validReceivers = isElement(receiversList) or type(receiversList) == "table" -- make sure that receiver is a valid element or array table

						if validReceivers then
							syncerElement = dataPackage[6] -- get our data

							syncerElement = isElement(syncerElement) and syncerElement or playerElements -- sanity check to avoid errors

							triggerClientEvent(receiversList, "onClientReceiveData", syncerElement, true, queueData) -- send as batched data
						end

						tempBatch[queueName] = nil
					end
				end
			end
		end

		return true
	end
end

--[[
/***************************************************

***************************************************\
]]

function sendBufferWithData(pBuffer, pType, pReceivers, pSyncer)
	local targetBuffer = bufferData[pType == "synced" and 1 or pType == "private" and 2]
	local validReceivers = isElement(pReceivers) or type(pReceivers) == "table" -- make sure that receiver is a valid element or array table

	if validReceivers then -- if so
		pSyncer = isElement(pSyncer) and pSyncer or playerElements -- sanity check to avoid errors
		triggerClientEvent(pReceivers, "onClientReceiveData", pSyncer, true, targetBuffer[pBuffer]) -- send as buffered data
	end

	targetBuffer[pBuffer] = nil -- clear our queue
end

--[[
/***************************************************

***************************************************\
]]

function onServerPlayerReady()
	if client then -- let's check if it's valid player - remember, do not use 'source'
		local playerParent = getElementParent(client) -- sanity check whether player have already parent

		if playerParent ~= playerElements then -- if so
			setElementParent(client, playerElements) -- add player to our special group of "ready players"
		
			triggerClientEvent(client, "onClientDataSync", client, syncedData) -- we need to send copy of server-side data to client, otherwise client wouldn't have it

			setCustomData(client, "Key", "Value", "synced", {client}, client, "onClientKeyChanged", false, 0)
		end
	end
end
addEvent("onServerPlayerReady", true)
addEventHandler("onServerPlayerReady", root, onServerPlayerReady)

--[[
/***************************************************

***************************************************\
]]

function onElementQuitAndDestroy()
	localData[source] = nil -- clear any local data stored under element index
	syncedData[source] = nil -- clear any synced data stored under element index
	privateData[source] = nil -- clear any private data stored under element index

	for _, playerData in pairs(privateData) do
		playerData[source] = nil
	end
end
addEventHandler("onPlayerQuit", playerElements, onElementQuitAndDestroy) -- let's bind handler just for players which are stored in our 'playerElements' parent
addEventHandler("onElementDestroy", otherElements, onElementQuitAndDestroy) -- let's bind handler just for elements which are stored in our 'otherElements' parent
