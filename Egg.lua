--======================================================
-- Dino Helper (Delta-ready)
-- Webhook + Anti-AFK + Toggle Auto-Claim + Auto Webhook ON/OFF + Manual Send
-- + Extras: Like Islands, Online Pack, Claim Task_7/Task_8
-- * ลูปทั้งหมดใช้ while เพื่อความเสถียรบน Delta
-- * ไม่ส่งรายชื่อสัตว์ (Pets) — ส่งเฉพาะจำนวนรวม Total Pets
--======================================================

-- 🔧 CONFIG (ตั้งก่อนรัน หรือ set ผ่านคอนโซลแล้วค่อย execute สคริปต์นี้)
getgenv().webhookUrl      = getgenv().webhookUrl or " https://discord.com/api/webhooks/1426125399800156190/DK-PiYJr05tETLwtN5hYgevNSJOdwogQ2pAHsOelfqMusXS8YiC0Mdy_wKL2mvxZ6Rc6"
getgenv().delay           = math.max(60, tonumber(getgenv().delay) or 300) -- ขั้นต่ำ 60 วินาที ป้องกันชน rate-limit
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
local displayName       = LocalPlayer.DisplayName or "Unknown"
local realName          = LocalPlayer.Name or "Unknown"
local nameHeader        = string.format("**%s (%s)**", realName, displayName)
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
-- 📨 Webhook Sender (ไม่แสดงรายชื่อสัตว์)
--======================================================
local function sendWebhook()
    local dataFolder = getDataFolder()
    if not dataFolder then return warn("Data folder not found!") end
    if not getgenv().webhookUrl or not tostring(getgenv().webhookUrl):find("^https://discord.com/api/webhooks/") then
        return warn("Invalid or missing webhookUrl")
    end

    local petData, totalPets = getPetData(dataFolder)  -- ใช้แค่ totalPets
    local eggData, totalEggs = getEggData(dataFolder)
    local fruitData         = getFruitData(dataFolder)

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

    -- ไม่ใส่รายละเอียด petData แล้ว เหลือแค่ Total Pets
    local description =
        "Money: " .. abbreviateNumber(moneyVal) ..
        "  Candy: " .. tostring(candyText) ..
        "```" .. string.format("Total Pets: %s", thousands(totalPets)) .. "```" ..
        "\n```" .. string.format("Total Eggs: %s\n\n%s", thousands(totalEggs), formatTable(eggData)) .. "```" ..
        "\n```" .. formatTable(fruitData) .. "```"

    local payload = HttpService:JSONEncode({ embeds = {{ title = nameHeader, description = description }} })

    local ok, err = pcall(function()
        request({
            Url = getgenv().webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload
        })
    end)
    if ok then
        print("📤 Webhook sent")
        pcall(function() StarterGui:SetCore("SendNotification", {Title="Dino Helper", Text="ส่ง Webhook แล้ว ✔", Duration=2}) end)
    else
        warn("⚠️ webhook error:", err)
        pcall(function() StarterGui:SetCore("SendNotification", {Title="Dino Helper", Text="ส่งไม่สำเร็จ ดูคอนโซล", Duration=2.5}) end)
    end
end

--======================================================
-- 🛡 Anti-AFK (Delta-ready | Multi-Strategy + Randomized)
--======================================================
do
    local Players                = game:GetService("Players")
    local LocalPlayer            = Players.LocalPlayer
    local VirtualUser            = game:GetService("VirtualUser")
    local VirtualInputManager    = game:GetService("VirtualInputManager")
    local RunService             = game:GetService("RunService")

    -- seed สุ่มรอบเวลาให้ไม่ตายตัว
    pcall(function() math.randomseed(os.clock()*1e6 % 1e6) end)

    local function pressSpaceQuick()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end

    local function softMouseClick()
        -- คลิกซ้าย + คลิกขวา เบา ๆ ที่หน้าจอ (พิกัด 0,0 ก็พอ แค่ให้เกิดอินพุต)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)  -- left down
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0) -- left up
        end)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0)  -- right down
            VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0) -- right up
        end)
    end

    local function vuNudge()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new()) -- คลิกขวาแบบ VirtualUser
        end)
    end

    local function tinyCameraNudge()
        pcall(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local cf = cam.CFrame
            -- หมุนกล้องเบา ๆ แล้วหมุนกลับ (ไม่ทำให้เวียนหัว)
            cam.CFrame = cf * CFrame.Angles(0, math.rad(1.5), 0)
            RunService.Heartbeat:Wait()
            cam.CFrame = cf
        end)
    end

    local function doAntiAFKTtick()
        -- สลับวิธีเพื่อลดโอกาสโดนจับแพทเทิร์น
        vuNudge()
        softMouseClick()
        pressSpaceQuick()
        tinyCameraNudge()
    end

    -- เมื่อเกมตรวจจับ Idle ให้ยิงทันทีรอบหนึ่ง
    Players.LocalPlayer.Idled:Connect(function()
        doAntiAFKTtick()
    end)

    -- ลูปกันหลุดแบบสุ่มช่วงเวลา (40–70 วิ) เพื่อความเป็นธรรมชาติ
    task.spawn(function()
        while true do
            local waitSec = math.random(40, 70)
            for _ = 1, waitSec do task.wait(1) end
            doAntiAFKTtick()
        end
    end)

    warn("🛡️ Anti-AFK (multi-strategy) enabled")
end

--======================================================
-- UI: กล่องควบคุม (ลากได้ทั้งชุด)
--======================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DinoHelperUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "ControlPanel"
container.Size = UDim2.new(0, 260, 0, 190) -- สูงพอ 3 ปุ่ม + label
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

-- ปุ่ม Toggle Auto-Claim
local isClaimingEnabled = false
local toggleButton = mkButton("🔴 ปิดใช้งานเก็บเงินออโต้", 30, Color3.fromRGB(200, 50, 50))
local function refreshToggle()
    if isClaimingEnabled then
        toggleButton.Text = "🟢 เปิดใช้งานเก็บเงินออโต้"
        toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    else
        toggleButton.Text = "🔴 ปิดใช้งานเก็บเงินออโต้"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end
toggleButton.MouseButton1Click:Connect(function()
    isClaimingEnabled = not isClaimingEnabled
    refreshToggle()
end)
refreshToggle()

-- ปุ่ม ส่ง Webhook เดี๋ยวนี้
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
        local ok, err = pcall(sendWebhook)
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

-- ปุ่ม Auto Webhook ON/OFF
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

-- 1) Auto-Claim Pets (ทุก 3 วิ เมื่อเปิดใช้งาน)
task.spawn(function()
    local petFolder = Workspace:FindFirstChild("Pets") or Workspace:WaitForChild("Pets")
    while true do
        task.wait(3)
        if isClaimingEnabled and petFolder then
            for _, pet in ipairs(petFolder:GetChildren()) do
                local petUser = pet:GetAttribute("UserId")
                if petUser == LocalPlayer.UserId and pet:FindFirstChild("RE") then
                    pcall(function() pet.RE:FireServer("Claim") end)
                end
            end
        end
    end
end)

-- 2) Auto Webhook (จับเวลาแม่นยำ + เปิด/ปิดได้)
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
                local ok, err = pcall(sendWebhook)
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
        -- สแกนเร็ว ๆ ทุก 0.3 วิ แล้วพักยาว 70 วิ หลังจบหนึ่งรอบ
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

warn("✅ Dino Helper Loaded! | ปุ่มอยู่มุมซ้ายบน ลากได้ทั้งกล่อง")