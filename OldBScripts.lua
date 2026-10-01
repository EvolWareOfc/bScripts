local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DIST_DOT = 1000
local DIST_MAX = 5000
local espEnabled = true
local chamsEnabled = true
local boxEnabled = true
local linesEnabled = true
local showDistance = true
local showWeapon = true
local squadHighlight = true
local visibleCheckChams = true
local visibleCheckBox = true
local optimisedESP = true
local fullbrightEnabled = false

local espData = {}
local drawBoxes = {}
local drawLines = {}
local visCache = {}
local visFrame = 0
local charactersFolder = workspace:FindFirstChild("Characters")

local settingsFile = "bscripts_settings.json"

local function saveSettings()
    if writefile then
        writefile(settingsFile, HttpService:JSONEncode({
            esp = espEnabled,
            chams = chamsEnabled,
            box = boxEnabled,
            lines = linesEnabled,
            distance = showDistance,
            weapon = showWeapon,
            squad = squadHighlight,
            visibleChams = visibleCheckChams,
            visibleBox = visibleCheckBox,
            optimised = optimisedESP,
        }))
    end
end

local function loadSettings()
    if readfile and isfile and isfile(settingsFile) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(settingsFile))
        end)
        if ok and data then return data end
    end
    return nil
end

local savedSettings = loadSettings()
local function getSetting(name, default)
    if savedSettings and savedSettings[name] ~= nil then
        return savedSettings[name]
    end
    return default
end

espEnabled = getSetting("esp", true)
chamsEnabled = getSetting("chams", true)
boxEnabled = getSetting("box", true)
linesEnabled = getSetting("lines", true)
showDistance = getSetting("distance", true)
showWeapon = getSetting("weapon", true)
squadHighlight = getSetting("squad", true)
visibleCheckChams = getSetting("visibleChams", true)
visibleCheckBox = getSetting("visibleBox", true)
optimisedESP = getSetting("optimised", true)
fullbrightEnabled = false

local originalBrightness = 1
local originalClockTime = 14
local originalFogEnd = 100000
local originalAmbient = Color3.fromRGB(127, 127, 127)
local originalOutdoorAmbient = Color3.fromRGB(127, 127, 127)

task.spawn(function()
    task.wait(0.1)
    originalBrightness = Lighting.Brightness
    originalClockTime = Lighting.ClockTime
    originalFogEnd = Lighting.FogEnd
    originalAmbient = Lighting.Ambient
    originalOutdoorAmbient = Lighting.OutdoorAmbient
end)

local function getSquadMembers()
    local members = {}
    local playerList = localPlayer.PlayerGui:FindFirstChild("PlayerList", true)
    if not playerList then return members end
    local squadList = playerList:FindFirstChild("SquadList", true)
    if not squadList then return members end
    for _, obj in ipairs(squadList:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Name == "NameLabel" and obj.Text ~= "" then
            members[obj.Text] = true
        end
    end
    return members
end

local function isVisible(character)
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local origin = camera.CFrame.Position
    local direction = rootPart.Position - origin
    local rayParams = RaycastParams.new()
    local filter = {character}
    if localPlayer.Character then table.insert(filter, localPlayer.Character) end
    if charactersFolder then
        for _, char in ipairs(charactersFolder:GetChildren()) do
            table.insert(filter, char)
        end
    end
    rayParams.FilterDescendantsInstances = filter
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, rayParams)
    return result == nil
end

local function getEquipped(character)
    local equipped = character:FindFirstChild("Equipped")
    if equipped then
        for _, obj in ipairs(equipped:GetChildren()) do
            if obj:IsA("Model") then return obj.Name end
        end
    end
    local tool = character:FindFirstChildWhichIsA("Tool")
    if tool then return tool.Name end
    return "No Weapon"
end

local function createDrawBox()
    local box = {}
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = false
        box[i] = line
    end
    return box
end

local function updateDrawBox(box, x, y, w, h, color)
    box[1].From = Vector2.new(x, y)
    box[1].To   = Vector2.new(x + w, y)
    box[2].From = Vector2.new(x, y + h)
    box[2].To   = Vector2.new(x + w, y + h)
    box[3].From = Vector2.new(x, y)
    box[3].To   = Vector2.new(x, y + h)
    box[4].From = Vector2.new(x + w, y)
    box[4].To   = Vector2.new(x + w, y + h)
    for i = 1, 4 do
        box[i].Color = color
        box[i].Visible = true
    end
