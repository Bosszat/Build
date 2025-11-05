

getgenv().webhookUrl      = getgenv().webhookUrl or "https://discord.com/api/webhooks/1426125399800156190/DK-PiYJr05tETLwtN5hYgevNSJOdwogQ2pAHsOelfqMusXS8YiC0Mdy_wKL2mvxZ6Rc6" -- URL Discord Webhook ของบอส
getgenv().secret          = getgenv().secret or "MY_SECRET_123"   -- ไม่จำเป็นสำหรับ Discord แต่อยู่ให้เหมือนเดิม
getgenv().delay           = math.max(60, tonumber(getgenv().delay) or 300) -- ขั้นต่ำ 60 วิ
getgenv().whitelist       = getgenv().whitelist or { Pets = {}, Eggs = {}, Fruits = {} }
getgenv().fpsLimit        = getgenv().fpsLimit or 30
getgenv().manualCooldown  = getgenv().manualCooldown or 10

--======================================================
-- Services
--======================================================
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UIS               = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local displayName       = LocalPlayer.DisplayName or "Unknown"  -- ชื่อเล่น
local realName          = LocalPlayer.Name or "Unknown"         -- ชื่อจริง
local nameHeader        = string.format("**%s (%s)**", realName, displayName)

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")


--======================================================
-- FPS cap (ถ้ามี)
--======================================================
task.spawn(function()
    if typeof(setfpscap) == "function" then
        pcall(setfpscap, getgenv().fpsLimit)
        warn("✅ FPS Lock set to "..tostring(getgenv().fpsLimit))
    end
end)

--======================================================
-- เลือก request() หรือ fallback PostAsync
--======================================================
local function getRequestFunc()
    local req = rawget(_G, "request") or rawget(_G, "http_request")
        or (syn and syn.request) or (http and http.request)
    if req then return req end
    return function(opts)
        assert(opts and opts.Url and opts.Method and opts.Body, "invalid request() opts")
        return HttpService:PostAsync(
            opts.Url,
            opts.Body,
            Enum.HttpContentType.ApplicationJson,
            false
        )
    end
end
local request = getRequestFunc()

--======================================================
-- Helpers
--======================================================
local function getDataFolder()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    return pg and pg:FindFirstChild("Data")
end

local function thousands(n)
    n = tonumber(n) or 0
    local s, neg = tostring(math.floor(math.abs(n))), (n < 0 and "-" or "")
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return neg .. out
end

local function abbreviateNumber(n)
    n = tonumber(n) or 0
    local suf = {"", "K", "M", "B", "T"}
    local i = 1
    while math.abs(n) >= 1000 and i < #suf do n = n/1000; i += 1 end
    local s = string.format("%.1f", n):gsub("%.0$", "")
    return s .. suf[i]
end

