---------------------------------------------------------
-- 🧩 CONFIG
---------------------------------------------------------
getgenv().webhookUrl = "https://discord.com/api/webhooks/1426125399800156190/DK-PiYJr05tETLwtN5hYgevNSJOdwogQ2pAHsOelfqMusXS8YiC0Mdy_wKL2mvxZ6Rc6"
getgenv().delay = 300 -- หน่วงเวลาส่ง webhook (วินาที)
getgenv().fpsLimit = 30 -- 🔒 จำกัด FPS เพื่อประหยัด CPU
getgenv().whitelist = {
	Pets = { "bear" },
	Eggs = {},
	Fruits = {}
}

---------------------------------------------------------
-- ⚙️ FPS LOCK (ลด CPU)
---------------------------------------------------------
task.spawn(function()
	if setfpscap then
		setfpscap(getgenv().fpsLimit)
		warn("✅ FPS Lock set to " .. getgenv().fpsLimit)
	else
		warn("⚠️ Executor นี้ไม่รองรับ setfpscap(), ใช้ task.wait() แทน")
	end
end)

---------------------------------------------------------
-- 🧠 SAFE LOOP (Loop ประสิทธิภาพสูง)
---------------------------------------------------------
local function safeLoop(interval, func)
	task.spawn(function()
		while task.wait(interval) do
			pcall(func)
		end
	end)
end

---------------------------------------------------------
-- 🌐 MAIN SYSTEM
---------------------------------------------------------
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

---------------------------------------------------------
-- 📦 ดึงข้อมูลจาก PlayerGui (Pets / Eggs / Fruits)
---------------------------------------------------------
local function getDataFolder()
	return LocalPlayer.PlayerGui:FindFirstChild("Data")
end

local function getEggData(dataContainer)
	local eggCounts, total = {}, 0
	local folder = dataContainer and dataContainer:FindFirstChild("Egg")
	local whitelist = getgenv().whitelist.Eggs
	local useWhitelist = whitelist and #whitelist > 0

	if folder then
		for _, egg in ipairs(folder:GetChildren()) do
			if egg:IsA("Configuration") and not egg:GetAttribute("D") then
				local t = egg:GetAttribute("T")
				if t and (not useWhitelist or table.find(whitelist, t)) then
					local mod = egg:GetAttribute("M") or ""
					local key = t .. "_" .. mod
					local name = (mod ~= "") and (t .. " (" .. mod .. ")") or t
					if not eggCounts[key] then eggCounts[key] = { name = name, count = 0 } end
					eggCounts[key].count += 1
					total += 1
				end
			end
		end
	end
	return eggCounts, total
end

local function getPetData(dataContainer)
	local petCounts, total = {}, 0
	local folder = dataContainer and dataContainer:FindFirstChild("Pets")
	local whitelist = getgenv().whitelist.Pets
	local useWhitelist = whitelist and #whitelist > 0

	if folder then
		for _, pet in ipairs(folder:GetChildren()) do
			if pet:IsA("Configuration") and not pet:GetAttribute("D") then
				local t = pet:GetAttribute("T")
				if t and (not useWhitelist or table.find(whitelist, t)) then
					local mod = pet:GetAttribute("M") or ""
					local key = t .. "_" .. mod
					local name = (mod ~= "") and (t .. " (" .. mod .. ")") or t
					if not petCounts[key] then petCounts[key] = { name = name, count = 0 } end
					petCounts[key].count += 1
					total += 1
				end
			end
		end
	end
	return petCounts, total
end

local function getFruitData(dataContainer)
	local fruitCounts = {}
	local folder = dataContainer and dataContainer:FindFirstChild("Asset")
	local whitelist = getgenv().whitelist.Fruits
	local useWhitelist = whitelist and #whitelist > 0

	if folder then
		for fruit, count in pairs(folder:GetAttributes()) do
			if type(count) == "number" and count > 0 then
				if not useWhitelist or table.find(whitelist, fruit) then
					fruitCounts[fruit] = count
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
			table.insert(lines, string.format("%s - x%d", info.name or name, info.count or 1))
		else
			table.insert(lines, string.format("%s - x%d", name, info))
		end
	end
	return #lines > 0 and table.concat(lines, "\n") or "None"