end

local function hideDrawBox(box)
    for i = 1, 4 do
        box[i].Visible = false
    end
end

local function createDrawLine()
    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Transparency = 1
    line.Visible = false
    return line
end

local function getBoxBounds(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3, 0))
    local bot = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
    if top.Z < 0 or bot.Z < 0 then return nil end
    local h = math.abs(top.Y - bot.Y)
    local w = h * 0.6
    local x = top.X - w / 2
    local y = math.min(top.Y, bot.Y)
    return x, y, w, h
end

local function removeESP(player)
    if espData[player] then
        if espData[player].highlight then espData[player].highlight:Destroy() end
        if espData[player].billboardBottom then espData[player].billboardBottom:Destroy() end
        if espData[player].billboardDot then espData[player].billboardDot:Destroy() end
        espData[player] = nil
    end
    if drawBoxes[player] then
        for _, line in ipairs(drawBoxes[player]) do line:Remove() end
        drawBoxes[player] = nil
    end
    if drawLines[player] then
        drawLines[player]:Remove()
        drawLines[player] = nil
    end
    visCache[player] = nil
end

local function addESP(player)
    if player == localPlayer then return end

    local function setupESP(character)
        removeESP(player)

        local humanoid = character:WaitForChild("Humanoid", 5)
        local rootPart = character:WaitForChild("HumanoidRootPart", 5)
        if not humanoid or not rootPart then return end

        local highlight = Instance.new("Highlight")
        highlight.FillTransparency = 0.4
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = Color3.fromRGB(220, 40, 40)
        highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
        highlight.Adornee = character
        highlight.Parent = character

        local billboardBottom = Instance.new("BillboardGui")
        billboardBottom.AlwaysOnTop = true
        billboardBottom.StudsOffsetWorldSpace = Vector3.new(0, -7.5, 0)
        billboardBottom.Size = UDim2.new(0, 100, 0, 30)
        billboardBottom.Adornee = rootPart
        billboardBottom.Parent = rootPart
        billboardBottom.Enabled = false

        local labelDist = Instance.new("TextLabel")
        labelDist.Size = UDim2.new(1, 0, 0.5, 0)
        labelDist.BackgroundTransparency = 1
        labelDist.TextColor3 = Color3.fromRGB(220, 220, 220)
        labelDist.TextStrokeTransparency = 0.3
        labelDist.Font = Enum.Font.GothamMedium
        labelDist.TextSize = 9
        labelDist.Text = "0m"
        labelDist.Parent = billboardBottom

        local labelItem = Instance.new("TextLabel")
        labelItem.Size = UDim2.new(1, 0, 0.5, 0)
        labelItem.Position = UDim2.new(0, 0, 0.5, 0)
        labelItem.BackgroundTransparency = 1
        labelItem.TextColor3 = Color3.fromRGB(255, 200, 60)
        labelItem.TextStrokeTransparency = 0.3
        labelItem.Font = Enum.Font.GothamMedium
        labelItem.TextSize = 9
        labelItem.Text = "No Weapon"
        labelItem.Parent = billboardBottom

        local billboardDot = Instance.new("BillboardGui")
        billboardDot.AlwaysOnTop = true
        billboardDot.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
        billboardDot.Size = UDim2.new(0, 50, 0, 46)
        billboardDot.Adornee = rootPart
        billboardDot.Parent = rootPart
        billboardDot.Enabled = false

        local labelDistDot = Instance.new("TextLabel")
        labelDistDot.Size = UDim2.new(1, 0, 0, 10)
        labelDistDot.BackgroundTransparency = 1
        labelDistDot.TextColor3 = Color3.fromRGB(180, 180, 180)
        labelDistDot.TextStrokeTransparency = 0.4
        labelDistDot.Font = Enum.Font.Gotham
        labelDistDot.TextSize = 8
        labelDistDot.Text = "0m"
        labelDistDot.Parent = billboardDot

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Position = UDim2.new(0.5, -3, 0, 13)
        dot.BackgroundColor3 = Color3.fromRGB(0, 210, 80)
        dot.BorderSizePixel = 0
        dot.Parent = billboardDot

        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot

        local labelName = Instance.new("TextLabel")
        labelName.Size = UDim2.new(1, 0, 0, 10)
        labelName.Position = UDim2.new(0, 0, 0, 23)
        labelName.BackgroundTransparency = 1
        labelName.TextColor3 = Color3.fromRGB(220, 220, 220)
        labelName.TextStrokeTransparency = 0.4
        labelName.Font = Enum.Font.Gotham
        labelName.TextSize = 8
        labelName.Text = player.Name
        labelName.Parent = billboardDot

        local labelTeam = Instance.new("TextLabel")
        labelTeam.Size = UDim2.new(1, 0, 0, 10)
        labelTeam.Position = UDim2.new(0, 0, 0, 34)
        labelTeam.BackgroundTransparency = 1
        labelTeam.TextColor3 = Color3.fromRGB(50, 150, 255)
        labelTeam.TextStrokeTransparency = 0.4
        labelTeam.Font = Enum.Font.Gotham
        labelTeam.TextSize = 8
        labelTeam.Text = "[team]"
        labelTeam.Visible = false
        labelTeam.Parent = billboardDot

        drawBoxes[player] = createDrawBox()
        drawLines[player] = createDrawLine()

        espData[player] = {
            highlight = highlight,
            billboardBottom = billboardBottom,
            billboardDot = billboardDot,
            dot = dot,
            labelDist = labelDist,
            labelItem = labelItem,
            labelDistDot = labelDistDot,
            labelTeam = labelTeam,
            rootPart = rootPart,
            humanoid = humanoid,
            character = character,
        }

        humanoid.Died:Connect(function() removeESP(player) end)
    end

    local character = player.Character
    if not character and charactersFolder then
        character = charactersFolder:FindFirstChild(player.Name)
    end
    if character then setupESP(character) end

    player.CharacterAdded:Connect(function(c) setupESP(c) end)

    if charactersFolder then
        charactersFolder.ChildAdded:Connect(function(child)
            if child.Name == player.Name then setupESP(child) end
        end)
    end
