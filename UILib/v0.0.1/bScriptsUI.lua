--[[
v0.0.1
]]

local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Library = {}
Library.__index = Library

-- Colours / fonts lifted directly from the original script
Library.Theme = {
    Accent      = Color3.fromRGB(88, 101, 242),
    Background  = Color3.fromRGB(15, 15, 15),
    Surface     = Color3.fromRGB(30, 30, 30),
    Border      = Color3.fromRGB(60, 60, 60),
    TabBar      = Color3.fromRGB(10, 10, 10),
    TabActive   = Color3.fromRGB(20, 20, 20),
    Text        = Color3.fromRGB(200, 200, 200),
    TextDim     = Color3.fromRGB(160, 160, 160),
    TextButton  = Color3.fromRGB(220, 220, 220),
    Heading     = Color3.fromRGB(180, 180, 180),
    Body        = Color3.fromRGB(140, 140, 140),
    Muted       = Color3.fromRGB(120, 120, 120),
    Subtitle    = Color3.fromRGB(100, 100, 100),
    White       = Color3.fromRGB(255, 255, 255),
    TitleFont   = Enum.Font.Bangers,
}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local anyListening = false

local function parentGui(gui)
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = obj
    return c
end

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------
function Library:CreateWindow(opts)
    opts = opts or {}
    local T = Library.Theme
    local self = setmetatable({}, Window)

    self.Tabs = {}
    self._conns = {}
    self._title = opts.Title or "bScripts"
    self._subtitle = opts.Subtitle or ""
    self._version = opts.Version

    local size = opts.Size or Vector2.new(280, 560)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = opts.Name or "bScriptsUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    parentGui(screenGui)
    self.ScreenGui = screenGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, size.X, 0, size.Y)
    frame.Position = UDim2.new(0.5, -size.X / 2, 0.5, -size.Y / 2)
    frame.BackgroundColor3 = T.Background
    frame.BorderSizePixel = 0
    frame.ZIndex = 10
    frame.Parent = screenGui
    corner(frame, 6)
    self.Frame = frame

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 4)
    topBar.BackgroundColor3 = T.Accent
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 11
    topBar.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 36)
    title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1
    title.TextColor3 = T.White
    title.Font = T.TitleFont
    title.TextSize = 20
    title.Text = self._title
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 11
    title.Parent = frame
    self.TitleLabel = title

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 16)
    subtitle.Position = UDim2.new(0, 10, 0, 26)
    subtitle.BackgroundTransparency = 1
    subtitle.TextColor3 = T.Subtitle
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 11
    subtitle.Parent = frame
    self.SubtitleLabel = subtitle
    self:_refreshSubtitle()

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -34, 0, 8)
    closeBtn.BackgroundColor3 = T.Surface
    closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.Text = "×"
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 11
    closeBtn.Parent = frame
    closeBtn.MouseButton1Click:Connect(function() frame.Visible = false end)

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.Position = UDim2.new(0, 0, 0, 42)
    sep.BackgroundColor3 = T.Surface
    sep.BorderSizePixel = 0
    sep.ZIndex = 11
    sep.Parent = frame

    local tabsFrame = Instance.new("Frame")
    tabsFrame.Size = UDim2.new(1, 0, 0, 32)
    tabsFrame.Position = UDim2.new(0, 0, 0, 43)
    tabsFrame.BackgroundColor3 = T.TabBar
    tabsFrame.BorderSizePixel = 0
    tabsFrame.ZIndex = 11
    tabsFrame.Parent = frame
    self.TabsFrame = tabsFrame

    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, -76)
    contentFrame.Position = UDim2.new(0, 0, 0, 76)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ZIndex = 11
    contentFrame.Parent = frame
    self.ContentFrame = contentFrame

    -- Dragging (same behaviour as the original)
    local dragging, dragStart, startPos = false, nil, nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and not self._sliderActive then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    -- Optional toggle key
    if opts.ToggleKey then
        local key = opts.ToggleKey
        table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, gp)
            if not gp and not anyListening and input.KeyCode == Enum.KeyCode[key] then
                self:Toggle()
            end
        end))
    end

    return self
end

