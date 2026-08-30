--==============================================================
-- WAN FPS BOOSTER
-- v0.5.71 - Mobile Fixed / Safe UI / Anti-Lag / FPS Counter / No-Dark
--==============================================================
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = PlayerGui:FindFirstChild("WAN_FPS_Booster")
if oldGui then oldGui:Destroy() end

local isBoosted = false
local sessionToken = 0
local connections = {}
local savedStates = {}
local protectionCache = {}
local fpsEnabled = false
local fpsConnection = nil
local noDarkEnabled = false
local noDarkState = nil

local function disconnectAll()
    for _, connection in ipairs(connections) do
        if connection then pcall(function() connection:Disconnect() end) end
    end
    table.clear(connections)
end

local function isInteractionTrigger(inst)
    return inst and (inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector")
        or inst:IsA("Seat") or inst:IsA("VehicleSeat"))
end

local function isPlayerCharacterModel(model)
    return model and model:IsA("Model") and Players:GetPlayerFromCharacter(model) ~= nil
end

local function getProtectionBoundary(obj)
    if not obj then return nil end
    local current = obj
    while current and current ~= Workspace and current ~= Lighting do
        if current:IsA("Model") then return current end
        current = current.Parent
    end
    current = obj
    while current.Parent and current.Parent ~= Workspace and current.Parent ~= Lighting do
        current = current.Parent
    end
    if current == Workspace or current == Lighting then return nil end
    return current
end

local function calculateBoundaryProtection(boundary)
    if not boundary then return false end
    if boundary:IsA("Model") and isPlayerCharacterModel(boundary) then return true end
    if isInteractionTrigger(boundary) then return true end
    if boundary:FindFirstChildWhichIsA("ProximityPrompt", true) then return true end
    if boundary:FindFirstChildWhichIsA("ClickDetector", true) then return true end
    if boundary:FindFirstChildWhichIsA("Seat", true) then return true end
    if boundary:FindFirstChildWhichIsA("VehicleSeat", true) then return true end
    return false
end

local function isProtected(obj)
    if not obj or obj == Workspace or obj == Lighting then return false end
    local boundary = getProtectionBoundary(obj)
    if not boundary then return false end
    if protectionCache[boundary] ~= nil then return protectionCache[boundary] end
    local result = calculateBoundaryProtection(boundary)
    protectionCache[boundary] = result
    return result
end

local function invalidateProtectionBoundary(obj)
    if not obj then return end
    local boundary = getProtectionBoundary(obj)
    if not boundary then return end
    protectionCache[boundary] = nil
end

local function revertBoundary(boundary)
    if not boundary then return end
    local toRevert = {}
    for obj in pairs(savedStates) do
        if obj and obj.Parent and (obj == boundary or obj:IsDescendantOf(boundary)) then
            table.insert(toRevert, obj)
        end
    end
    for _, obj in ipairs(toRevert) do
        local props = savedStates[obj]
        if props and obj.Parent then
            pcall(function()
                for propertyName, value in pairs(props) do obj[propertyName] = value end
            end)
            savedStates[obj] = nil
        end
    end
end

local function handleNewTrigger(triggerObj)
    if not triggerObj then return end
    local boundary = getProtectionBoundary(triggerObj)
    if not boundary then return end
    invalidateProtectionBoundary(triggerObj)
    revertBoundary(boundary)
    protectionCache[boundary] = true
end