end

local squadMembers = {}
task.spawn(function()
    while true do
        squadMembers = getSquadMembers()
        task.wait(2)
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = localPlayer.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 410)
frame.Position = UDim2.new(0.5, -120, 0.5, -205)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel = 0
frame.ZIndex = 10
frame.Parent = screenGui

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 4)
topBar.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
topBar.BorderSizePixel = 0
topBar.ZIndex = 11
topBar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 36)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.Bangers
title.TextSize = 20
title.Text = "bScripts"
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 16)
subtitle.Position = UDim2.new(0, 10, 0, 26)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = Color3.fromRGB(100, 100, 100)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.Text = "apoc2 v1.1"
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 11
subtitle.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Text = "×"
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 11
closeBtn.Parent = frame

local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, 0, 0, 1)
sep.Position = UDim2.new(0, 0, 0, 42)
sep.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sep.BorderSizePixel = 0
sep.ZIndex = 11
sep.Parent = frame

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, 0, 0, 32)
tabsFrame.Position = UDim2.new(0, 0, 0, 43)
tabsFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
tabsFrame.BorderSizePixel = 0
tabsFrame.ZIndex = 11
tabsFrame.Parent = frame

local tabs = {"Visual", "Misc"}
local tabButtons = {}
local tabContents = {}

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 1, -76)
contentFrame.Position = UDim2.new(0, 0, 0, 76)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 11
contentFrame.Parent = frame

local anyListening = false