function Window:_refreshSubtitle()
    local parts = {}
    if self._subtitle and self._subtitle ~= "" then table.insert(parts, self._subtitle) end
    if self._version and self._version ~= "" then
        local v = tostring(self._version)
        if v:sub(1, 1):lower() ~= "v" then v = "v" .. v end
        table.insert(parts, v)
    end
    self.SubtitleLabel.Text = table.concat(parts, " · ")
end

function Window:SetTitle(text)
    self._title = text
    self.TitleLabel.Text = text
end

function Window:SetSubtitle(text)
    self._subtitle = text
    self:_refreshSubtitle()
end

function Window:SetVersion(text)
    self._version = text
    self:_refreshSubtitle()
end

function Window:Toggle() self.Frame.Visible = not self.Frame.Visible end
function Window:Show() self.Frame.Visible = true end
function Window:Hide() self.Frame.Visible = false end

function Window:Destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self.ScreenGui:Destroy()
end

function Window:SelectTab(index)
    local T = Library.Theme
    for i, tab in ipairs(self.Tabs) do
        local active = i == index
        tab.Content.Visible = active
        tab.Button.BackgroundColor3 = active and T.TabActive or T.TabBar
        tab.Button.TextColor3 = active and T.White or T.Subtitle
        tab.Underline.Visible = active
    end
end

function Window:AddTab(name)
    local T = Library.Theme
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = name
    tab._y = 4
    tab._conns = self._conns

    local index = #self.Tabs + 1
    table.insert(self.Tabs, tab)

    -- content (scrolling so any amount of elements fits)
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible = index == 1
    content.ZIndex = 12
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.Parent = self.ContentFrame
    tab.Content = content

    -- tab button
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = index == 1 and T.TabActive or T.TabBar
    btn.TextColor3 = index == 1 and T.White or T.Subtitle
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Text = name
    btn.BorderSizePixel = 0
    btn.ZIndex = 12
    btn.Parent = self.TabsFrame
    tab.Button = btn

    local underline = Instance.new("Frame")
    underline.Size = UDim2.new(1, 0, 0, 2)
    underline.Position = UDim2.new(0, 0, 1, -2)
    underline.BackgroundColor3 = T.Accent
    underline.BorderSizePixel = 0
    underline.Visible = index == 1
    underline.ZIndex = 13
    underline.Parent = btn
    tab.Underline = underline

    btn.MouseButton1Click:Connect(function() self:SelectTab(index) end)

    -- re-space all tab buttons evenly
    local n = #self.Tabs
    for i, t in ipairs(self.Tabs) do
        t.Button.Size = UDim2.new(1 / n, 0, 1, 0)
        t.Button.Position = UDim2.new((i - 1) / n, 0, 0, 0)
    end

    return tab
end

----------------------------------------------------------------
-- TAB ELEMENTS
----------------------------------------------------------------
function Tab:_place(height)
    local y = self._y
    self._y = y + height
    self.Content.CanvasSize = UDim2.new(0, 0, 0, self._y + 4)
    return y
end

local function newRow(tab, height, indentSize)
    indentSize = indentSize or 0
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20 - indentSize, 0, height)
    row.Position = UDim2.new(0, 10 + indentSize, 0, tab:_place(height))
    row.BackgroundTransparency = 1
    row.ZIndex = 12
    row.Parent = tab.Content
    return row
end

local function newText(parent, text, font, size, color, z)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.TextColor3 = color
    l.Font = font
    l.TextSize = size
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = z or 13
    l.Parent = parent
    return l
end

