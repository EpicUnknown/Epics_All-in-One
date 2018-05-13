--[[
---- My To-do list ----
-- All core features should be done

############################################################
### [ After completing the above I want to do these things ] ###
- Add support for multiple Sync pokes for diff times of the day
- Add ability to go to PC and find Sync Poke

]]--


-- ## General Items ##
local enableDebugLogging = false 	-- This allows you to post in Forums with specific errors for faster fixes
local disblePrivateMessaging = false -- Exactly what you think it does

-- ## Would you like to farm money? ##
local farmMoney = false
local farmMinAmount = 50000 	-- When should the bot start to farm money?
local farmMaxAmount = 100000 	-- When should the bot stop farming money?

-- ## Would you like to buy pokeballs? ##
local pokeballPurchase = false		-- Do you wish to purchase pokeballs when you get low?
local pokeballType = "Pokeball" 	-- Choose either "Pokeball", "Great Ball" or "Ultra Ball" (Mind the spaces, they MUST be there for Ultra and Great)
local pokeballPurchaseAmount = 20	-- How many pokeballs will you buy?
local pokeballMinAmount = 5			-- How many should you have left before going to buy more?

-- ## Are you using this to level-up? ##
local levelPokemon = false						-- Are we going to level our pokemon?
local levelPokemonMinLevel = 100				-- What level should we stop leveling at?
local levelPokemonIndex = 1						-- Which pokemon will be trained to the level specified? (1-6)

-- ## Are you training EV Stats? ##
local evStatTrain = false
local evStatToTrain = "ATK"		-- Which EV are you training (ATK, DEF, SPD, SPATK, SPDEF, HP)
local evStatMax = 255			-- How high do you wish to train your EV?
local evStatPokemonIndex = 1	-- Which pokemon will be EV Trained?

-- ## Are you using this to catch pokemon? ##
local pokemonCatch = true						-- Are we going to catch pokemon?
local pokemonUncaught = false 					-- This will only catch pokemon that you have not caught before
local pokemonUseSync = false					-- Do you wish to use a pokemon with Synchronize?
local pokemonFalseSwipe = false					-- Will you be using False Swipe?
local pokemonFalseSwipeIndex = 2				-- Where is the pokemon with "False Swipe" located in your party? (1-6)
local pokemonSleepStatus = false				-- Will you be using a Sleeping attack before catching the wild pokemon?
local pokemonSleeperIndex = 3					-- Where is the pokemon with your sleeping attack located in your party? (1-6)
local pokemonSleeperMove = "Sleep Powder"		-- If you are using a Sleeper Poke you MUST input the attack you will be using (Case-sensitive)
local pokemonToCatch = {"Tentacool"}			-- You can add multiple pokemon you want to catch here
local pokemonFishing = false					-- Will you be fishing?
local pokemonRod = "Good Rod"					-- What rod will you be using? Don't worry if you aren't fishing


----------------------------------------------------------------------------------
-- ###### Do not edit below this line unless you know what you are doing ###### --
----------------------------------------------------------------------------------
local version = "v1.1"
name = "All-in-One Script " .. version
author = "iEpic"
description = [[iEpics All-in-One Script]]

local Pathfinder = require "Pathfinder/MoveToApp"
local kantoSpawn = require "Pathfinder/Maps/Kanto/KantoMapSpawn"

local pokemonCaughtCount = {}
local pokemonSeenCount = {}
local startTime = os.time()
local targetMaps = {}
local zoneMaps = {}
local checks = false

local function logMessage(message, type)
	if type == 1 then
		log(message)
	elseif type == 2 then
		log("**[Debug]** : " .. message)
	elseif type == 3 then
		log("**[Info]** : " .. message)
	elseif type == 4 then
		log("**[WARNING]** : " .. message)
	end
end

local function checkEnabled(value)
	if value then
		return "Yes"
	else
		return "No"
	end
end

