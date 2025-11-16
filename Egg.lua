-- 🎒 Inventory Checker + Discord Webhook Sender v9 (Executor Compatible)
-- 🧠 by Phakaphop GPT-5
---------------------------------------------------
-- 🔧 CONFIG
---------------------------------------------------
local WEBHOOK_URL = "https://discord.com/api/webhooks/1426125399800156190/DK-PiYJr05tETLwtN5hYgevNSJOdwogQ2pAHsOelfqMusXS8YiC0Mdy_wKL2mvxZ6Rc6"
local AUTO_REFRESH_SEC = 10
---------------------------------------------------

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

---------------------------------------------------
-- 🥚 RARITY ICONS
---------------------------------------------------
local RARITY_ICONS = {
    Normal = "⚪",
    Golden = "✨",
    Diamond = "💎",
    Electric = "⚡",
    Fire = "🔥",
    Jurassic = "🦖",
    Snow = "❄️",
    Halloween = "🎃"
}

---------------------------------------------------
-- ❌ Non-currency filters
---------------------------------------------------
local NON_CURRENCY_ITEMS = {
    "Grape","Banana","Pear","BloodstoneCycad","DragonFruit","Pumpkin",
    "Apple","Orange","GoldMango","ColossalPinecone","Corn","Durian",
    "Blueberry","Watermelon","Strawberry","CandyCorn","Pineapple",
    "Potion_3in1","FishingBait1","DeepseaPearlFruit","LotteryTicket",
    "FishingBait3","Potion_Hatch","FishingBait2","VoltGinkgo",
    "Potion_Coin","Potion_Luck","Key_Bronze","Key_Silver","Key_Gold",
    "Fruits","Inventory"
}

---------------------------------------------------
-- 🖼️ UI
---------------------------------------------------
local screenGui = Instance.new("ScreenGui", localPlayer:WaitForChild("PlayerGui"))
screenGui.Name = "InventoryCheckerGUI"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 350, 0, 500)
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 42, 54)
mainFrame.BorderColor3 = Color3.fromRGB(98, 114, 164)
mainFrame.Active, mainFrame.Draggable = true, true

local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, 0, 0, 32)
titleLabel.BackgroundColor3 = Color3.fromRGB(50, 52, 64)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "🥚 Egg & Currency Checker (v9)"
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 16

local scrollingFrame = Instance.new("ScrollingFrame", mainFrame)
scrollingFrame.Size = UDim2.new(1, -10, 1, -85)
scrollingFrame.Position = UDim2.new(0, 5, 0, 35)
scrollingFrame.BackgroundColor3 = Color3.fromRGB(30, 32, 42)
scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(98, 114, 164)
local listLayout = Instance.new("UIListLayout", scrollingFrame)
listLayout.Padding = UDim.new(0, 5)

local refreshButton = Instance.new("TextButton", mainFrame)
refreshButton.Size = UDim2.new(0, 160, 0, 30)
refreshButton.Position = UDim2.new(0.5, -165, 1, -40)
refreshButton.BackgroundColor3 = Color3.fromRGB(80, 250, 123)
refreshButton.Text = "🔄 REFRESH"
refreshButton.Font = Enum.Font.SourceSansBold
refreshButton.TextSize = 14

local webhookButton = Instance.new("TextButton", mainFrame)
webhookButton.Size = UDim2.new(0, 160, 0, 30)
webhookButton.Position = UDim2.new(0.5, 5, 1, -40)
webhookButton.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
webhookButton.Text = "📤 SEND NOW"
webhookButton.Font = Enum.Font.SourceSansBold
webhookButton.TextSize = 14

---------------------------------------------------
-- 📦 DATA PARSER
---------------------------------------------------
local function getDataFolder()
	return localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("Data")
end

local function getCoinData(folder)
	local currency = {}
	local asset = folder and folder:FindFirstChild("Asset")
	if asset then
		for name, value in pairs(asset:GetAttributes()) do
			if type(value) == "number" and value > 0 then
				local skip = false
				for _, bad in ipairs(NON_CURRENCY_ITEMS) do
					if name == bad then skip = true break end
				end
				if not skip then
					currency[name] = value
				end
			end
		end
	end
	return currency
end

local function getEggData(folder)
	local eggs_with_status = {}
	local total = 0
	local eggFolder = folder and folder:FindFirstChild("Egg")
	if eggFolder then
		for _, e in ipairs(eggFolder:GetChildren()) do
			if e:IsA("Configuration") and not e:GetAttribute("D") then
				local egg_name = e:GetAttribute("T")
				if egg_name then
					local status = e:GetAttribute("M") or e:GetAttribute("Status") or e:GetAttribute("Buff") or "Normal"
					if status == "" then status = "Normal" end
					total += 1
					local icon = RARITY_ICONS[status] or "⚪"
					local key = string.format("%s [%s %s]", egg_name, icon, status)
					eggs_with_status[key] = (eggs_with_status[key] or 0) + 1
				end
			end
		end
	end
	return eggs_with_status, total