local function saveAndOptimize(obj)
    if not obj or not obj.Parent or isProtected(obj) then return end

    if obj:IsA("BasePart") then
        if not savedStates[obj] then
            savedStates[obj] = {Material = obj.Material, CastShadow = obj.CastShadow}
        end
        pcall(function()
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
        end)

    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        if not savedStates[obj] then savedStates[obj] = {Transparency = obj.Transparency} end
        pcall(function() obj.Transparency = 1 end)

    elseif obj:IsA("ParticleEmitter") or obj:IsA("Fire")
        or obj:IsA("Smoke") or obj:IsA("Sparkles")
        or obj:IsA("Beam") or obj:IsA("Trail") then

        if not savedStates[obj] then savedStates[obj] = {Enabled = obj.Enabled} end
        pcall(function() obj.Enabled = false end)

    elseif obj:IsA("PointLight") or obj:IsA("SpotLight")
        or obj:IsA("SurfaceLight") then

        if not savedStates[obj] then savedStates[obj] = {Shadows = obj.Shadows} end
        pcall(function() obj.Shadows = false end)
    end
end

local function optimizeTerrain()
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    if not savedStates[terrain] then
        savedStates[terrain] = {
            WaterWaveSize = terrain.WaterWaveSize,
            WaterWaveSpeed = terrain.WaterWaveSpeed,
            WaterReflectance = terrain.WaterReflectance,
            WaterTransparency = terrain.WaterTransparency,
            Decoration = terrain.Decoration
        }
    end
    pcall(function()
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 0
        terrain.Decoration = false
    end)
end

local function enableAntiLag()
    if isBoosted then return end
    isBoosted = true
    sessionToken += 1
    local currentSession = sessionToken
    optimizeTerrain()

    task.spawn(function()
        for i, obj in ipairs(Workspace:GetDescendants()) do
            if sessionToken ~= currentSession or not isBoosted then break end
            saveAndOptimize(obj)
            if i % 400 == 0 then task.wait() end
        end
    end)

    local function handleAdded(obj)
        if not isBoosted or sessionToken ~= currentSession then return end
        if isInteractionTrigger(obj) then handleNewTrigger(obj); return end
        saveAndOptimize(obj)
    end

    local function handleRemoving(obj)
        if not isBoosted or sessionToken ~= currentSession then return end
        if isInteractionTrigger(obj) then invalidateProtectionBoundary(obj) end
    end

    table.insert(connections, Workspace.DescendantAdded:Connect(handleAdded))
    table.insert(connections, Lighting.DescendantAdded:Connect(handleAdded))
    table.insert(connections, Workspace.DescendantRemoving:Connect(handleRemoving))
    table.insert(connections, Lighting.DescendantRemoving:Connect(handleRemoving))
end

local function restoreGraphics()
    if not isBoosted then return end
    isBoosted = false
    sessionToken += 1
    disconnectAll()
    for obj, props in pairs(savedStates) do
        if obj and obj.Parent then
            pcall(function()
                for propertyName, value in pairs(props) do obj[propertyName] = value end
            end)
        end
    end
    savedStates = {}
    protectionCache = {}
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WAN_FPS_Booster"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local wanButton = Instance.new("TextButton")
wanButton.Name = "WANButton"
wanButton.Size = UDim2.new(0, 120, 0, 38)
wanButton.Position = UDim2.new(0.5, -60, 0, 18)
wanButton.BackgroundColor3 = Color3.fromRGB(95, 70, 180)
wanButton.BorderSizePixel = 0
wanButton.Text = "WAN"
wanButton.TextColor3 = Color3.fromRGB(255,255,255)
wanButton.TextSize = 18
wanButton.Font = Enum.Font.GothamBold
wanButton.AutoButtonColor = false
wanButton.Parent = screenGui

local wanCorner = Instance.new("UICorner")
wanCorner.CornerRadius = UDim.new(0, 12)
wanCorner.Parent = wanButton