local function formatTable(tbl)
    local lines, keys = {}, {}
    for k in pairs(tbl) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local info = tbl[k]
        if typeof(info) == "table" then
            table.insert(lines, string.format("%s — x%d", info.name or k, info.count or 1))
        else
            table.insert(lines, string.format("%s — x%d", k, info))
        end
    end
    return (#lines == 0) and "None" or table.concat(lines, "\n")
end

local function getEggData(dataContainer)
    local eggCounts, totalEggs = {}, 0
    local eggFolder = dataContainer and dataContainer:FindFirstChild("Egg")
    local wl = getgenv().whitelist.Eggs
    local useWL = wl and #wl > 0
    if eggFolder then
        for _, eggData in ipairs(eggFolder:GetChildren()) do
            if eggData:IsA("Configuration") and not eggData:GetAttribute("D") then
                local t = eggData:GetAttribute("T")
                if t then
                    if not useWL or table.find(wl, t) then
                        local m = eggData:GetAttribute("M") or ""
                        local key = t .. "_" .. m
                        local name = (m ~= "" and (t.." ("..m..")")) or t
                        eggCounts[key] = eggCounts[key] or { name = name, count = 0 }
                        eggCounts[key].count += 1
                    end
                    totalEggs += 1
                end
            end
        end
    end
    return eggCounts, totalEggs
end

local function getPetData(dataContainer)
    local petCounts, totalPets = {}, 0
    local petFolder = dataContainer and dataContainer:FindFirstChild("Pets")
    local wl = getgenv().whitelist.Pets
    local useWL = wl and #wl > 0
    if petFolder then
        for _, petData in ipairs(petFolder:GetChildren()) do
            if petData:IsA("Configuration") and not petData:GetAttribute("D") then
                local t = petData:GetAttribute("T")
                if t then
                    if not useWL or table.find(wl, t) then
                        local m = petData:GetAttribute("M") or ""
                        local key = t .. "_" .. m
                        local name = (m ~= "" and (t.." ("..m..")")) or t
                        petCounts[key] = petCounts[key] or { name = name, count = 0 }
                        petCounts[key].count += 1
                    end
                    totalPets += 1
                end
            end
        end
    end
    return petCounts, totalPets
end

local function getFruitData(dataContainer)
    local fruitCounts = {}
    local assetData = dataContainer and dataContainer:FindFirstChild("Asset")
    local wl = getgenv().whitelist.Fruits
    local useWL = wl and #wl > 0
    if assetData then
        for fruitName, count in pairs(assetData:GetAttributes()) do
            if type(count) == "number" and count > 0 then
                if not useWL or table.find(wl, fruitName) then
                    fruitCounts[fruitName] = count
                end
            end
        end
    end
    return fruitCounts
end

--======================================================
-- 📨 Webhook Sender (ชื่อเดิม, ปุ่มเดิม) → ส่งเข้า Discord
--======================================================
local function sendWebhook()
    local dataFolder = getDataFolder()
    if not dataFolder then return warn("Data folder not found!") end
    if not getgenv().webhookUrl or not tostring(getgenv().webhookUrl):find("^https://discord%.com/api/webhooks/") then
        return warn("Invalid or missing webhookUrl (ต้องเป็น Discord Webhook URL)")
    end

    local petData, totalPets = getPetData(dataFolder)  -- ใช้เฉพาะรวม
    local eggData, totalEggs = getEggData(dataFolder)
    local fruitData          = getFruitData(dataFolder)

    local moneyVal = 0
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls and ls:FindFirstChild("Money $") then
            moneyVal = ls["Money $"].Value
        end
    end)

    local candyText = "0"
    pcall(function()
        local gui  = LocalPlayer.PlayerGui:FindFirstChild("ScreenDino")
        local tl   = gui and gui:FindFirstChild("Root") and gui.Root:FindFirstChild("Coin") and gui.Root.Coin:FindFirstChild("TextLabel")
        if tl and tl.Text and #tl.Text > 0 then candyText = tl.Text end
    end)

    -- สรุปสั้น ๆ
    local summary = string.format(
        "Money %s | Candy %s | Total Pets %s | Total Eggs %s",
        abbreviateNumber(moneyVal),
        tostring(candyText),
        thousands(totalPets),
        thousands(totalEggs)
    )

    -- โครงสร้าง JSON สำหรับ Discord
    local bodyTbl = {
        content = string.format("%s\n%s", nameHeader, summary), -- ชื่อจริง+ชื่อเล่น + summary
        username = "Dino Helper",
        allowed_mentions = { parse = {} }, -- กัน @everyone/@here
        embeds = {
            {
                title = "Inventory Snapshot",
                description = "รายละเอียดคงเหลือแบบย่อ",
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"), -- UTC
                fields = {
                    { name = "Money ($)", value = thousands(moneyVal), inline = true },
                    { name = "Candy",     value = tostring(candyText), inline = true },
                    { name = "Total Pets", value = thousands(totalPets), inline = true },
                    { name = "Total Eggs", value = thousands(totalEggs), inline = true },
                    { name = "Eggs",   value = "```\n"..formatTable(eggData).."\n```", inline = false },
                    { name = "Fruits", value = "```\n"..formatTable(fruitData).."\n```", inline = false },
                },
                footer = { text = "secret: "..tostring(getgenv().secret or "") },
            }
        }
    }

    local ok, err = pcall(function()
        request({
            Url = getgenv().webhookUrl,            -- <<-- ใช้ชื่อเดิมตามสคริปต์แรก
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(bodyTbl)
        })
    end)

    if ok then
        print("📤 Sent to Discord Webhook")
        pcall(function() StarterGui:SetCore("SendNotification", {Title="Dino Helper", Text="ส่ง Webhook (Discord) แล้ว ✔", Duration=2}) end)
    else
        warn("⚠️ webhook error:", err)
        pcall(function() StarterGui:SetCore("SendNotification", {Title="Dino Helper", Text="ส่งไม่สำเร็จ ดูคอนโซล", Duration=2.5}) end)
    end