-- Toggle (the original "checkbox")
function Tab:AddToggle(text, default, callback, indent)
    local T = Library.Theme
    local row = newRow(self, 22, indent and 14 or 0)

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 14, 0, 14)
    box.Position = UDim2.new(0, 0, 0.5, -7)
    box.BackgroundColor3 = default and T.Accent or T.Surface
    box.BorderSizePixel = 1
    box.BorderColor3 = T.Border
    box.ZIndex = 13
    box.Parent = row

    local tick = Instance.new("TextLabel")
    tick.Size = UDim2.new(1, 0, 1, 0)
    tick.BackgroundTransparency = 1
    tick.TextColor3 = T.White
    tick.Font = Enum.Font.GothamBold
    tick.TextSize = 10
    tick.Text = default and "✓" or ""
    tick.ZIndex = 14
    tick.Parent = box

    local label = newText(row, text, Enum.Font.Gotham, indent and 11 or 12,
        indent and T.TextDim or T.Text)
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 20, 0, 0)

    local enabled = default or false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 15
    btn.Parent = row

    local obj = { Frame = row, Label = label }
    local function apply(v)
        enabled = v
        box.BackgroundColor3 = v and T.Accent or T.Surface
        tick.Text = v and "✓" or ""
    end
    btn.MouseButton1Click:Connect(function()
        apply(not enabled)
        if callback then callback(enabled) end
    end)
    function obj:Set(v, silent)
        apply(v and true or false)
        if callback and not silent then callback(enabled) end
    end
    function obj:Get() return enabled end
    function obj:SetText(t) label.Text = t end
    return obj
end

-- Slider
-- opts: Increment (default 1), Suffix (default "")
function Tab:AddSlider(text, min, max, default, callback, opts)
    opts = opts or {}
    local T = Library.Theme
    local inc = opts.Increment or 1
    local suffix = opts.Suffix or ""
    local row = newRow(self, 34)

    local label = newText(row, text, Enum.Font.Gotham, 12, T.Text)
    label.Size = UDim2.new(0.6, 0, 0, 18)

    local valueLbl = newText(row, "", Enum.Font.GothamBold, 11, T.TextButton)
    valueLbl.Size = UDim2.new(0.4, 0, 0, 18)
    valueLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 4)
    track.Position = UDim2.new(0, 0, 0, 24)
    track.BackgroundColor3 = T.Surface
    track.BorderSizePixel = 1
    track.BorderColor3 = T.Border
    track.ZIndex = 13
    track.Parent = row

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = T.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 14
    fill.Parent = track

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 0, 16)
    hit.Position = UDim2.new(0, 0, 0, 18)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 15
    hit.Parent = row

    local decimals = 0
    do
        local s = tostring(inc)
        local dot = s:find("%.")
        if dot then decimals = #s - dot end
    end

    local value = math.clamp(default or min, min, max)
    local function render()
        local alpha = (max - min) == 0 and 0 or (value - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        valueLbl.Text = string.format("%." .. decimals .. "f", value) .. suffix
    end
    render()

    local function setFromX(x, silent)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = min + rel * (max - min)
        v = math.floor(v / inc + 0.5) * inc
        v = math.clamp(v, min, max)
        if v ~= value then
            value = v
            render()
            if callback and not silent then callback(value) end
        end
    end

    local sliding = false
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            self.Window._sliderActive = true
            setFromX(input.Position.X)
        end
    end)
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end))
    table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            sliding = false
            self.Window._sliderActive = false
        end
    end))

    local obj = { Frame = row, Label = label }
    function obj:Set(v, silent)
        value = math.clamp(v, min, max)
        render()
        if callback and not silent then callback(value) end
    end
    function obj:Get() return value end
    return obj
end

-- Dropdown (click to cycle, like the original)
function Tab:AddDropdown(text, options, current, callback)
    local T = Library.Theme
    local row = newRow(self, 22)

    local label = newText(row, text, Enum.Font.Gotham, 12, T.Text)
    label.Size = UDim2.new(0.45, 0, 1, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5, 0, 0, 18)
    btn.Position = UDim2.new(0.5, 0, 0.5, -9)
    btn.BackgroundColor3 = T.Surface
    btn.TextColor3 = T.TextButton
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Text = tostring(current)
    btn.BorderSizePixel = 1
    btn.BorderColor3 = T.Border
    btn.ZIndex = 13
    btn.Parent = row

    local idx = 1
    for i, o in ipairs(options) do if o == current then idx = i break end end

    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        btn.Text = options[idx]
        if callback then callback(options[idx]) end
    end)

    local obj = { Frame = row, Label = label }
    function obj:Set(v, silent)
        for i, o in ipairs(options) do
            if o == v then
                idx = i
                btn.Text = tostring(v)
                if callback and not silent then callback(v) end
                return
            end
        end
    end
    function obj:Get() return options[idx] end
    return obj