local wanStroke = Instance.new("UIStroke")
wanStroke.Thickness = 1.5
wanStroke.Transparency = 0.35
wanStroke.Parent = wanButton

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 285, 0, 225)
mainFrame.Position = UDim2.new(0.5, -142, 0, 65)
mainFrame.BackgroundColor3 = Color3.fromRGB(25,25,30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 1
mainStroke.Transparency = 0.45
mainStroke.Parent = mainFrame

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,42)
header.BackgroundTransparency = 1
header.Parent = mainFrame

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1,-80,1,0)
headerTitle.Position = UDim2.new(0,15,0,0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "WAN  •  FPS Booster v0.5.71"
headerTitle.TextColor3 = Color3.fromRGB(255,255,255)
headerTitle.TextSize = 16
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0,32,0,30)
minimizeButton.Position = UDim2.new(1,-70,0,6)
minimizeButton.BackgroundColor3 = Color3.fromRGB(55,55,65)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "–"
minimizeButton.TextColor3 = Color3.fromRGB(255,255,255)
minimizeButton.TextSize = 20
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.Parent = header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0,8)
minCorner.Parent = minimizeButton

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0,32,0,30)
closeButton.Position = UDim2.new(1,-35,0,6)
closeButton.BackgroundColor3 = Color3.fromRGB(190,55,65)
closeButton.BorderSizePixel = 0
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(255,255,255)
closeButton.TextSize = 15
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0,8)
closeCorner.Parent = closeButton

local function createSwitch(text, y)
    local label = Instance.new("TextButton")
    label.Size = UDim2.new(1,-105,0,30)
    label.Position = UDim2.new(0,15,0,y)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220,220,225)
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.AutoButtonColor = false
    label.Parent = mainFrame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0,62,0,30)
    button.Position = UDim2.new(1,-78,0,y)
    button.BackgroundColor3 = Color3.fromRGB(75,75,80)
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = mainFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1,0)
    corner.Parent = button

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,24,0,24)
    knob.Position = UDim2.new(0,3,0.5,-12)
    knob.BackgroundColor3 = Color3.fromRGB(235,235,235)
    knob.BorderSizePixel = 0
    knob.Active = false
    knob.Parent = button

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1,0)
    knobCorner.Parent = knob
    return label, button, knob
end

local switchLabel, switchBackground, switchKnob = createSwitch("ลดกราฟิก / ลดภาระ Render",49)
local fpsLabelBtn, fpsSwitch, fpsKnob = createSwitch("แสดง FPS",94)
local noDarkLabelBtn, noDarkSwitch, noDarkKnob = createSwitch("☀️🌑🌙  ทำให้ไม่มืด",134)

local statusLabel = Instance.new("TextButton")
statusLabel.Size = UDim2.new(1,-30,0,28)
statusLabel.Position = UDim2.new(0,15,0,176)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Anti-Lag: ปิด"
statusLabel.TextColor3 = Color3.fromRGB(170,170,180)
statusLabel.TextSize = 13
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.AutoButtonColor = false
statusLabel.Parent = mainFrame

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Name = "FPSCounter"
fpsLabel.Size = UDim2.new(0,120,0,32)
fpsLabel.Position = UDim2.new(0,12,0,12)
fpsLabel.BackgroundColor3 = Color3.fromRGB(20,20,24)
fpsLabel.BackgroundTransparency = 0.15
fpsLabel.BorderSizePixel = 0
fpsLabel.Text = "FPS: --"
fpsLabel.TextColor3 = Color3.fromRGB(255,255,255)
fpsLabel.TextSize = 15
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.Visible = false
fpsLabel.Parent = screenGui

local fpsCorner = Instance.new("UICorner")
fpsCorner.CornerRadius = UDim.new(0,8)
fpsCorner.Parent = fpsLabel

local switchTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function updateSimpleSwitch(switch, knob, enabled, animated)
    local color = enabled and Color3.fromRGB(50,190,90) or Color3.fromRGB(75,75,80)
    local position = enabled and UDim2.new(1,-27,0.5,-12) or UDim2.new(0,3,0.5,-12)
    if animated then
        TweenService:Create(switch,switchTweenInfo,{BackgroundColor3=color}):Play()
        TweenService:Create(knob,switchTweenInfo,{Position=position}):Play()
    else
        switch.BackgroundColor3 = color
        knob.Position = position
    end
end