end

---------------------------------------------------
-- 💬 WEBHOOK SENDER (EXECUTOR COMPATIBLE)
---------------------------------------------------
local function formatCurrencyMetric(n)
	local abs = math.abs(n)
	if abs >= 1e18 then return string.format("%.2fQ", n / 1e18)
	elseif abs >= 1e15 then return string.format("%.2fQ", n / 1e15)
	elseif abs >= 1e12 then return string.format("%.2fT", n / 1e12)
	elseif abs >= 1e9 then return string.format("%.2fB", n / 1e9)
	elseif abs >= 1e6 then return string.format("%.2fM", n / 1e6)
	elseif abs >= 1e3 then return string.format("%.2fK", n / 1e3)
	else return tostring(math.floor(n)) end
end

local function JSONEncode(obj)
	if type(obj) == "string" then
		return '"' .. obj:gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
	elseif type(obj) == "number" then
		return tostring(obj)
	elseif type(obj) == "boolean" then
		return obj and "true" or "false"
	elseif type(obj) == "table" then
		if obj[1] then -- array
			local result = "["
			for i, v in ipairs(obj) do
				if i > 1 then result = result .. "," end
				result = result .. JSONEncode(v)
			end
			return result .. "]"
		else -- object
			local result = "{"
			local first = true
			for k, v in pairs(obj) do
				if not first then result = result .. "," end
				result = result .. '"' .. k .. '":' .. JSONEncode(v)
				first = false
			end
			return result .. "}"
		end
	end
	return "null"
end

local function sendWebhookHTTP(url, payload)
	-- ลอง executor methods
	if syn and syn.request then
		syn.request({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload
		})
		return true
	elseif request then
		request({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload
		})
		return true
	elseif http_request then
		http_request({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload
		})
		return true
	end
	return false
end

local function sendWebhook(currency, eggs_with_status, total)
	if not WEBHOOK_URL or WEBHOOK_URL == "" then
		warn("❌ Webhook URL ไม่ได้ตั้งค่า!")
		return
	end

	-- 🎨 สีหลัก Embed (พาสเทลน้ำเงิน)
	local EMBED_COLOR = 0x89CFF0
	local player = localPlayer

	-- 💰 สกุลเงิน
	local currencyText = ""
	for n, v in pairs(currency) do
		currencyText = currencyText .. "💰 **" .. n .. ":** " .. formatCurrencyMetric(v) .. "\n"
	end
	if currencyText == "" then
		currencyText = "`ไม่มีข้อมูล`"
	end

	-- 🥚 ไข่ทั้งหมด พร้อม code block markdown
	local eggList = {}
	local names = {}
	for k in pairs(eggs_with_status) do table.insert(names, k) end
	table.sort(names)
	for _, k in ipairs(names) do
		table.insert(eggList, "- " .. k .. " × " .. eggs_with_status[k] .. "")
	end
	local eggText = #eggList > 0 and "```yml\n" .. table.concat(eggList, "\n") .. "\n```" or "`ไม่มีไข่ที่มีสถานะ`"

	-- 🧩 สร้าง Embed แบบสวยงาม
	local embed = {
		title = "🥚 Egg & Currency Report (v6)",
		color = EMBED_COLOR,
		description = string.format("**Username:** %s\n**Display Name:** %s\n**Total Eggs:** `%d`",
			player.Name, player.DisplayName, total),
		fields = {
			{
				name = "💸 **CURRENCY (Metric)**",
				value = currencyText,
				inline = false
			},
			{
				name = "🥚 **ALL EGGS WITH STATUS**",
				value = eggText,
				inline = false
			}
		},
		footer = {
			text = "Made by Phakaphop v6 | " .. os.date("วันนี้ เวลา %H:%M"),
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
	}

	local payload = JSONEncode({
		username = "🥚 Egg Reporter PRO",
		avatar_url = "https://cdn-icons-png.flaticon.com/512/616/616408.png",
		embeds = { embed }
	})

	local success = sendWebhookHTTP(WEBHOOK_URL, payload)

	if success then
		print("✅ ส่งรายงานเข้า Webhook สำเร็จ!")
		local notif = Instance.new("TextLabel", screenGui)
		notif.Text = "✅ ส่งรายงานสวยงามเข้า Discord แล้ว!"
		notif.TextColor3 = Color3.fromRGB(80, 250, 123)
		notif.Size = UDim2.new(0, 320, 0, 28)
		notif.Position = UDim2.new(0.5, -160, 0, 10)
		notif.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
		notif.TextSize = 14
		notif.Font = Enum.Font.SourceSansBold
		game:GetService("Debris"):AddItem(notif, 3)
	else
		warn("❌ Webhook ส่งไม่สำเร็จ!")
	end
end

---------------------------------------------------
-- 🔁 UPDATE UI
---------------------------------------------------
local function updateDisplay()
	for _, c in ipairs(scrollingFrame:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end

	local folder = getDataFolder()
	if not folder then
		local lbl = Instance.new("TextLabel", scrollingFrame)
		lbl.Text = "⏳ รอเล่นเกมสักครู่..."
		lbl.TextColor3 = Color3.fromRGB(200,200,200)
		lbl.Size = UDim2.new(1,0,0,25)
		lbl.BackgroundTransparency = 1
		return
	end

	local currency = getCoinData(folder)
	local eggs_with_status, total = getEggData(folder)

	local function addHeader(t, color)
		local l = Instance.new("TextLabel", scrollingFrame)
		l.Text = t
		l.TextColor3 = color
		l.Font = Enum.Font.SourceSansBold
		l.TextSize = 18
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1,0,0,25)
	end

	local function addLine(t)
		local l = Instance.new("TextLabel", scrollingFrame)
		l.Text = "  " .. t
		l.TextColor3 = Color3.fromRGB(240,240,240)
		l.Font = Enum.Font.SourceSans
		l.TextSize = 15
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1,0,0,22)
	end

	if next(currency) then
		addHeader("--- 💸 ---", Color3.fromRGB(255,255,0))
		for n,v in pairs(currency) do 
			addLine(n .. ": " .. formatCurrencyMetric(v)) 
		end
	end

	if next(eggs_with_status) then
		addHeader("--- 🥚 ไข่ทั้งหมด ---", Color3.fromRGB(240,100,255))
		local names = {}
		for k in pairs(eggs_with_status) do table.insert(names, k) end
		table.sort(names)
		for _, n in ipairs(names) do 
			addLine(n .. " × " .. eggs_with_status[n]) 
		end
		addHeader("🥚 รวมไข่: " .. total .. " ฟอง", Color3.fromRGB(255,200,100))
	end

	scrollingFrame.CanvasSize = UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y)