local function createCheckbox(parent, labelText, yPos, default, callback, keybindKey, keybindCallback, indent)
    local indentSize = indent and 16 or 0
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20 - indentSize, 0, 28)
    row.Position = UDim2.new(0, 10 + indentSize, 0, yPos)
    row.BackgroundTransparency = 1
    row.ZIndex = 12
    row.Parent = parent

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 16, 0, 16)
    box.Position = UDim2.new(0, 0, 0.5, -8)
    box.BackgroundColor3 = default and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
    box.BorderSizePixel = 1
    box.BorderColor3 = Color3.fromRGB(60, 60, 60)
    box.ZIndex = 13
    box.Parent = row

    local tick = Instance.new("TextLabel")
    tick.Size = UDim2.new(1, 0, 1, 0)
    tick.BackgroundTransparency = 1
    tick.TextColor3 = Color3.fromRGB(255, 255, 255)
    tick.Font = Enum.Font.GothamBold
    tick.TextSize = 12
    tick.Text = default and "✓" or ""
    tick.ZIndex = 14
    tick.Parent = box

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -26 - (keybindKey and 56 or 0), 1, 0)
    label.Position = UDim2.new(0, 26, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = indent and Color3.fromRGB(160, 160, 160) or Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = indent and 11 or 12
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 13
    label.Parent = row

    if keybindKey then
        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 50, 0, 20)
        keyBtn.Position = UDim2.new(1, -50, 0.5, -10)
        keyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        keyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.TextSize = 11
        keyBtn.Text = keybindKey
        keyBtn.BorderSizePixel = 1
        keyBtn.BorderColor3 = Color3.fromRGB(60, 60, 60)
        keyBtn.ZIndex = 16
        keyBtn.Parent = row

        local listening = false
        local currentKey = keybindKey

        keyBtn.MouseButton1Click:Connect(function()
            if anyListening then return end
            listening = true
            anyListening = true
            keyBtn.Text = "..."
            keyBtn.TextColor3 = Color3.fromRGB(88, 101, 242)
            keyBtn.BorderColor3 = Color3.fromRGB(88, 101, 242)
        end)

        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if listening then
                if input.KeyCode == Enum.KeyCode.Unknown then return end
                listening = false
                anyListening = false
                currentKey = input.KeyCode.Name
                keyBtn.Text = currentKey
                keyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                keyBtn.BorderColor3 = Color3.fromRGB(60, 60, 60)
            elseif not gameProcessed and input.KeyCode == Enum.KeyCode[currentKey] then
                if keybindCallback then keybindCallback() end
            end
        end)
    end

    local enabled = default or false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, keybindKey and -56 or 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 15
    btn.Parent = row

    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        box.BackgroundColor3 = enabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
        tick.Text = enabled and "✓" or ""
        if callback then callback(enabled) end
    end)

    return row, box, tick
end

local function createKeybind(parent, labelText, yPos, defaultKey, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 28)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundTransparency = 1
    row.ZIndex = 12
    row.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Text = labelText
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 13
    label.Parent = row

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 50, 0, 20)
    keyBtn.Position = UDim2.new(1, -50, 0.5, -10)
    keyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    keyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 11
    keyBtn.Text = defaultKey
    keyBtn.BorderSizePixel = 1
    keyBtn.BorderColor3 = Color3.fromRGB(60, 60, 60)
    keyBtn.ZIndex = 13
    keyBtn.Parent = row

    local listening = false
    local currentKey = defaultKey

    keyBtn.MouseButton1Click:Connect(function()
        if anyListening then return end
        listening = true
        anyListening = true
        keyBtn.Text = "..."
        keyBtn.TextColor3 = Color3.fromRGB(88, 101, 242)
        keyBtn.BorderColor3 = Color3.fromRGB(88, 101, 242)
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if listening then
            if input.KeyCode == Enum.KeyCode.Unknown then return end
            listening = false
            anyListening = false
            currentKey = input.KeyCode.Name
            keyBtn.Text = currentKey
            keyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            keyBtn.BorderColor3 = Color3.fromRGB(60, 60, 60)
        elseif not gameProcessed and input.KeyCode == Enum.KeyCode[currentKey] then
            if callback then callback() end
        end
    end)
end

local visualContent = Instance.new("Frame")
visualContent.Size = UDim2.new(1, 0, 1, 0)
visualContent.BackgroundTransparency = 1
visualContent.Visible = true
visualContent.ZIndex = 12
visualContent.Parent = contentFrame

local fullbrightConn = nil

local function toggleFullbright(enabled)
    fullbrightEnabled = enabled
    if fullbrightEnabled then
        if fullbrightConn then fullbrightConn:Disconnect() fullbrightConn = nil end
        fullbrightConn = RunService.RenderStepped:Connect(function()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.Ambient = Color3.fromRGB(178, 178, 178)
            Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        end)
    else
        if fullbrightConn then fullbrightConn:Disconnect() fullbrightConn = nil end
        Lighting.Brightness = originalBrightness
        Lighting.ClockTime = originalClockTime
        Lighting.FogEnd = originalFogEnd
        Lighting.Ambient = originalAmbient
        Lighting.OutdoorAmbient = originalOutdoorAmbient
    end