local tableWithMeta =
	{
    __len = function(self)
        local count = 0
        for i in pairs(self) do
            count = count + 1
        end
        return count
    end
	}

local function printAllTable(varTable)
	local values = nil
	
	for i, key in ipairs(varTable) do
		if not values then
			values = key
		else
			values = values .. ", " .. key
		end
	end
	return values
end

local function checkSyncAlive()
	if pokemonUseSync then
		if getPokemonHealth(pokemonSyncIndex) <= 0 then
			logMessage("Sync Pokemon has fainted. Headed to PokeCenter.", 3)
			Pathfinder.useNearestPokecenter()
			return
		end
		if not getPokemonAbility(1) == "Synchronize" then
			logMessage("The pokemon in your number 1 slot is not Synchronize. Please make it a Synchronize pokemon.", 4)
			fatal("")
		end
	end
end

local function checkFalseSwipePP(inBattle)
	if pokemonFalseSwipe then
		if not inBattle then
			if getRemainingPowerPoints(pokemonFalseSwipeIndex, "False Swipe") <= 0 then
				logMessage("False Swipe pokemon has no more PP left in False Swipe. Headed to PokeCenter.", 3)
				Pathfinder.useNearestPokecenter()
				return
			end
		else
			if getRemainingPowerPoints(pokemonFalseSwipeIndex, "False Swipe") <= 0 then
				return run()
			else
				return useMove("False Swipe")
			end
		end
	end
end

local function checkSleeperPPMove(inBattle)
	if pokemonSleepStatus then
		if not inBattle then
			if getRemainingPowerPoints(pokemonSleeperIndex, pokemonSleeperMove) <= 0 then
				logMessage("Sleeper pokemon has no more PP left in sleep move. Headed to PokeCenter.", 3)
				Pathfinder.useNearestPokecenter()
				return
			end
		else
			if getRemainingPowerPoints(pokemonSleeperIndex, pokemonSleeperMove) <= 0 then
				return run()
			else
				return useMove(pokemonSleeperMove)
			end
		end
	end
end

local function checkTeamSurf()
	for x = 1,getTeamSize() do
		if hasMove(x, "surf") then
			return true
		end
	end	
	return false
end

local function checkMoney()
	if farmMoney then
		if getMoney() < farmMinAmount then
			return true
		elseif getMoney() < farmMaxAmount then
			return true
		else
			return false
		end
	end
end

local function checkPokemonLevel()
	if levelPokemon then
		if getPokemonLevel(levelPokemonIndex) < levelPokemonMinLevel then
			return true
		else
			return false
		end
	end
end

local function checkPokeballs()
	if pokeballPurchase then
		if hasItem(pokeballType) then
			if getItemQuantity(pokeballType) < pokeballMinAmount then
				Pathfinder.useNearestPokemart(pokeballType, pokeballPurchaseAmount)
			end
		else
			Pathfinder.useNearestPokemart(pokeballType, pokeballPurchaseAmount)
		end	
	end
end

local function needToCatch(value)
	for i, pokemon in ipairs(pokemonToCatch) do
		if pokemon == value then
			return true
		end
	end
	return false
end

local function addToCounter(pokemon, caught)

	-- If the pokemon is caught do the below code
	if caught then
		for index, key in pairs(pokemonCaughtCount) do
			if key.name == pokemon then
				key.count = key.count + 1
				return
			end
		end
		pokemon = {name = pokemon, count = 1}
		table.insert(pokemonCaughtCount, pokemon)
		return
	end
	
	-- If the pokemon was just seen then do the below code
	for i, k in pairs(pokemonSeenCount) do
		if k.name == pokemon then
			k.count = k.count + 1
			return
		end
    end
	pokemon = {name = pokemon, count = 1}
	table.insert(pokemonSeenCount, pokemon)	
end