end

---------------------------------------------------
-- 🧭 BUTTON EVENTS
---------------------------------------------------
refreshButton.MouseButton1Click:Connect(updateDisplay)

webhookButton.MouseButton1Click:Connect(function()
	local folder = getDataFolder()
	if folder then
		local currency = getCoinData(folder)
		local eggs_with_status, total = getEggData(folder)
		sendWebhook(currency, eggs_with_status, total)
	else
		warn("❌ ไม่พบข้อมูล!")
	end
end)

---------------------------------------------------
-- 🔄 AUTO LOOP (ส่ง Webhook ทุก 10 วิ)
---------------------------------------------------
task.spawn(function()
	updateDisplay()
	while task.wait(AUTO_REFRESH_SEC) do
		if screenGui.Parent then
			pcall(function()
				updateDisplay()
				local folder = getDataFolder()
				if folder then
					local currency = getCoinData(folder)
					local eggs_with_status, total = getEggData(folder)
					sendWebhook(currency, eggs_with_status, total)
				end
			end)
		else
			break
		end
	end
end)

-- ⌨️ KEYBOARD SHORTCUTS
local UserInputService = game:GetService("UserInputService")
local LKey = false
local MKey = false
local KKey = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.L then LKey = true end
	if input.KeyCode == Enum.KeyCode.M then MKey = true end
	if input.KeyCode == Enum.KeyCode.K then KKey = true end
	
	-- L + M = Minimize/Maximize
	if  MKey then
		isMinimized = not isMinimized
		if isMinimized then
			scrollingFrame.Visible = false
			refreshButton.Visible = false
			webhookButton.Visible = false
			mainFrame.Size = UDim2.new(0, 300, 0, 35)
			minimizeBtn.Text = "▲"
		else
			scrollingFrame.Visible = true
			refreshButton.Visible = true
			webhookButton.Visible = true
			mainFrame.Size = UDim2.new(0, 350, 0, 500)
			minimizeBtn.Text = "━"
		end
	end
	
	-- L + K = Close
	if  KKey then
		screenGui:Destroy()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.L then LKey = false end
	if input.KeyCode == Enum.KeyCode.M then MKey = false end
	if input.KeyCode == Enum.KeyCode.K then KKey = false end
end)

print("✅ Inventory Checker v9 Loaded!")
print("📤 Auto Webhook ทุก " .. AUTO_REFRESH_SEC .. " วินาที")
print("⚠️ ใช้ได้กับ: Synapse X, Script-Ware, Fluxus เป็นต้น")