end


--======================================================
-- UI: กล่องควบคุม (เหมือนอันแรก: ปุ่ม “ส่ง Webhook เดี๋ยวนี้”)
--======================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DinoHelperUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "ControlPanel"
container.Size = UDim2.new(0, 260, 0, 190)
container.Position = UDim2.new(0, 20, 0, 20)
container.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
container.BorderSizePixel = 0
container.Parent = screenGui

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 24)
header.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
header.TextColor3 = Color3.fromRGB(255, 255, 255)
header.Font = Enum.Font.SourceSansBold
header.TextScaled = true
header.Text = "Dino Helper"
header.Parent = container

-- ลากได้ทั้งกรอบ
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = container.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function mkButton(text, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 40)
    b.Position = UDim2.new(0, 10, 0, y)
    b.TextScaled = true
    b.Font = Enum.Font.SourceSansBold
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.BackgroundColor3 = color
    b.AutoButtonColor = true
    b.Text = text
    b.Parent = container
    return b
end



-- ปุ่ม ส่ง Webhook เดี๋ยวนี้ (ชื่อเหมือนอันแรก)
local sendButton = mkButton("🚀 ส่ง Webhook เดี๋ยวนี้", 80, Color3.fromRGB(50, 100, 200))
local canSendManual = true
sendButton.MouseButton1Click:Connect(function()
    if not canSendManual then
        pcall(function() StarterGui:SetCore("SendNotification", {Title="Dino Helper", Text="รอคูลดาวน์ก่อนนะ", Duration=1.5}) end)
        return
    end
    canSendManual = false
    sendButton.AutoButtonColor = false
    sendButton.Active = false
    sendButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    sendButton.Text = "⏳ กำลังส่ง..."
    task.spawn(function()
        local ok, err = pcall(sendWebhook)   -- <<-- ใช้ชื่อเดิม
        if not ok then warn("Manual webhook error:", err) end
        for i = getgenv().manualCooldown, 1, -1 do
            sendButton.Text = ("⏳ รอ %ds"):format(i)
            task.wait(1)
        end
        sendButton.Text = "🚀 ส่ง Webhook เดี๋ยวนี้"
        sendButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
        sendButton.Active = true
        sendButton.AutoButtonColor = true
        canSendManual = true
    end)
end)

-- ปุ่ม Auto Webhook ON/OFF (ชื่อเหมือนอันแรก)
local autoSendEnabled = true
local autoBtn = mkButton("🟢 Auto Webhook: ON", 130, Color3.fromRGB(50, 160, 80))
local function refreshAutoBtn()
    if autoSendEnabled then
        autoBtn.Text = "🟢 Auto Webhook: ON"
        autoBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
    else
        autoBtn.Text = "🔴 Auto Webhook: OFF"
        autoBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    end
end
autoBtn.MouseButton1Click:Connect(function()
    autoSendEnabled = not autoSendEnabled
    refreshAutoBtn()
end)
refreshAutoBtn()

-- ป้ายนับถอยหลังออโต้
local countdown = Instance.new("TextLabel")
countdown.Size = UDim2.new(1, -20, 0, 18)
countdown.Position = UDim2.new(0, 10, 0, 172)
countdown.BackgroundTransparency = 1
countdown.TextColor3 = Color3.fromRGB(220, 220, 220)
countdown.Font = Enum.Font.SourceSans
countdown.TextScaled = true
countdown.Text = "Auto webhook: --s"
countdown.Parent = container

--======================================================
-- ลูประบบต่าง ๆ (Delta-friendly)
--======================================================


getgenv().autoCollect = false -- เปิด/ปิด Auto Collect


pcall(function()
    local virtualUser = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        virtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        virtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        print("⚠️ Anti-AFK activated!")
    end)
end)



