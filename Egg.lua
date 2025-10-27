---------------------------------------------------------
-- 💾 REMOVED PERSISTENCE: ไม่มีการบันทึก/โหลดการตั้งค่าแล้ว
---------------------------------------------------------
local HttpService       = game:GetService("HttpService")

---------------------------------------------------------
-- 🧩 CONFIG
---------------------------------------------------------
-- ตั้ง webhook ผ่าน getgenv ก่อนรันสคริปต์นี้ เช่น:
getgenv().webhookUrl = "https://discord.com/api/webhooks/1426125399800156190/DK-PiYJr05tETLwtN5hYgevNSJOdwogQ2pAHsOelfqMusXS8YiC0Mdy_wKL2mvxZ6Rc6"
getgenv().delay      = getgenv().delay or 300   -- หน่วงส่ง webhook (วินาที)
getgenv().fpsLimit   = getgenv().fpsLimit or 30
getgenv().whitelist  = getgenv().whitelist or { Pets = { "bear" }, Eggs = {}, Fruits = {} }

---------------------------------------------------------
-- ⚙️ FPS LOCK (ลด CPU)
---------------------------------------------------------
task.spawn(function()
    if setfpscap then
        setfpscap(getgenv().fpsLimit)
        warn("✅ FPS Lock set to " .. getgenv().fpsLimit)
    end
end)

---------------------------------------------------------
-- 🧠 SAFE LOOP
---------------------------------------------------------
local function safeLoop(interval, func)
    task.spawn(function()
        while task.wait(interval) do
            local ok, err = pcall(func)
            if not ok then warn("Loop error:", err) end
        end
    end)
end

---------------------------------------------------------
-- 🌐 SERVICES
---------------------------------------------------------
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

---------------------------------------------------------
-- 🧷 ANTI-AFK (เปิดใช้ทันที)
-- ใช้ VirtualUser จับ Idle แล้วคลิกขวาจิ๋ว ๆ กันโดนเตะ
---------------------------------------------------------
do
    local vu = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end)
    warn("🛡️ Anti-AFK enabled (VirtualUser)")
end

---------------------------------------------------------
-- 📦 DATA HELPERS
---------------------------------------------------------
local function getDataFolder()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    return pg and pg:FindFirstChild("Data")
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

local function abbreviateNumber(n)
    local s = {"", "K", "M", "B", "T"}
    local i = 1
    while math.abs(n) >= 1000 and i < #s do n /= 1000; i += 1 end
    local out = string.format("%.1f%s", n, s[i])
    out = out:gsub("%.0([A-Z]?)$", "%1")
    return out
end

---------------------------------------------------------
-- 📨 WEBHOOK
---------------------------------------------------------
local http = rawget(_G,"request") or rawget(_G,"http_request") or (syn and syn.request) or (http and http.request)

local function sendWebhook()
    local dataFolder = getDataFolder()
    if not dataFolder or not getgenv().webhookUrl then return end

    local petData, totalPets = getPetData(dataFolder)

    -- ทำข้อความรายการ pet แบบย่อ (ชื่อ x จำนวน)
    local list = {}
    for _, v in pairs(petData) do
        table.insert(list, string.format("%s x%s", v.name, abbreviateNumber(v.count)))
    end
    local bodyText = next(list) and table.concat(list, "\n") or "None"

    local embeds = {{
        title = string.format("%s (%s)", LocalPlayer.DisplayName, LocalPlayer.Name),
        description = "🐾 Pets ("..totalPets..")\n```"..bodyText.."```"
    }}

    pcall(function()
        http({
            Url = getgenv().webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ embeds = embeds })
        })
    end)
end

safeLoop(getgenv().delay, sendWebhook)

---------------------------------------------------------
-- 🏆 Claim ทุก Task (5 นาที)
---------------------------------------------------------
local function collectTaskIds()
    local ids, seen = {}, {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        local name = obj.Name
        local tnum = name:match("^Task_(%d+)$")
        if tnum and not seen[name] then
            table.insert(ids, name)
            seen[name] = true
        end
    end
    if #ids == 0 then
        for i = 1, 50 do table.insert(ids, ("Task_%d"):format(i)) end
    end
    table.sort(ids, function(a,b) return tonumber(a:match("%d+")) < tonumber(b:match("%d+")) end)
    return ids
end

local ALL_TASK_IDS = collectTaskIds()
local function claimAllTasks()
    for _, id in ipairs(ALL_TASK_IDS) do
        pcall(function()
            ReplicatedStorage.Remote.DinoEventRE:FireServer({ { event = "claimreward", id = id } })
        end)
        task.wait(0.25)
    end
end
safeLoop(300, claimAllTasks)

---------------------------------------------------------
-- 🐾 Auto Claim Pet + UI (ไม่มีเซฟสถานะอีกต่อไป)
---------------------------------------------------------
local petFolder = Workspace:WaitForChild("Pets")

-- ค่าตั้งต้นตอนเริ่มรอบนี้เท่านั้น (ไม่บันทึก)
local isClaimingEnabled = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DinoHelperUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 240, 0, 50)
toggleButton.Position = UDim2.new(0, 20, 0, 20)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
toggleButton.Draggable = true
toggleButton.Parent = screenGui

local function refresh()
    if isClaimingEnabled then
        toggleButton.Text = "🟢 เปิดใช้งานเก็บเงินออโต้"
        toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    else
        toggleButton.Text = "🔴 ปิดใช้งานเก็บเงินออโต้"
        toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end
refresh()

safeLoop(3, function()
    if not isClaimingEnabled then return end
    for _, pet in pairs(petFolder:GetChildren()) do
        local petUser = pet:GetAttribute("UserId")
        if petUser == LocalPlayer.UserId and pet:FindFirstChild("RE") then
            pet.RE:FireServer("Claim")
        end
    end
end)

toggleButton.MouseButton1Click:Connect(function()
    isClaimingEnabled = not isClaimingEnabled
    refresh()
end)

warn("✅ Script Loaded! Anti-AFK เปิดแล้ว | Webhook ใช้ getgenv().webhookUrl เพื่อกำหนดก่อนรัน")