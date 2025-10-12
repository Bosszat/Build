local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

local function getDataFolder()
    return localPlayer.PlayerGui:FindFirstChild("Data")
end

local function getEggData(dataContainer)
    local eggCounts = {}
    local totalEggs = 0
    local eggDataFolder = dataContainer and dataContainer:FindFirstChild("Egg")
    local whitelist = shared.whitelist.Eggs
    local useWhitelist = whitelist and #whitelist > 0

    if eggDataFolder then
        for _, eggData in ipairs(eggDataFolder:GetChildren()) do
            if eggData:IsA("Configuration") and not eggData:GetAttribute("D") then
                local eggType = eggData:GetAttribute("T")
                if eggType then

                    if not useWhitelist or table.find(whitelist, eggType) then
                        local modifier = eggData:GetAttribute("M") or ""
                        local uniqueKey = eggType .. "_" .. modifier
                        local displayName = eggType
                        if modifier ~= "" then displayName = string.format("%s (%s)", eggType, modifier) end
                        if not eggCounts[uniqueKey] then eggCounts[uniqueKey] = { name = displayName, count = 0 } end
                        eggCounts[uniqueKey].count = eggCounts[uniqueKey].count + 1
                    end
                    totalEggs = totalEggs + 1
                end
            end
        end
    end
    return eggCounts, totalEggs
end

local function getPetData(dataContainer)
    local petCounts = {}
    local totalPets = 0
    local petDataFolder = dataContainer and dataContainer:FindFirstChild("Pets")
    local whitelist = shared.whitelist.Pets
    local useWhitelist = whitelist and #whitelist > 0

    if petDataFolder then
        for _, petData in ipairs(petDataFolder:GetChildren()) do
            if petData:IsA("Configuration") and not petData:GetAttribute("D") then
                local petType = petData:GetAttribute("T")
                if petType then
                    if not useWhitelist or table.find(whitelist, petType) then
                        local modifier = petData:GetAttribute("M") or ""
                        local uniqueKey = petType .. "_" .. modifier
                        local displayName = petType
                        if modifier ~= "" then displayName = string.format("%s (%s)", petType, modifier) end
                        if not petCounts[uniqueKey] then petCounts[uniqueKey] = { name = displayName, count = 0 } end
                        petCounts[uniqueKey].count = petCounts[uniqueKey].count + 1
                    end
                    totalPets = totalPets + 1
                end
            end
        end
    end
    return petCounts, totalPets
end

local function getFruitData(dataContainer)
    local fruitCounts = {}
    local assetData = dataContainer and dataContainer:FindFirstChild("Asset")
    local whitelist = shared.whitelist.Fruits
    local useWhitelist = whitelist and #whitelist > 0

    if assetData then
        for fruitName, count in pairs(assetData:GetAttributes()) do
            if type(count) == "number" and count > 0 then
                if not useWhitelist or table.find(whitelist, fruitName) then
                    fruitCounts[fruitName] = count
                end
            end
        end
    end
    return fruitCounts
end

local function sendWebhook()
	local dataFolder = getDataFolder()
	if not dataFolder then return warn("Data folder not found!") end
	local petData, totalPets = getPetData(dataFolder)
	local eggData, totalEggs = getEggData(dataFolder)
	local fruitData = getFruitData(dataFolder)

	if (totalPets <= 0) and (totalEggs <= 0) and (next(fruitData) == nil) then
		print("Skipping webhook.")
		return
	end

	local function formatTable(tbl)
		local lines = {}
		for name, info in pairs(tbl) do
			if typeof(info) == "table" then
				table.insert(lines, string.format("*%s* â x%d", info.name or name, info.count or 1))
			else
				table.insert(lines, string.format("*%s* â x%d", name, info))
			end
		end
		if #lines == 0 then
			return "None"
		end
		return table.concat(lines, "\n")
	end

	local data = {
		embeds = {
			{
				title = "Pet Data",
				description = string.format("Total Pets: **%d**\n\n%s", totalPets, formatTable(petData)),
			},
			{
				title = "Egg Data",
				description = string.format("Total Eggs: **%d**\n\n%s", totalEggs, formatTable(eggData)),
			},
			{
				title = "Fruit Data",
				description = formatTable(fruitData),
			},
		}
	}

	request({
		Url = shared.webhookUrl,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = HttpService:JSONEncode(data)
	}) 
	print("send")
end

warn("run")

task.spawn(function()
	while true do
		sendWebhook()
		task.wait(shared.delay)
	end
end)