end

-- Keybind (click, then press a key; callback fires when that key is pressed)
function Tab:AddKeybind(text, defaultKey, callback)
    local T = Library.Theme
    local row = newRow(self, 24)

    local label = newText(row, text, Enum.Font.Gotham, 12, T.Text)
    label.Size = UDim2.new(1, -60, 1, 0)

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 52, 0, 18)
    keyBtn.Position = UDim2.new(1, -52, 0.5, -9)
    keyBtn.BackgroundColor3 = T.Surface
    keyBtn.TextColor3 = T.Text
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 11
    keyBtn.Text = defaultKey
    keyBtn.BorderSizePixel = 1
    keyBtn.BorderColor3 = T.Border
    keyBtn.ZIndex = 13
    keyBtn.Parent = row

    local listening, currentKey = false, defaultKey
    keyBtn.MouseButton1Click:Connect(function()
        if anyListening then return end
        listening = true
        anyListening = true
        keyBtn.Text = "..."
        keyBtn.TextColor3 = T.Accent
    end)
    table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, gp)
        if listening then
            if input.KeyCode == Enum.KeyCode.Unknown then return end
            listening = false
            anyListening = false
            currentKey = input.KeyCode.Name
            keyBtn.Text = currentKey
            keyBtn.TextColor3 = T.Text
        elseif not gp and input.KeyCode == Enum.KeyCode[currentKey] then
            if callback then callback() end
        end
    end))

    local obj = { Frame = row, Label = label }
    function obj:Get() return currentKey end
    function obj:Set(k)
        currentKey = k
        keyBtn.Text = k
    end
    return obj
end

-- Button (full width, accent coloured, like the Discord button)
-- opts: Color (Color3), Height (number)
function Tab:AddButton(text, callback, opts)
    opts = opts or {}
    local T = Library.Theme
    local height = opts.Height or 32
    local row = newRow(self, height + 8)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, height)
    btn.BackgroundColor3 = opts.Color or T.Accent
    btn.TextColor3 = T.White
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = text
    btn.BorderSizePixel = 0
    btn.ZIndex = 12
    btn.Parent = row

    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    local obj = { Frame = row, Button = btn }
    function obj:SetText(t) btn.Text = t end
    function obj:Flash(t, seconds)
        local old = btn.Text
        btn.Text = t
        task.delay(seconds or 2, function() btn.Text = old end)
    end
    return obj
end

-- Heading (section title, e.g. "Credits")
function Tab:AddHeading(text)
    local T = Library.Theme
    local row = newRow(self, 22)
    local l = newText(row, text, Enum.Font.GothamBold, 13, T.Heading, 12)
    l.Size = UDim2.new(1, 0, 1, 0)
    local obj = { Frame = row, Label = l }
    function obj:SetText(t) l.Text = t end
    return obj
end

-- Label (small grey status text, e.g. "P:0 Z:0 V:0")
-- height is optional (default 18); wrap lines by increasing it
function Tab:AddLabel(text, height)
    local T = Library.Theme
    height = height or 18
    local row = newRow(self, height)
    local l = newText(row, text, Enum.Font.Gotham, 11, T.Muted, 12)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    local obj = { Frame = row, Label = l }
    function obj:SetText(t) l.Text = t end
    function obj:Get() return l.Text end
    return obj
end

-- Paragraph (body text, e.g. the credits text). height optional (default 50)
function Tab:AddParagraph(text, height)
    local T = Library.Theme
    height = height or 50
    local row = newRow(self, height)
    local l = newText(row, text, Enum.Font.Gotham, 12, T.Body, 12)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    local obj = { Frame = row, Label = l }
    function obj:SetText(t) l.Text = t end
    return obj
end

-- Separator line
function Tab:AddSeparator()
    local T = Library.Theme
    local row = newRow(self, 8)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = T.Surface
    line.BorderSizePixel = 0
    line.ZIndex = 12
    line.Parent = row
    return { Frame = row }
end

-- Blank vertical space
function Tab:AddSpacer(height)
    self:_place(height or 8)
end

return Library
