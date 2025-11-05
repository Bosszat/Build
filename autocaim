
getgenv().autoCollect = false 


pcall(function()
    local virtualUser = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        virtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        virtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        print("done")
    end)
end)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")


task.spawn(function()
	while task.wait(0.1) do
		if autoCollect then
			for _, pet in ipairs(Workspace.Pets:GetChildren()) do
	if pet:GetAttribute(“UserId”) == LocalPlayer.UserId then
		if pet.TrgIdle then
			firetouchinterest(HumanoidRootPart, pet.TrgIdle, 1)
			task.wait(0.1)
			firetouchinterest(HumanoidRootPart, pet.TrgIdle, 0)
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