local function displayCounter()

	message = ""
	tempSeen = ""
	
	setmetatable(pokemonCaughtCount, tableWithMeta)
	setmetatable(pokemonSeenCount, tableWithMeta)

	if #pokemonCaughtCount == 0 then
		if #pokemonSeenCount == 0 then
			return "You have not encountered any wild pokemon."
		end
		
		for i, k in pairs(pokemonSeenCount) do
			if message == nil then
				message = "The counters are as follows:\n" .. k.name .. ": Caught:0 Seen: " .. k.count
			else
				message = message .. "\n" .. k.name .. ": Caught:0 Seen: " .. k.count
			end
		end
		return message
	end
	
	for index, key in pairs(pokemonCaughtCount) do
		for i, k in pairs(pokemonSeenCount) do
			if k.name == key.name then
				tempSeen = k.count
			end
		end
		if message == nil then
			message = "The counters are as follows:\n" .. key.name .. ": Caught:" .. key.count .. " Seen: " .. tempSeen
		else
			message = message .. "\n" .. key.name .. ": Caught:" .. key.count .. " Seen: " .. tempSeen
		end		
	end
	
	return message
end

local function checkBotTime()
	endTime = os.time()
	
	if os.difftime(endTime,startTime) <= 30 then
		return
	elseif (os.difftime(endTime,startTime)/60) >= math.random(60,120) then
		relog(math.random(0,60), "The bot has been active for more than 2 hours. Re-logging to stay safe...")
	end
end

local function moveToClosestWild(mapLinks)
	for i, k in pairs(mapLinks) do
		if k.name:contains("Route") then
			return k
		end
	end
end

