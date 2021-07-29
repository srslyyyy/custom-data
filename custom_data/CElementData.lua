local localData = {} -- store our local (non-synced data)
local syncedData = {} -- store our synced data
local privateData = {} -- store our private data
local dataHandlers = {} -- store our data handlers
local playerElements = getElementByID("playerElements") -- we would need that aswell for binding handlers.
local otherElements = getElementByID("otherElements") -- we would need that aswell for binding handlers.

--[[
/***************************************************

***************************************************\
]]

function getCustomData(pElement, pKey, pType)
	local cachedTable = pType == "local" and localData or pType == "synced" and syncedData or pType == "private" and privateData or {}

	cachedTable = cachedTable[pElement]

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

function getElementsByKey(pKey, pValue, pType, pMultipleResults)
	local cachedTable = pType == "local" and localData or pType == "synced" and syncedData or pType == "private" and privateData or {}
	local requestedElements = pMultipleResults and {} or false
	local doesHaveData = false

	for element, _ in pairs(cachedTable) do -- loop through all elements
		doesHaveData = getCustomData(element, pKey, pType) -- search for the elements which meets conditions

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

function setCustomData(pElement, pKey, pValue, pType, pEvent, pSyncer)
	local cachedTable = pType == "local" and localData or pType == "synced" and syncedData or pType == "private" and privateData

	if cachedTable then
		local elementData = cachedTable[pElement]
		local oldValue = false

		if not elementData then
			cachedTable[pElement] = {}
			elementData = cachedTable[pElement]
		end

		oldValue = elementData[pKey] -- get old value for data handlers

		if pValue ~= oldValue then -- if data isn't equal, process it
			elementData[pKey] = pValue -- set our value

			handleDataChange(pElement, pKey, pType, oldValue, pValue, pEvent, pSyncer) -- handle our functions (if there's any)

			return true
		end
	end

	return false
end

--[[
/***************************************************

***************************************************\
]]

function addDataHandler(pElementTypes, pTypes, pKeys, pFunction, pEvent)
	local validElementTypes = type(pElementTypes) == "string" or type(pElementTypes) == "table" -- check if it's valid type
	local validTypes = type(pTypes) == "string" or type(pTypes) == "table" -- check if it's valid type
	local validKeys = type(pKeys) == "string" or type(pKeys) == "table" -- check if it's valid type
	local validFunction = type(pFunction) == "function" -- check if it's valid type
	local validServerEvents = type(pEvent) == "string" or type(pEvent) == "table" or not pEvent -- check if it's valid type

	if validElementTypes and validTypes and validKeys and validFunction and validServerEvents then -- if all correct
		local elementType = false -- element type
		local currentHandler = false -- reference to table
		local currentSize = false -- new index for data

		local isTypesTable = type(pTypes) == "table" -- check if it's table
		local typesCount = isTypesTable and #pTypes or false -- if so, save types count, otherwise make it boolean
		local requireTypeMatching = isTypesTable and typesCount > 0 or not isTypesTable -- check whether we need to verify type
		local newTypes = requireTypeMatching and {} or false -- if so, create table, otherwise make it boolean

		local isKeysTable = type(pKeys) == "table" -- check if it's table
		local keysCount = isKeysTable and #pKeys or false -- if so, save keys count, otherwise make it boolean
		local requireKeyMatching = isKeysTable and keysCount > 0 or not isKeysTable -- check whether we need to verify key
		local newKeys = requireKeyMatching and {} or false -- if so, create table, otherwise make it boolean

		local isEventsTable = type(pEvent) == "table" -- check if it's table
		local eventsCount = isEventsTable and #pEvent or 0 -- if so, save events count - we will use them later
		local requireEventMatching = isEventsTable and eventsCount > 0 or not isEventsTable -- check whether we need to verify event
		local newEvents = requireEventMatching and {} or false -- if so, create table, otherwise make it boolean

		if requireTypeMatching then

			if isTypesTable then
				local typeName = false -- save type name here

				for typeID = 1, typesCount do
					typeName = pTypes[typeID]
					newTypes[typeName] = true
				end
			else
				newTypes[pTypes] = true
			end
		end

		if requireKeyMatching then -- if we require key matching

			if isKeysTable then -- if key is passed as table
				local keyName = false -- save key name here

				for keyID = 1, keysCount do -- loop through each key
					keyName = pKeys[keyID] -- update variable
					newKeys[keyName] = true -- insert key name as index in new table
				end
			else -- otherwise
				newKeys[pKeys] = true -- ditto, but we don't need loop here
			end
		end

		if requireEventMatching then -- if we require event matching

			if isEventsTable then -- if event is passed as table
				local eventName = false -- save event name here

				for eventID = 1, eventsCount do -- loop through each event
					eventName = pEvent[eventID] -- update variable
					newEvents[eventName] = true -- insert event name as index in new table
				end
			else -- otherwise
				newEvents[pEvent] = true -- ditto, but we don't need loop here
			end
		end

		local packedData = {newTypes, newKeys, newEvents, pFunction, requireTypeMatching, requireKeyMatching, requireEventMatching} -- store our packed data
		local elementTypes = type(pElementTypes) -- check if it's string

		if elementTypes == "string" then -- if so
			currentHandler = dataHandlers[pElementTypes] -- store reference

			if not currentHandler then -- if such index doesn't exist...
				dataHandlers[pElementTypes] = {packedData} -- insert packed data
			else -- otherwise
				currentSize = #currentHandler + 1 -- get new index for data
				currentHandler[currentSize] = packedData -- insert packed data
			end
		else -- otherwise
			for typeID = 1, #pElementTypes do -- loop through given table
				elementType = pElementTypes[typeID] -- get element type
				currentHandler = dataHandlers[elementType] -- store reference

				if not currentHandler then -- if such index doesn't exist...
					dataHandlers[elementType] = {packedData} -- insert packed data
				else -- otherwise
					currentSize = #currentHandler + 1 -- get new index for data
					currentHandler[currentSize] = packedData -- insert packed data
				end
			end
		end

		return true
	end

	return false
end

--[[
/***************************************************

***************************************************\
]]

function handleDataChange(pElement, pKey, pType, pOldValue, pNewValue, pEvent, pSyncer)
	local isValidElement = isElement(pElement) -- we want element to exist at the time when handler was processed

	if isValidElement then
		local elementType = getElementType(pElement) -- get our element type
		local elementHandlers = dataHandlers[elementType] -- check if there's any handler for this type of element

		if elementHandlers then -- yup, apparently there is something
			local handlerData = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerTypes = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerKeys = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerEvents = false -- remember, reuse it's always faster rather than recreating variable each time
			local handlerFunction = false -- remember, reuse it's always faster rather than recreating variable each time
			local requireTypeMatching = false -- remember, reuse it's always faster rather than recreating variable each time
			local requireKeyMatching = false -- remember, reuse it's always faster rather than recreating variable each time
			local requireEventMatching = false -- remember, reuse it's always faster rather than recreating variable each time
			local isTypeEqual = false -- remember, reuse it's always faster rather than recreating variable each time
			local isKeyEqual = false -- remember, reuse it's always faster rather than recreating variable each time
			local isEventEqual = false -- remember, reuse it's always faster rather than recreating variable each time

			for handlerID = 1, #elementHandlers do -- process our handlers by loop
				handlerData = elementHandlers[handlerID] -- cache target table to reduce indexing
				handlerTypes = handlerData[1] -- get our data
				handlerKeys = handlerData[2] -- get our data
				handlerEvents = handlerData[3] -- get our data
				requireTypeMatching = handlerData[5]
				requireKeyMatching = handlerData[6] -- get our data
				requireEventMatching = handlerData[7] -- get our data

				isTypeEqual = requireTypeMatching and handlerTypes[pType] or not requireTypeMatching and true or false -- verify whether type is required or not
				isKeyEqual = requireKeyMatching and handlerKeys[pKey] or not requireKeyMatching and true or false -- verify whether key is required or not
				isEventEqual = requireEventMatching and handlerEvents[pEvent] or not requireEventMatching and true or false -- verify whether event is required or not

				if isTypeEqual and isKeyEqual and isEventEqual then -- if everything fine
					handlerFunction = handlerData[4] -- get our data
					handlerFunction(pElement, pKey, pType, pOldValue, pNewValue, pEvent, pSyncer) -- process function
				end
			end
		end
	end
end

--[[
/***************************************************

***************************************************\
]]

function onClientDataHandler(pElement, pKey, pType, pOldValue, pNewValue, pEvent, pSyncer)
	print("onClientDataHandler got triggered at key: "..pKey.." ("..pType.." data) - syncer element: "..inspect(pSyncer))
end
addDataHandler("player", {}, {}, onClientDataHandler, "onClientKeyChanged") -- requirements to trigger function: elements need to be player, any data type and key name can trigger this, event needs to be equal to onClientKeyChanged

--[[
/***************************************************

***************************************************\
]]

function onClientDataSync(pData)
	syncedData = pData -- update data
end
addEvent("onClientDataSync", true)
addEventHandler("onClientDataSync", localPlayer, onClientDataSync)

--[[
/***************************************************

***************************************************\
]]

function onClientReceiveData(...)
	local dataFromServer = {...} -- use vararg, because data coming from server might be packed in table or not
	local isBuffer = dataFromServer[1] -- verify if it's buffered
	local elementToSet = false -- declare it once for better readability, and later reuse it
	local keyToSet = false -- declare it once for better readability, and later reuse it
	local typeToSet = false -- declare it once for better readability, and later reuse it
	local valueToSet = false -- declare it once for better readability, and later reuse it
	local eventToSet = false -- declare it once for better readability, and later reuse it
	local syncerToSet = false -- declare it once for better readability, and later reuse it

	if isBuffer then -- if yes, then use loop to iterate over table
		local dataPackage = dataFromServer[2] -- get data package
		local bufferData = false -- reuse it later

		for i = 1, #dataPackage do -- loop through packed data
			bufferData = dataPackage[i] -- cache target table to reduce indexing
			elementToSet = bufferData[1] -- get our data
			keyToSet = bufferData[2] -- get our data
			typeToSet = bufferData[3] -- get our data
			valueToSet = bufferData[4] -- get our data
			eventToSet = bufferData[5] -- get our data
			syncerToSet = bufferData[6] -- get our data

			setCustomData(elementToSet, keyToSet, valueToSet, typeToSet, eventToSet, syncerToSet) -- set it locally
		end
	else -- otherwise process normally
		elementToSet = dataFromServer[2] -- get our data
		keyToSet = dataFromServer[3] -- get our data
		typeToSet = dataFromServer[4]
		valueToSet = dataFromServer[5] -- get our data
		eventToSet = dataFromServer[6] -- get our data
		syncerToSet = dataFromServer[7] -- get our data

		setCustomData(elementToSet, keyToSet, valueToSet, typeToSet, eventToSet, syncerToSet) -- set it locally
	end
end
addEvent("onClientReceiveData", true)
addEventHandler("onClientReceiveData", root, onClientReceiveData)

--[[
/***************************************************

***************************************************\
]]

function onClientResourceStart()
	triggerServerEvent("onServerPlayerReady", localPlayer) -- let's tell server that client part is ready
end
addEventHandler("onClientResourceStart", resourceRoot, onClientResourceStart)

--[[
/***************************************************

***************************************************\
]]

function onClientElementQuitAndDestroy()
	localData[source] = nil -- clear any local data stored under element index
	syncedData[source] = nil -- clear any synced data stored under element index
	privateData[source] = nil -- clear any private data stored under element index
end
addEventHandler("onClientPlayerQuit", playerElements, onClientElementQuitAndDestroy) -- let's bind handler just for players which are stored in our 'playerElements' parent
addEventHandler("onClientElementDestroy", otherElements, onClientElementQuitAndDestroy) -- let's bind handler just for elements which are stored in our 'otherElements' parent