end

local savedChams = chamsEnabled
local savedBox = boxEnabled
local savedLines = linesEnabled
local savedDistance = showDistance
local savedWeapon = showWeapon
local savedSquad = squadHighlight
local chamsBox, chamsTick
local boxBox, boxTick
local linesBox, linesTick
local distBox, distTick
local weaponBox, weaponTick
local squadBox, squadTick
local vcChamsBox, vcChamsTick
local vcBoxBox, vcBoxTick

local function setSubEnabled(enabled)
    chamsEnabled = enabled and savedChams or false
    chamsBox.BackgroundColor3 = chamsEnabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
    chamsTick.Text = chamsEnabled and "✓" or ""
    boxEnabled = enabled and savedBox or false
    boxBox.BackgroundColor3 = boxEnabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
    boxTick.Text = boxEnabled and "✓" or ""
    linesEnabled = enabled and savedLines or false
    linesBox.BackgroundColor3 = linesEnabled and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
    linesTick.Text = linesEnabled and "✓" or ""
    showDistance = enabled and savedDistance or false
    distBox.BackgroundColor3 = showDistance and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
    distTick.Text = showDistance and "✓" or ""
    showWeapon = enabled and savedWeapon or false
    weaponBox.BackgroundColor3 = showWeapon and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
    weaponTick.Text = showWeapon and "✓" or ""
    squadHighlight = enabled and savedSquad or false
    squadBox.BackgroundColor3 = squadHighlight and Color3.fromRGB(88, 101, 242) or Color3.fromRGB(30, 30, 30)
    squadTick.Text = squadHighlight and "✓" or ""
    if not squadHighlight then
        for _, data in pairs(espData) do
            if data.highlight then
                data.highlight.FillColor = Color3.fromRGB(220, 40, 40)
                data.highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
            end
        end
    end
    saveSettings()
end

createCheckbox(visualContent, "ESP", 0, getSetting("esp", true), function(enabled)
    espEnabled = enabled
    setSubEnabled(enabled)
    if not enabled then
        for _, data in pairs(espData) do
            data.highlight.Enabled = false
            data.billboardBottom.Enabled = false
            data.billboardDot.Enabled = false
        end
        for _, box in pairs(drawBoxes) do hideDrawBox(box) end
        for _, line in pairs(drawLines) do line.Visible = false end
    end
    saveSettings()
end)

local _, cBox, cTick = createCheckbox(visualContent, "Chams", 28, getSetting("chams", true), function(enabled)
    savedChams = enabled
    chamsEnabled = enabled
    for _, data in pairs(espData) do data.highlight.Enabled = enabled end
    saveSettings()
end, nil, nil, true)
chamsBox = cBox
chamsTick = cTick

local _, vcCB, vcCT = createCheckbox(visualContent, "Visible Check (Chams)", 56, getSetting("visibleChams", true), function(enabled)
    visibleCheckChams = enabled
    saveSettings()
end, nil, nil, true)
vcChamsBox = vcCB
vcChamsTick = vcCT

local _, bBox, bTick = createCheckbox(visualContent, "Box ESP", 84, getSetting("box", true), function(enabled)
    savedBox = enabled
    boxEnabled = enabled
    if not enabled then
        for _, box in pairs(drawBoxes) do hideDrawBox(box) end
    end
    saveSettings()
end, nil, nil, true)
boxBox = bBox
boxTick = bTick

local _, vcBB, vcBT = createCheckbox(visualContent, "Visible Check (Box)", 112, getSetting("visibleBox", true), function(enabled)
    visibleCheckBox = enabled
    saveSettings()
end, nil, nil, true)
vcBoxBox = vcBB
vcBoxTick = vcBT

local _, lBox, lTick = createCheckbox(visualContent, "Lines", 140, getSetting("lines", true), function(enabled)
    savedLines = enabled
    linesEnabled = enabled
    if not enabled then
        for _, line in pairs(drawLines) do line.Visible = false end
    end
    saveSettings()
end, nil, nil, true)
linesBox = lBox
linesTick = lTick

local _, dBox, dTick = createCheckbox(visualContent, "Show Distance", 168, getSetting("distance", true), function(enabled)
    savedDistance = enabled
    showDistance = enabled
    saveSettings()
end, nil, nil, true)
distBox = dBox
distTick = dTick