end

local function abbreviateNumber(n)
	local s = {"", "K", "M", "B"}
	local i = 1
	while math.abs(n) >= 1000 and i < #s do
		n /= 1000
		i += 1
	end
	return string.format("%.1f%s", n, s[i]):gsub("%.0", "")
end

---------------------------------------------------------
-- 📨 ส่งข้อมูลไปยัง Discord Webhook
---------------------------------------------------------
local function sendWebhook()
	local dataFolder = getDataFolder()
	if not dataFolder then return end
	local petData, totalPets = getPetData(dataFolder)
	local eggData, totalEggs = getEggData(dataFolder)
	local fruitData = getFruitData(dataFolder)

	local candy = LocalPlayer.PlayerGui.ScreenDino.Root.Coin.TextLabel

	local data = {
		embeds = {
			{
				title = string.format("%s (%s)", LocalPlayer.DisplayName, LocalPlayer.Name),
				description = "💰 Money: "..abbreviateNumber(LocalPlayer.leaderstats["Money $"].Value)
					.." | 🍬 Candy: "..candy.Text
					.."\n```Pets ("..totalPets..")\n"..formatTable(petData)
					.."```\n```Eggs ("..totalEggs..")\n"..formatTable(eggData)
					.."```\n```Fruits\n"..formatTable(fruitData).."```",
			}
		}
	}
	request({
		Url = getgenv().webhookUrl,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode(data)
	})
	print("✅ Webhook sent!")
end

safeLoop(getgenv().delay, sendWebhook)

---------------------------------------------------------
-- 🦖 Auto Like / Dino Event / Claim Reward
---------------------------------------------------------
local base = Workspace.Art
local client = LocalPlayer:GetAttribute("AssignedIslandName")

-- Auto GiveLike
safeLoop(70, function()
	for _, v in pairs(base:GetChildren()) do
		if v.Name ~= client then
			local occ = v:GetAttribute("OccupyingPlayerId")
			if occ then
				local args = { "GiveLike", tonumber(occ) }
				ReplicatedStorage.Remote.CharacterRE:FireServer(unpack(args))
			end
		end
	end
end)

-- Auto DinoEvent
safeLoop(0.3, function()
	local remain = LocalPlayer:GetAttribute("DinoEventOnlineRemainSecond")
	if remain == 0 then
		ReplicatedStorage.Remote.DinoEventRE:FireServer({ { event = "onlinepack" } })
	end
end)

-- Auto Claim Task
safeLoop(60, function()
	for _, id in ipairs({ "Task_7", "Task_8" }) do
		ReplicatedStorage.Remote.DinoEventRE:FireServer({ { event = "claimreward", id = id } })
		task.wait(3)
	end
end)

---------------------------------------------------------
-- 🐾 Auto Claim Pet (พร้อม UI เปิด–ปิด)
---------------------------------------------------------
local petFolder = Workspace:WaitForChild("Pets")

local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
local toggleButton = Instance.new("TextButton", screenGui)
toggleButton.Size = UDim2.new(0, 220, 0, 50)
toggleButton.Position = UDim2.new(0, 20, 0, 20)
toggleButton.Text = "🟢 เปิดใช้งานเก็บเงินออโต้"
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
toggleButton.Draggable = true

local isClaimingEnabled = true

-- Loop สำหรับ Claim Pets
safeLoop(3, function()
	if isClaimingEnabled then
		for _, pet in pairs(petFolder:GetChildren()) do
			local petUser = pet:GetAttribute("UserId")
			if petUser and petUser == LocalPlayer.UserId then
				if pet:FindFirstChild("RE") then
					pet.RE:FireServer("Claim")
				end
			end
		end
	end
end)

toggleButton.MouseButton1Click:Connect(function()
	isClaimingEnabled = not isClaimingEnabled
	if isClaimingEnabled then
		toggleButton.Text = "🟢 เปิดใช้งานเก็บเงินออโต้"
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	else
		toggleButton.Text = "🔴 ปิดใช้งานเก็บเงินออโต้"
		toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end
end)

warn("✅ Script Loaded! ระบบทั้งหมดทำงานเรียบร้อยแล้ว ✅")