local function checkMapZone(currentMap, mapList)
	local path = Pathfinder.getPath(currentMap, mapList)
	local lastMap = path[#path]
	
	for i, key in pairs(zoneMaps) do
		if key.mapName == lastMap then
			if key.zone == "Water" then
				return "Water"
			end
			if key.zone == "Land" then
				return "Land"
			end
		end
	end
	
end

local function determineMap()
	for map, zone in pairs(kantoSpawn) do
		for zone, spawn in pairs(zone) do
			for pokemon, spawnRate in pairs(spawn) do
				for _, p in ipairs(pokemonToCatch) do
					if p == pokemon then
						if zone == "Fishing" then
							if pokemonFishing then
								table.insert(targetMaps, map)
								mapData = {mapName = map, zone = zone}
								table.insert(zoneMaps, mapData)
							end
						else
							table.insert(targetMaps, map)
							mapData = {mapName = map, zone = zone}
							table.insert(zoneMaps, mapData)
						end
					end
				end
			end
		end
	end
end

----------------------------- MY TESTING AREA -----------------------------




----------------------------- MY TESTING AREA -----------------------------

function onStart()
	logMessage("0-----------------------------------------------------0",3)
	logMessage("Epics All-in-One started at: " .. os.date("%X"), 3)
	logMessage("Is logging enabled: " .. checkEnabled(enableDebugLogging) , 3)
	
	if #pokemonToCatch > 0 then
		logMessage("We will be catching the following pokemon: " .. printAllTable(pokemonToCatch), 3)
		determineMap()
	end
	logMessage("0-----------------------------------------------------0",3)
	
	
	if enableDebugLogging then
		for i, k in pairs(zoneMaps) do
			logMessage("Map name: " .. k.mapName .. " Zone: " .. k.zone, 2)
		end
	end
	
	if disblePrivateMessaging then
		disablePrivateMessage()
		logMessage("Private Messaging has been disabled.", 3)
	end
	
end

function onPause()
	endTime = os.time()
	logMessage(string.format("The bot has been running for: %.2f", os.difftime(endTime,startTime)/60 ).. " minutes", 3)
	logMessage("0-----------------------------------------------------0",3)
	logMessage(displayCounter(), 3)
	
end

function onStop()
	endTime = os.time()
	logMessage(string.format("The bot ran for: %.2f", os.difftime(endTime,startTime)/60 ).. " minutes", 3)
end

function onPathAction()
	
	-- Lets run our checks before heading out
	checkBotTime()
	checkSyncAlive()
	checkSleeperPPMove(false)
	checkFalseSwipePP(false)
	checkPokeballs()
	
	-- Lets move out
	
	-- Run this portion if we are headed out to catch some pokes
	if #pokemonToCatch > 0 and pokemonCatch then
		if not Pathfinder.moveTo(getMapName(), targetMaps) then
			if checkMapZone(getMapName(), targetMaps) == "Water" then
				if checkTeamSurf() then
					moveToWater()
					checks = false
				elseif pokemonFishing then
					Pathfinder.moveToShoreline()
					checks = false
					if hasItem(pokemonRod) then
						logMessage("You do not have the Pokemon Rod: " .. pokemonRod .. " please change it to a rod you own to continue.", 4)
					elseif useItem(pokemonRod) then
						return
					end
				else
					if not checks then
						checks = true
						logMessage("You wanna catch a water pokemon but do not have surf and have fishing turned off.", 4)
					end
				end
			end
			if checkMapZone(getMapName(), targetMaps) == "Land" then
				moveToGrass()
				checks = false
			end
		end
	else
		-- Run this portion if we are only farming for money or leveling
		if not Pathfinder.moveTo(getMapName(), moveToClosestWild(getMapLinks())) then
			moveToGrass()
		end
	end
	
end

function onBattleAction()
	if isWildBattle() and (needToCatch(getOpponentName()) or (pokemonUncaught and not isAlreadyCaught())) then
		if useItem("Ultra Ball") or useItem("Great Ball") or useItem("Pokeball") then
			return
		end
	elseif farmMoney or levelPokemon  or evStatTrain then
		if checkMoney() and not checkPokemonLevel() and not evStatTrain then
			attack()
		end
		if checkPokemonLevel() or evStatTrain then
			if evStatPokemonIndex == levelPokemonIndex then
				if getActivePokemonNumber() != levelPokemonIndex then
					sendPokemon(levelPokemonIndex)
				elseif isOpponentEffortValue(evStatToTrain) then
					attack()
				else
					run()
				end
			elseif getActivePokemonNumber() != evStatPokemonIndex then
					sendPokemon(evStatPokemonIndex)
			elseif isOpponentEffortValue(evStatToTrain) then
				attack()
			else
				run()
			end
		end
	-- Check if we are using Sync
	elseif pokemonUseSync then
		-- We are using sync, check if we are using False Swipe
		if pokemonFalseSwipe then
			-- We are using False Swipe
			if getActivePokemonNumber() == 1 then
				return sendPokemon(pokemonFalseSwipeIndex)
			elseif getActivePokemonNumber() == pokemonFalseSwipeIndex and getOpponentHealth() > 2 then
				checkFalseSwipePP(true)
			else
				-- Check if we are using a sleep move against the opponent
				if pokemonSleepStatus then
					-- We are using a sleeping pokemon
					if getActivePokemonNumber() != pokemonSleeperIndex then
						return sendPokemon(pokemonSleeperIndex)
					elseif getActivePokemonNumber(pokemonSleeperIndex) and getOpponentStatus() != "SLEEP" then
						checkSleeperPPMove(true)
					elseif getOpponentStatus() == "SLEEP" then
						if useItem(pokeballType) or useItem("Ultra Ball") or useItem("Great Ball") or useItem("Pokeball") then
							return
						end
					end
				else
					-- We are NOT using a sleeping pokemon
					if useItem(pokeballType) or useItem("Ultra Ball") or useItem("Great Ball") or useItem("Pokeball") then
						return
					end
				end
			end				
		else
			-- We are NOT using False Swipe
			if useItem(pokeballType) or useItem("Ultra Ball") or useItem("Great Ball") or useItem("Pokeball") then
				return
			end
		end
	end
	run()
end

function onBattleMessage(wild)
	if wild:contains("A Wild ") then
		addToCounter(getOpponentName(), false)
	end
	if wild:contains("Success!") then
		addToCounter(getOpponentName(), true)
	end
end