task.spawn(function()
	while task.wait(0.1) do
		if autoCollect then
			for _, pet in ipairs(Workspace.Pets:GetChildren()) do
				if pet:GetAttribute("UserId") == LocalPlayer.UserId then
					firetouchinterest(HumanoidRootPart, pet, 1)
					task.wait(0.1)
					firetouchinterest(HumanoidRootPart, pet, 0)
				end
			end
		end
	end
end)

--  UI 
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local ToggleButton = Instance.new("TextButton", ScreenGui)
ToggleButton.Size = UDim2.new(0, 120, 0, 40)
ToggleButton.Position = UDim2.new(0, 50, 0, 100)
ToggleButton.BackgroundColor3 = Color3.new(0.2, 0.4, 0.6)
ToggleButton.Text = "Auto Collect: OFF"
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.TextSize = 18
ToggleButton.TextColor3 = Color3.new(1, 1, 1)

ToggleButton.MouseButton1Click:Connect(function()
	getgenv().autoCollect = not getgenv().autoCollect
	ToggleButton.Text = "Auto Collect: " .. (autoCollect and "ON" or "OFF")
	ToggleButton.BackgroundColor3 = autoCollect and Color3.new(0, 0.8, 0.2) or Color3.new(0.8, 0, 0)
end)



-- 2) Auto Webhook (ชื่อเดิม, ทำงานเหมือนเดิม)
task.spawn(function()
    local delaySec = getgenv().delay
    local nextSend = os.clock() + delaySec
    local sending = false
    while true do
        task.wait(1)
        if autoSendEnabled then
            local remain = math.max(0, math.floor(nextSend - os.clock()))
            countdown.Text = "Auto webhook: "..tostring(remain).."s"
            if not sending and os.clock() >= nextSend then
                sending = true
                local ok, err = pcall(sendWebhook)   -- <<-- ใช้ชื่อเดิม
                if not ok then
                    warn("Auto webhook error:", err)
                    pcall(function() StarterGui:SetCore("SendNotification", {Title="Dino Helper", Text="ส่งออโต้ผิดพลาด ดูคอนโซล", Duration=2.5}) end)
                else
                    pcall(function() StarterGui:SetCore("SendNotification", {Title="Dino Helper", Text="ส่งออโต้แล้ว ✔", Duration=2}) end)
                end
                nextSend = os.clock() + delaySec
                sending = false
            end
        else
            countdown.Text = "Auto webhook: OFF"
        end
    end
end)

-- 3) Extra: ไลก์เกาะอื่นทุก ~70 วิ
task.spawn(function()
    local base = Workspace:FindFirstChild("Art")
    if not base then return end
    while true do
        local client = LocalPlayer:GetAttribute("AssignedIslandName")
        for _, v in pairs(base:GetChildren()) do
            if v.Name ~= client then
                local Occply = v:GetAttribute("OccupyingPlayerId")
                if Occply ~= nil then
                    local args = {"GiveLike", tonumber(Occply)}
                    pcall(function()
                        ReplicatedStorage:WaitForChild("Remote"):WaitForChild("CharacterRE"):FireServer(unpack(args))
                    end)
                end
            end
        end
        task.wait(70)
    end
end)

-- 4) Extra: onlinepack เมื่อ remain == 0
task.spawn(function()
    while true do
        task.wait(1)
        local remain = tonumber(LocalPlayer:GetAttribute("DinoEventOnlineRemainSecond")) or 0
        if remain == 0 then
            pcall(function()
                ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE"):FireServer({{ event = "onlinepack" }})
            end)
            task.wait(3)
        end
    end
end)

-- 5) Extra: เคลม Task_7 และ Task_8 ทุก 60 วิ
task.spawn(function()
    while true do
        task.wait(60)
        local r = ReplicatedStorage:WaitForChild("Remote"):WaitForChild("DinoEventRE")
        pcall(function() r:FireServer({{ event = "claimreward", id = "Task_7" }}) end)
        task.wait(3)
        pcall(function() r:FireServer({{ event = "claimreward", id = "Task_8" }}) end)
    end
end)

warn("✅ Dino Helper Loaded! | ส่งชื่อจริง+ชื่อเล่น → Discord Webhook เรียบร้อย")
