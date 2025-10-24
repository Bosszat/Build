getgenv().webhookUrl = "https://discord.com/api/webhooks/1426125399800156190/DK-PiYJr05tETLwtN5hYgevNSJOdwogQ2pAHsOelfqMusXS8YiC0Mdy_wKL2mvxZ6Rc6"
getgenv().delay = 300 
getgenv().whitelist = {
    Pets = { bear },
    Eggs = {},
    Fruits = {}
}

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
    local whitelist = getgenv().whitelist.Eggs
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
    local whitelist = getgenv().whitelist.Pets
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
    local whitelist = getgenv().whitelist.Fruits
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

local function formatTable(tbl)
	local lines = {}
	for name, info in pairs(tbl) do
		if typeof(info) == "table" then
			table.insert(lines, string.format("%s Ã¢ÂÂ x%d", info.name or name, info.count or 1))
		else
			table.insert(lines, string.format("%s Ã¢ÂÂ x%d", name, info))
		end
	end
	if #lines == 0 then
		return "None"
	end
	return table.concat(lines, "\n")
end

local function abbreviateNumber(n)
	local s = {"", "K", "M", "B"}
	local i = 1

	while math.abs(n) >= 1000 and i < #s do
		n /= 1000
		i += 1
	end
    
	return (string.format("%.1f", n):gsub("%.0$", "") .. s[i]):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function sendWebhook()
	local dataFolder = getDataFolder()
	if not dataFolder then return warn("Data folder not found!") end
	local petData, totalPets = getPetData(dataFolder)
	local eggData, totalEggs = getEggData(dataFolder)
	local fruitData = getFruitData(dataFolder)

	local candy = localPlayer.PlayerGui.ScreenDino.Root.Coin.TextLabel
	--[[
	if (totalPets <= 0) and (totalEggs <= 0) and (next(fruitData) == nil) then
		print("Skipping webhook.")
		return
	end
	]]

	local data = {
		embeds = {
			{
				title = localPlayer.Name,
				description = "Money: "..abbreviateNumber(localPlayer.leaderstats["Money $"].Value).."  Candy: "..candy.Text.."```"..string.format("Total Pets: %d\n\n%s", totalPets, formatTable(petData)).."```\n".."```"..string.format("Total Eggs: %d\n\n%s", totalEggs, formatTable(eggData)).."```\n".."```"..formatTable(fruitData).."```",
			}
		}
	}
	request({
		Url = getgenv().webhookUrl,
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
		task.wait(getgenv().delay)
	end
end)

local players = game:GetService("Players")
local LocalPlayer = players.LocalPlayer

local base = workspace.Art
local client = LocalPlayer:GetAttribute("AssignedIslandName")
local dinoTimeRemain = LocalPlayer:GetAttribute("DinoEventOnlineRemainSecond")

while task.wait(.3) do
	for _, v in pairs(base:GetChildren()) do
		if v.Name ~= client then
			local Occply = v:GetAttribute("OccupyingPlayerId")

			if Occply ~= nil then
				local args = {
					[1] = "GiveLike",
					[2] = tonumber(Occply)
				}

				game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
			end
		end
	end

	task.wait(70)
end

while task.wait(.3) do
	if dinoTimeRemain == 0 then
		local args = {
			[1] = {
				["event"] = "onlinepack"
			}
		}

		game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
	end
end

while task.wait(60) do
	local args = {
		[1] = {
			["event"] = "claimreward",
			["id"] = "Task_7"
		}
	}

	game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
	task.wait(3)
	local args = {
		[1] = {
			["event"] = "claimreward",
			["id"] = "Task_8"
		}
	}

	game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer(unpack(args))
end