local function updateSwitch(animated)
    updateSimpleSwitch(switchBackground,switchKnob,isBoosted,animated)
    statusLabel.Text = isBoosted and "Anti-Lag: เปิด" or "Anti-Lag: ปิด"
end

local function setNoDark(enabled)
    noDarkEnabled = enabled
    if enabled then
        if not noDarkState then
            noDarkState = {
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient
            }
        end
        pcall(function()
            Lighting.Brightness = math.max(Lighting.Brightness,2)
            Lighting.Ambient = Color3.fromRGB(180,180,180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
        end)
    elseif noDarkState then
        local state = noDarkState
        pcall(function()
            Lighting.Brightness = state.Brightness
            Lighting.Ambient = state.Ambient
            Lighting.OutdoorAmbient = state.OutdoorAmbient
        end)
        noDarkState = nil
    end
end

local function setFPS(enabled)
    fpsEnabled = enabled
    if fpsConnection then
        fpsConnection:Disconnect()
        fpsConnection = nil
    end
    fpsLabel.Visible = enabled
    updateSimpleSwitch(fpsSwitch,fpsKnob,enabled,true)
    if not enabled then
        fpsLabel.Text = "FPS: --"
        return
    end
    local elapsed, frames = 0, 0
    fpsConnection = RunService.RenderStepped:Connect(function(dt)
        frames += 1
        elapsed += dt
        if elapsed >= 0.5 then
            fpsLabel.Text = "FPS: " .. tostring(math.floor(frames / elapsed + 0.5))
            frames, elapsed = 0, 0
        end
    end)
end

local function toggleAntiLag()
    if isBoosted then restoreGraphics() else enableAntiLag() end
    updateSwitch(true)
end

wanButton.Activated:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

switchBackground.Activated:Connect(toggleAntiLag)
switchLabel.Activated:Connect(toggleAntiLag)
statusLabel.Activated:Connect(toggleAntiLag)

fpsSwitch.Activated:Connect(function()
    setFPS(not fpsEnabled)
end)
fpsLabelBtn.Activated:Connect(function()
    setFPS(not fpsEnabled)
end)

noDarkSwitch.Activated:Connect(function()
    setNoDark(not noDarkEnabled)
    updateSimpleSwitch(noDarkSwitch,noDarkKnob,noDarkEnabled,true)
end)
noDarkLabelBtn.Activated:Connect(function()
    setNoDark(not noDarkEnabled)
    updateSimpleSwitch(noDarkSwitch,noDarkKnob,noDarkEnabled,true)
end)

minimizeButton.Activated:Connect(function()
    mainFrame.Visible = false
end)

closeButton.Activated:Connect(function()
    setFPS(false)
    setNoDark(false)
    if isBoosted then restoreGraphics() end
    screenGui:Destroy()
end)

local function makeDraggable(guiObject, onMove)
    local dragging, dragStart, startPos = false, nil, nil
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(
                startPos.X.Scale,startPos.X.Offset + delta.X,
                startPos.Y.Scale,startPos.Y.Offset + delta.Y
            )
            if onMove then onMove() end
        end
    end)
end

-- WAN button can be moved by mouse or touch.
-- The main panel follows the button while it is being moved.
makeDraggable(wanButton,function()
    mainFrame.Position = UDim2.new(
        0,
        wanButton.AbsolutePosition.X + wanButton.AbsoluteSize.X / 2 - mainFrame.AbsoluteSize.X / 2,
        0,
        wanButton.AbsolutePosition.Y + wanButton.AbsoluteSize.Y + 9
    )
end)

makeDraggable(fpsLabel)

screenGui.Destroying:Connect(function()
    setFPS(false)
    setNoDark(false)
    if isBoosted then restoreGraphics() end
end)

updateSwitch(false)
updateSimpleSwitch(fpsSwitch,fpsKnob,false,false)
updateSimpleSwitch(noDarkSwitch,noDarkKnob,false,false)