local _, wBox, wTick = createCheckbox(visualContent, "Show Weapon", 196, getSetting("weapon", true), function(enabled)
    savedWeapon = enabled
    showWeapon = enabled
    saveSettings()
end, nil, nil, true)
weaponBox = wBox
weaponTick = wTick

local _, sBox, sTick = createCheckbox(visualContent, "Team Check", 224, getSetting("squad", true), function(enabled)
    savedSquad = enabled
    squadHighlight = enabled
    if not enabled then
        for _, data in pairs(espData) do
            if data.highlight then
                data.highlight.FillColor = Color3.fromRGB(220, 40, 40)
                data.highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
            end
        end
    end
    saveSettings()
end, nil, nil, true)
squadBox = sBox
squadTick = sTick

createCheckbox(visualContent, "Optimised ESP (dots >1000m)", 252, getSetting("optimised", true), function(enabled)
    optimisedESP = enabled
    saveSettings()
end)

createCheckbox(visualContent, "Fullbright", 280, getSetting("fullbright", false), function(enabled)
    toggleFullbright(enabled)
end)

local miscContent = Instance.new("Frame")
miscContent.Size = UDim2.new(1, 0, 1, 0)
miscContent.BackgroundTransparency = 1
miscContent.Visible = false
miscContent.ZIndex = 12
miscContent.Parent = contentFrame

createKeybind(miscContent, "Toggle GUI", 0, "PageUp", function()
    frame.Visible = not frame.Visible
end)

local discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(1, -20, 0, 32)
discordBtn.Position = UDim2.new(0, 10, 1, -42)
discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
discordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextSize = 12
discordBtn.Text = "JOIN DISCORD"
discordBtn.BorderSizePixel = 0
discordBtn.ZIndex = 12
discordBtn.Parent = miscContent

discordBtn.MouseButton1Click:Connect(function()
    if setclipboard then
        setclipboard("https://discord.gg/aQUSCJmgxh")
        discordBtn.Text = "LINK COPIED TO CLIPBOARD"
        discordBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 70)
        task.delay(2, function()
            discordBtn.Text = "JOIN DISCORD"
            discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        end)
    end
end)

tabContents = {visualContent, miscContent}

for i, tabName in ipairs(tabs) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1/#tabs, 0, 1, 0)
    tabBtn.Position = UDim2.new((i-1)/#tabs, 0, 0, 0)
    tabBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(10, 10, 10)
    tabBtn.TextColor3 = i == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.TextSize = 11
    tabBtn.Text = tabName
    tabBtn.BorderSizePixel = 0
    tabBtn.ZIndex = 12
    tabBtn.Parent = tabsFrame

    local underline = Instance.new("Frame")
    underline.Size = UDim2.new(1, 0, 0, 2)
    underline.Position = UDim2.new(0, 0, 1, -2)
    underline.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    underline.BorderSizePixel = 0
    underline.Visible = i == 1
    underline.ZIndex = 13
    underline.Parent = tabBtn

    tabButtons[i] = {btn = tabBtn, underline = underline}

    tabBtn.MouseButton1Click:Connect(function()
        for j, content in ipairs(tabContents) do
            content.Visible = false
            tabButtons[j].btn.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
            tabButtons[j].btn.TextColor3 = Color3.fromRGB(100, 100, 100)
            tabButtons[j].underline.Visible = false
        end
        tabContents[i].Visible = true
        tabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        underline.Visible = true
    end)
end

local dragging, dragStart, startPos = false, nil, nil
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)
frame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    frame.Visible = false
end)

RunService.RenderStepped:Connect(function()
    visFrame = visFrame + 1
    local doVis = visFrame % 8 == 0
    local screenSize = camera.ViewportSize

    local localChar = localPlayer.Character
    if not localChar and charactersFolder then
        for _, char in ipairs(charactersFolder:GetChildren()) do
            if char.Name == localPlayer.Name then localChar = char break end
        end
    end

    for player, data in pairs(espData) do
        if not data.character or not data.character.Parent then
            removeESP(player)
            continue
        end

        if not espEnabled then
            data.highlight.Enabled = false
            data.billboardBottom.Enabled = false
            data.billboardDot.Enabled = false
            if drawBoxes[player] then hideDrawBox(drawBoxes[player]) end
            if drawLines[player] then drawLines[player].Visible = false end
            continue
        end

        if not drawBoxes[player] then drawBoxes[player] = createDrawBox() end
        if not drawLines[player] then drawLines[player] = createDrawLine() end

        local dist = 9999
        if localChar and localChar:FindFirstChild("HumanoidRootPart") then
            dist = math.floor((data.rootPart.Position - localChar.HumanoidRootPart.Position).Magnitude)
        end

        if dist > DIST_MAX then
            data.highlight.Enabled = false
            data.billboardBottom.Enabled = false
            data.billboardDot.Enabled = false
            if drawBoxes[player] then hideDrawBox(drawBoxes[player]) end
            if drawLines[player] then drawLines[player].Visible = false end
            visCache[player] = nil
            continue
        end

        if doVis then
            visCache[player] = isVisible(data.character)
        end
        local visible = visCache[player]
        if visible == nil then visible = false end

        local isSquadMate = squadHighlight and squadMembers[player.Name] == true
        local dotMode = optimisedESP and dist >= DIST_DOT

        data.highlight.Enabled = chamsEnabled and not dotMode
        data.billboardBottom.Enabled = (showDistance or showWeapon) and not dotMode
        data.billboardDot.Enabled = optimisedESP and dotMode

        local espColor = isSquadMate and Color3.fromRGB(50, 150, 255)
            or visible and Color3.fromRGB(0, 255, 100)
            or Color3.fromRGB(255, 60, 60)

        local rootScreen, onScreen = camera:WorldToViewportPoint(data.rootPart.Position)
        if linesEnabled and onScreen and rootScreen.Z > 0 then
            drawLines[player].From = Vector2.new(screenSize.X / 2, screenSize.Y)
            drawLines[player].To = Vector2.new(rootScreen.X, rootScreen.Y)
            drawLines[player].Color = espColor
            drawLines[player].Visible = true
        else
            drawLines[player].Visible = false
        end

        if boxEnabled and not dotMode then
            local x, y, w, h = getBoxBounds(data.character)
            if x then
                local boxColor = isSquadMate and Color3.fromRGB(50, 150, 255)
                    or visibleCheckBox and espColor
                    or Color3.fromRGB(255, 60, 60)
                updateDrawBox(drawBoxes[player], x, y, w, h, boxColor)
            else
                hideDrawBox(drawBoxes[player])
            end
        else
            hideDrawBox(drawBoxes[player])
        end

        if dotMode then
            data.labelTeam.Visible = isSquadMate
            if isSquadMate then
                data.dot.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            else
                local t2 = math.clamp((dist - 1000) / 4000, 0, 1)
                data.dot.BackgroundColor3 = Color3.fromRGB(math.floor((1-t2)*220), math.floor(t2*210), 0)
            end
            data.labelDistDot.Text = showDistance and dist .. "m" or ""
        else
            local scale = math.clamp(40 / math.max(dist, 1), 0.4, 1.8)
            data.billboardBottom.Size = UDim2.new(0, math.floor(100*scale), 0, math.floor(30*scale))
            data.labelDist.TextSize = math.clamp(math.floor(9*scale), 7, 13)
            data.labelItem.TextSize = math.clamp(math.floor(9*scale), 7, 13)
            data.labelDist.Text = showDistance and dist .. "m" or ""
            data.labelItem.Text = showWeapon and getEquipped(data.character) or ""

            if isSquadMate then
                data.highlight.FillColor = Color3.fromRGB(0, 100, 255)
                data.highlight.OutlineColor = Color3.fromRGB(50, 150, 255)
            elseif visibleCheckChams then
                if visible then
                    data.highlight.FillColor = Color3.fromRGB(0, 210, 80)
                    data.highlight.OutlineColor = Color3.fromRGB(0, 255, 100)
                else
                    data.highlight.FillColor = Color3.fromRGB(220, 40, 40)
                    data.highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
                end
            else
                data.highlight.FillColor = Color3.fromRGB(220, 40, 40)
                data.highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
            end
        end
    end
end)

Players.PlayerAdded:Connect(addESP)
Players.PlayerRemoving:Connect(removeESP)

for _, player in ipairs(Players:GetPlayers()) do
    addESP(player)
end

print("bScripts loaded!")
