--[[
   
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Library = {
    Version = "2.0.0",
    Flags = {},
    Elements = {},
    ConfigFolder = "bScriptsUI",
    _windows = {},
    _loaded = {},
}
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
    Success     = Color3.fromRGB(80, 200, 120),
    Warning     = Color3.fromRGB(240, 180, 60),
    Danger      = Color3.fromRGB(237, 66, 69),
    TitleFont   = Enum.Font.Bangers,
}

Library.Themes = {
    Default = {},
    Crimson = { Accent = Color3.fromRGB(237, 66, 69) },
    Emerald = { Accent = Color3.fromRGB(46, 204, 113) },
    Ocean   = { Accent = Color3.fromRGB(52, 152, 219) },
    Amber   = { Accent = Color3.fromRGB(241, 196, 15) },
    Violet  = { Accent = Color3.fromRGB(155, 89, 182) },
    Rose    = { Accent = Color3.fromRGB(255, 105, 180) },
    Mono    = { Accent = Color3.fromRGB(210, 210, 210) },
}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local anyListening = false

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function copy(t)
    local n = {}
    for k, v in pairs(t) do n[k] = v end
    return n
end

local function safe(name, fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn(string.format("[bScriptsUI] callback error in '%s': %s", tostring(name), tostring(err)))
    end
end

local function tween(obj, props, t)
    local ok, tw = pcall(function()
        return TweenService:Create(obj, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and tw then tw:Play() end
end

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = obj
    return c
end

local function parentGui(gui, protect)
    local ok = false
    if protect ~= false then
        if gethui then
            ok = pcall(function() gui.Parent = gethui() end)
        end
        if not ok or not gui.Parent then
            pcall(function()
                if syn and syn.protect_gui then syn.protect_gui(gui) end
            end)
            pcall(function() gui.Parent = CoreGui end)
        end
    else
        pcall(function() gui.Parent = CoreGui end)
    end
    if not gui.Parent then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function round(n) return math.floor(n + 0.5) end

local function colorToTable(c)
    return { R = round(c.R * 255), G = round(c.G * 255), B = round(c.B * 255) }
end

local function tableToColor(t)
    if type(t) == "table" and tonumber(t.R) and tonumber(t.G) and tonumber(t.B) then
        return Color3.fromRGB(t.R, t.G, t.B)
    end
end

----------------------------------------------------------------
-- FLAGS / CONFIG
----------------------------------------------------------------
function Library:_initial(flag, default, de)
    if flag and Library._loaded[flag] ~= nil then
        local v
        if de then v = de(Library._loaded[flag]) else v = Library._loaded[flag] end
        if v ~= nil then return v, true end
    end
    return default, false
end

function Library:_register(flag, obj, value)
    if not flag then return end
    Library.Elements[flag] = obj
    Library.Flags[flag] = value
end

function Library:_commit(flag, value)
    if not flag then return end
    Library.Flags[flag] = value
    local a = Library._autosave
    if a and a.name then
        a.token = (a.token or 0) + 1
        local t = a.token
        task.delay(1, function()
            if Library._autosave and Library._autosave.token == t then
                Library:SaveConfig(Library._autosave.name)
            end
        end)
    end
end

local function fsReady()
    return writefile and readfile and isfile and true or false
end

local function cleanName(name)
    return (tostring(name or ""):gsub("[^%w_%- ]", ""))
end

local function configPath(name)
    return Library.ConfigFolder .. "/" .. cleanName(name) .. ".json"
end

local function ensureFolder()
    pcall(function()
        if makefolder and isfolder and not isfolder(Library.ConfigFolder) then
            makefolder(Library.ConfigFolder)
        end
    end)
end

function Library:SerializeFlags()
    local out = {}
    for flag, obj in pairs(Library.Elements) do
        if obj._ser then out[flag] = obj._ser() end
    end
    return out
end

function Library:SaveConfig(name)
    if cleanName(name) == "" then return false, "invalid name" end
    if not fsReady() then return false, "executor has no file functions" end
    ensureFolder()
    local ok, err = pcall(function()
        writefile(configPath(name), HttpService:JSONEncode(Library:SerializeFlags()))
    end)
    return ok, err
end

function Library:LoadConfig(name)
    if cleanName(name) == "" then return false, "invalid name" end
    if not fsReady() then return false, "executor has no file functions" end
    local path = configPath(name)
    if not isfile(path) then return false, "config not found" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false, "config is corrupted" end
    for flag, raw in pairs(data) do
        local obj = Library.Elements[flag]
        if obj and obj._de then
            local v = obj._de(raw)
            if v ~= nil then obj:Set(v) end
        end
    end
    return true
end

function Library:DeleteConfig(name)
    if not (delfile and isfile) then return false, "executor has no delfile" end
    local path = configPath(name)
    if not isfile(path) then return false, "config not found" end
    return pcall(delfile, path)
end

function Library:ListConfigs()
    local out = {}
    if not listfiles then return out end
    ensureFolder()
    local ok, files = pcall(listfiles, Library.ConfigFolder)
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
    end
    table.sort(out)
    return out
end

function Library:SetAutoSave(name)
    if not name then
        Library._autosave = nil
        return
    end
    Library._autosave = { name = name, token = 0 }
    if fsReady() and isfile(configPath(name)) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(configPath(name))) end)
        if ok and type(data) == "table" then Library._loaded = data end
    end
end

function Library:Notify(opts)
    local w = Library._windows[#Library._windows]
    if w then w:Notify(opts) end
end

function Library:Unload()
    for i = #Library._windows, 1, -1 do
        Library._windows[i]:Destroy()
    end
end

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------
function Window:_themed(fn)
    fn()
    table.insert(self._themeFns, fn)
end

local function bind(win, inst, prop, key)
    win:_themed(function() inst[prop] = win.Theme[key] end)
end

function Window:_screenPos(input)
    local inset = Vector2.new(0, 0)
    if not self.ScreenGui.IgnoreGuiInset then
        local ok, i = pcall(function() return GuiService:GetGuiInset() end)
        if ok then inset = i end
    end
    return Vector2.new(input.Position.X, input.Position.Y) + inset
end

function Library:CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({}, Window)

    self.Tabs = {}
    self._conns = {}
    self._themeFns = {}
    self._title = opts.Title or "bScripts"
    self._subtitle = opts.Subtitle or ""
    self._version = opts.Version
    self._tipToken = 0
    self._toasts = {}
    self._toastCount = 0
    self.Theme = copy(Library.Theme)

    if opts.Theme then
        local preset = type(opts.Theme) == "string" and Library.Themes[opts.Theme] or opts.Theme
        if type(preset) == "table" then
            for k, v in pairs(preset) do self.Theme[k] = v end
        end
    end
    local T = self.Theme

    if opts.AutoSave then Library:SetAutoSave(opts.AutoSave) end

    local size = opts.Size or Vector2.new(280, 560)
    self._fullH = size.Y

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = opts.Name or "bScriptsUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    parentGui(screenGui, opts.Protect)
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
    closeBtn.MouseButton1Click:Connect(function() self:Hide() end)

    local minBtn
    if opts.Minimise ~= false then
        minBtn = Instance.new("TextButton")
        minBtn.Size = UDim2.new(0, 28, 0, 28)
        minBtn.Position = UDim2.new(1, -66, 0, 8)
        minBtn.BackgroundColor3 = T.Surface
        minBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
        minBtn.Font = Enum.Font.GothamBold
        minBtn.TextSize = 14
        minBtn.Text = "–"
        minBtn.BorderSizePixel = 0
        minBtn.ZIndex = 11
        minBtn.Parent = frame
        minBtn.MouseButton1Click:Connect(function() self:SetMinimised(not self.Minimised) end)
    end

    for _, b in ipairs({ closeBtn, minBtn }) do
        if b then
            b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = self.Theme.Border }) end)
            b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = self.Theme.Surface }) end)
        end
    end

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

    self:_themed(function()
        frame.BackgroundColor3 = self.Theme.Background
        topBar.BackgroundColor3 = self.Theme.Accent
        title.TextColor3 = self.Theme.White
        subtitle.TextColor3 = self.Theme.Subtitle
        closeBtn.BackgroundColor3 = self.Theme.Surface
        if minBtn then minBtn.BackgroundColor3 = self.Theme.Surface end
        sep.BackgroundColor3 = self.Theme.Surface
        tabsFrame.BackgroundColor3 = self.Theme.TabBar
    end)

    -- Overlay (popups, tooltips, toasts) -- sits above the window
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    overlay.Parent = screenGui
    self.Overlay = overlay

    -- Tooltip
    local tip = Instance.new("Frame")
    tip.BackgroundColor3 = T.Surface
    tip.BorderSizePixel = 1
    tip.BorderColor3 = T.Border
    tip.Visible = false
    tip.ZIndex = 200
    tip.Parent = overlay
    local tipLbl = Instance.new("TextLabel")
    tipLbl.BackgroundTransparency = 1
    tipLbl.Position = UDim2.new(0, 6, 0, 3)
    tipLbl.TextColor3 = T.Text
    tipLbl.Font = Enum.Font.Gotham
    tipLbl.TextSize = 11
    tipLbl.TextXAlignment = Enum.TextXAlignment.Left
    tipLbl.TextYAlignment = Enum.TextYAlignment.Top
    tipLbl.TextWrapped = true
    tipLbl.ZIndex = 201
    tipLbl.Parent = tip
    self.TipFrame, self.TipLabel = tip, tipLbl
    self:_themed(function()
        tip.BackgroundColor3 = self.Theme.Surface
        tip.BorderColor3 = self.Theme.Border
        tipLbl.TextColor3 = self.Theme.Text
    end)

    -- Notification holder
    local holder = Instance.new("Frame")
    holder.AnchorPoint = Vector2.new(1, 1)
    holder.Position = UDim2.new(1, -12, 1, -12)
    holder.Size = UDim2.new(0, 240, 1, -24)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 150
    holder.Parent = overlay
    local list = Instance.new("UIListLayout")
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)
    list.Parent = holder
    self.ToastHolder = holder

    -- Dragging (mouse + touch), with screen clamp
    local dragging, dragStart, startPos = false, nil, nil
    local function clamp()
        pcall(function()
            local sg = screenGui.AbsoluteSize
            local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
            local cx = math.clamp(ap.X, -(as.X - 60), sg.X - 60)
            local cy = math.clamp(ap.Y, 0, sg.Y - 30)
            if cx ~= ap.X or cy ~= ap.Y then
                frame.Position = frame.Position + UDim2.fromOffset(cx - ap.X, cy - ap.Y)
            end
        end)
    end
    local function isPointer(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end
    frame.InputBegan:Connect(function(input)
        if isPointer(input) then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            task.defer(function()
                if self._busy then dragging = false end
            end)
        end
    end)
    frame.InputEnded:Connect(function(input)
        if isPointer(input) then
            if dragging then clamp() end
            dragging = false
        end
    end)
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if dragging and not self._busy and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    -- Resize handle
    if opts.Resizable ~= false then
        local grip = Instance.new("TextButton")
        grip.Size = UDim2.new(0, 16, 0, 16)
        grip.Position = UDim2.new(1, -16, 1, -16)
        grip.BackgroundTransparency = 1
        grip.Text = "◢"
        grip.TextSize = 10
        grip.Font = Enum.Font.Gotham
        grip.TextColor3 = T.Subtitle
        grip.ZIndex = 30
        grip.Parent = frame
        bind(self, grip, "TextColor3", "Subtitle")
        self._grip = grip

        local resizing, rStart, rSize = false, nil, nil
        local minW, minH = opts.MinSize and opts.MinSize.X or 220, opts.MinSize and opts.MinSize.Y or 200
        grip.InputBegan:Connect(function(input)
            if isPointer(input) then
                resizing = true
                self._busy = true
                rStart = input.Position
                rSize = frame.AbsoluteSize
            end
        end)
        table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - rStart
                local sg = screenGui.AbsoluteSize
                local w = math.clamp(rSize.X + d.X, minW, math.max(minW, sg.X))
                local h = math.clamp(rSize.Y + d.Y, minH, math.max(minH, sg.Y))
                frame.Size = UDim2.fromOffset(w, h)
                self._fullH = h
            end
        end))
        table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
            if resizing and isPointer(input) then
                resizing = false
                self._busy = false
            end
        end))
    end

    -- Popup outside-click closing
    table.insert(self._conns, UserInputService.InputBegan:Connect(function(input)
        if self._popup and isPointer(input) then
            local sp = self:_screenPos(input)
            local fp, fs = self._popup.frame.AbsolutePosition, self._popup.frame.AbsoluteSize
            local inside = sp.X >= fp.X and sp.X <= fp.X + fs.X and sp.Y >= fp.Y and sp.Y <= fp.Y + fs.Y
            if not inside then
                self._lastClose = { owner = self._popup.owner, time = tick() }
                self:_closePopup()
            end
        end
    end))

    -- Tooltip follows the mouse
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if tip.Visible and input.UserInputType == Enum.UserInputType.MouseMovement then
            self:_placeTip(self:_screenPos(input))
        end
    end))

    -- Optional toggle key
    if opts.ToggleKey then
        local key = opts.ToggleKey
        table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, gp)
            if not gp and not anyListening and input.KeyCode.Name == key then
                self:Toggle()
            end
        end))
    end

    -- Mobile toggle button
    local mobile = opts.MobileButton
    if mobile == nil then
        mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end
    if mobile then
        local mb = Instance.new("TextButton")
        mb.Size = UDim2.new(0, 44, 0, 44)
        mb.Position = UDim2.new(0, 10, 0.4, 0)
        mb.BackgroundColor3 = T.Accent
        mb.TextColor3 = T.White
        mb.Font = Enum.Font.GothamBold
        mb.TextSize = 18
        mb.Text = "☰"
        mb.BorderSizePixel = 0
        mb.ZIndex = 50
        mb.Parent = screenGui
        corner(mb, 22)
        bind(self, mb, "BackgroundColor3", "Accent")
        mb.MouseButton1Click:Connect(function() self:Toggle() end)
        self._mobileBtn = mb
    end

    table.insert(Library._windows, self)
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

function Window:Toggle()
    if self.Frame.Visible then self:Hide() else self:Show() end
end
function Window:Show() self.Frame.Visible = true end
function Window:Hide()
    self:_closePopup()
    self.TipFrame.Visible = false
    self.Frame.Visible = false
end

function Window:SetMinimised(state)
    state = state and true or false
    if state == self.Minimised then return end
    self.Minimised = state
    self:_closePopup()
    local f = self.Frame
    local w = f.Size.X
    if state then
        self.TabsFrame.Visible = false
        self.ContentFrame.Visible = false
        if self._grip then self._grip.Visible = false end
        tween(f, { Size = UDim2.new(w.Scale, w.Offset, 0, 44) }, 0.15)
    else
        tween(f, { Size = UDim2.new(w.Scale, w.Offset, 0, self._fullH) }, 0.15)
        task.delay(0.15, function()
            if self.Minimised or self._destroyed then return end
            self.TabsFrame.Visible = true
            self.ContentFrame.Visible = true
            if self._grip then self._grip.Visible = true end
        end)
    end
end

function Window:Destroy()
    self._destroyed = true
    self:_closePopup()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for flag, obj in pairs(Library.Elements) do
        if obj.Window == self then
            Library.Elements[flag] = nil
            Library.Flags[flag] = nil
        end
    end
    for i, w in ipairs(Library._windows) do
        if w == self then table.remove(Library._windows, i) break end
    end
    self.ScreenGui:Destroy()
end

----------------------------------------------------------------
-- THEMING
----------------------------------------------------------------
function Window:SetTheme(t)
    local preset = type(t) == "string" and Library.Themes[t] or t
    if type(preset) ~= "table" then
        warn("[bScriptsUI] unknown theme: " .. tostring(t))
        return
    end
    local fresh = copy(Library.Theme)
    for k, v in pairs(preset) do fresh[k] = v end
    for k, v in pairs(fresh) do self.Theme[k] = v end
    self:_closePopup()
    for _, fn in ipairs(self._themeFns) do pcall(fn) end
end

function Window:SetAccent(color)
    self.Theme.Accent = color
    for _, fn in ipairs(self._themeFns) do pcall(fn) end
end

----------------------------------------------------------------
-- POPUPS / TOOLTIPS / NOTIFICATIONS
----------------------------------------------------------------
function Window:_closePopup()
    local p = self._popup
    if not p then return end
    self._popup = nil
    if p.close then pcall(p.close) end
    if p.frame then p.frame:Destroy() end
    if p.conns then
        for _, c in ipairs(p.conns) do pcall(function() c:Disconnect() end) end
    end
    self._busy = false
end

function Window:_setPopup(frame, owner, conns, close)
    self:_closePopup()
    self._popup = { frame = frame, owner = owner, conns = conns, close = close }
end

function Window:_justClosed(owner)
    local lc = self._lastClose
    return lc and lc.owner == owner and tick() - lc.time < 0.25
end

function Window:_popupPos(anchor, w, h)
    local ap = anchor.AbsolutePosition - self.Overlay.AbsolutePosition
    local x = ap.X
    local y = ap.Y + anchor.AbsoluteSize.Y + 2
    local sg = self.Overlay.AbsoluteSize
    if y + h > sg.Y then y = ap.Y - h - 2 end
    if x + w > sg.X then x = sg.X - w - 4 end
    return UDim2.fromOffset(math.max(x, 0), math.max(y, 0))
end

function Window:_openList(anchor, owner, getOptions, isSelected, onPick, keepOpen)
    local T = self.Theme
    local options = getOptions()
    if #options == 0 then return end
    local rows = math.min(#options, 6)
    local h = rows * 20 + 2
    local w = math.max(anchor.AbsoluteSize.X, 100)

    local f = Instance.new("ScrollingFrame")
    f.Size = UDim2.fromOffset(w, h)
    f.Position = self:_popupPos(anchor, w, h)
    f.BackgroundColor3 = T.Surface
    f.BorderSizePixel = 1
    f.BorderColor3 = T.Border
    f.ScrollBarThickness = 3
    f.CanvasSize = UDim2.new(0, 0, 0, #options * 20)
    f.Active = true
    f.ZIndex = 120
    f.Parent = self.Overlay

    local items = {}
    local function refresh()
        for opt, b in pairs(items) do
            local sel = isSelected(opt)
            b.TextColor3 = sel and T.Accent or T.Text
            b.Text = (keepOpen and (sel and "✓ " or "   ") or "") .. tostring(opt)
        end
    end
    for i, opt in ipairs(options) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -4, 0, 20)
        b.Position = UDim2.new(0, 0, 0, (i - 1) * 20)
        b.BackgroundTransparency = 1
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.TextTruncate = Enum.TextTruncate.AtEnd
        b.ZIndex = 121
        b.Parent = f
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.Parent = b
        items[opt] = b
        b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.8 b.BackgroundColor3 = T.Border end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
        b.MouseButton1Click:Connect(function()
            onPick(opt)
            if keepOpen then refresh() else self:_closePopup() end
        end)
    end
    refresh()
    self:_setPopup(f, owner)
end

function Window:_openColorPicker(anchor, owner, initial, onChange)
    local T = self.Theme
    local hue, sat, val = initial:ToHSV()
    local W, H = 176, 152

    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(W, H)
    f.Position = self:_popupPos(anchor, W, H)
    f.BackgroundColor3 = T.Surface
    f.BorderSizePixel = 1
    f.BorderColor3 = T.Border
    f.Active = true
    f.ZIndex = 120
    f.Parent = self.Overlay

    local sv = Instance.new("Frame")
    sv.Size = UDim2.fromOffset(160, 90)
    sv.Position = UDim2.fromOffset(8, 8)
    sv.BorderSizePixel = 0
    sv.ZIndex = 121
    sv.Parent = f

    local white = Instance.new("Frame")
    white.Size = UDim2.new(1, 0, 1, 0)
    white.BackgroundColor3 = Color3.new(1, 1, 1)
    white.BorderSizePixel = 0
    white.ZIndex = 122
    white.Parent = sv
    local wg = Instance.new("UIGradient")
    wg.Transparency = NumberSequence.new(0, 1)
    wg.Parent = white

    local black = Instance.new("Frame")
    black.Size = UDim2.new(1, 0, 1, 0)
    black.BackgroundColor3 = Color3.new(0, 0, 0)
    black.BorderSizePixel = 0
    black.ZIndex = 123
    black.Parent = sv
    local bg = Instance.new("UIGradient")
    bg.Rotation = 90
    bg.Transparency = NumberSequence.new(1, 0)
    bg.Parent = black

    local svCursor = Instance.new("Frame")
    svCursor.Size = UDim2.fromOffset(6, 6)
    svCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    svCursor.BorderSizePixel = 1
    svCursor.BorderColor3 = Color3.new(0, 0, 0)
    svCursor.ZIndex = 125
    svCursor.Parent = sv

    local svHit = Instance.new("TextButton")
    svHit.Size = UDim2.new(1, 0, 1, 0)
    svHit.BackgroundTransparency = 1
    svHit.Text = ""
    svHit.ZIndex = 126
    svHit.Parent = sv

    local hueBar = Instance.new("Frame")
    hueBar.Size = UDim2.fromOffset(160, 10)
    hueBar.Position = UDim2.fromOffset(8, 104)
    hueBar.BorderSizePixel = 0
    hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
    hueBar.ZIndex = 121
    hueBar.Parent = f
    local hg = Instance.new("UIGradient")
    local kps = {}
    for i = 0, 6 do
        table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 1), 1, 1)))
    end
    hg.Color = ColorSequence.new(kps)
    hg.Parent = hueBar

    local hueCursor = Instance.new("Frame")
    hueCursor.Size = UDim2.new(0, 3, 1, 4)
    hueCursor.Position = UDim2.new(0, 0, 0, -2)
    hueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    hueCursor.BorderSizePixel = 1
    hueCursor.BorderColor3 = Color3.new(0, 0, 0)
    hueCursor.ZIndex = 125
    hueCursor.Parent = hueBar

    local hueHit = Instance.new("TextButton")
    hueHit.Size = UDim2.new(1, 0, 1, 8)
    hueHit.Position = UDim2.new(0, 0, 0, -4)
    hueHit.BackgroundTransparency = 1
    hueHit.Text = ""
    hueHit.ZIndex = 126
    hueHit.Parent = hueBar

    local hex = Instance.new("TextBox")
    hex.Size = UDim2.fromOffset(100, 20)
    hex.Position = UDim2.fromOffset(8, 124)
    hex.BackgroundColor3 = T.Background
    hex.BorderSizePixel = 1
    hex.BorderColor3 = T.Border
    hex.TextColor3 = T.TextButton
    hex.Font = Enum.Font.GothamBold
    hex.TextSize = 11
    hex.ClearTextOnFocus = false
    hex.ZIndex = 121
    hex.Parent = f

    local preview = Instance.new("Frame")
    preview.Size = UDim2.fromOffset(52, 20)
    preview.Position = UDim2.fromOffset(116, 124)
    preview.BorderSizePixel = 1
    preview.BorderColor3 = T.Border
    preview.ZIndex = 121
    preview.Parent = f

    local function apply(fire)
        local c = Color3.fromHSV(hue, sat, val)
        sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        svCursor.Position = UDim2.new(sat, -3, 1 - val, -3)
        hueCursor.Position = UDim2.new(hue, -1, 0, -2)
        hex.Text = "#" .. c:ToHex():upper()
        preview.BackgroundColor3 = c
        if fire then onChange(c) end
    end
    apply(false)

    local mode = nil
    local function update(input)
        local sp = self:_screenPos(input)
        if mode == "sv" then
            local rel = (sp - sv.AbsolutePosition)
            sat = math.clamp(rel.X / math.max(sv.AbsoluteSize.X, 1), 0, 1)
            val = 1 - math.clamp(rel.Y / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
            apply(true)
        elseif mode == "hue" then
            local rel = (sp.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1)
            hue = math.clamp(rel, 0, 0.999)
            apply(true)
        end
    end
    local function isPointer(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end
    svHit.InputBegan:Connect(function(input)
        if isPointer(input) then mode = "sv" self._busy = true update(input) end
    end)
    hueHit.InputBegan:Connect(function(input)
        if isPointer(input) then mode = "hue" self._busy = true update(input) end
    end)

    local conns = {}
    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if mode and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end))
    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if mode and isPointer(input) then
            mode = nil
            self._busy = false
        end
    end))

    hex.FocusLost:Connect(function()
        local ok, c = pcall(function() return Color3.fromHex(hex.Text) end)
        if ok and c then
            hue, sat, val = c:ToHSV()
            apply(true)
        else
            apply(false)
        end
    end)

    self:_setPopup(f, owner, conns)
end

function Window:_placeTip(screenPos)
    local ov = self.Overlay
    local rel = screenPos - ov.AbsolutePosition
    local sz = self.TipFrame.AbsoluteSize
    local x = math.min(rel.X + 14, ov.AbsoluteSize.X - sz.X - 4)
    local y = math.min(rel.Y + 18, ov.AbsoluteSize.Y - sz.Y - 4)
    self.TipFrame.Position = UDim2.fromOffset(math.max(x, 0), math.max(y, 0))
end

function Window:_showTip(text)
    local bounds = TextService:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(220, 1000))
    self.TipLabel.Text = text
    self.TipLabel.Size = UDim2.fromOffset(bounds.X + 2, bounds.Y)
    self.TipFrame.Size = UDim2.fromOffset(bounds.X + 14, bounds.Y + 8)
    self:_placeTip(UserInputService:GetMouseLocation())
    self.TipFrame.Visible = true
end

function Window:_attachTooltip(row, getText)
    row.MouseEnter:Connect(function()
        local text = getText and getText()
        if not text or text == "" then return end
        self._tipToken = self._tipToken + 1
        local token = self._tipToken
        task.delay(0.45, function()
            if token == self._tipToken and not self._destroyed then
                self:_showTip(text)
            end
        end)
    end)
    row.MouseLeave:Connect(function()
        self._tipToken = self._tipToken + 1
        self.TipFrame.Visible = false
    end)
end

function Window:Notify(o)
    if type(o) == "string" then o = { Text = o } end
    o = o or {}
    local T = self.Theme
    local dur = o.Duration or 3
    local map = { info = T.Accent, success = T.Success, warning = T.Warning, error = T.Danger }
    local col = map[tostring(o.Type or "info"):lower()] or T.Accent

    local text = tostring(o.Text or "")
    local textH = 0
    if text ~= "" then
        textH = TextService:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(214, 1000)).Y
    end
    local titleH = o.Title and 18 or 0
    local h = math.max(titleH + textH + 14, 30)

    self._toastCount = self._toastCount + 1
    local slot = Instance.new("Frame")
    slot.Size = UDim2.new(0, 240, 0, h)
    slot.BackgroundTransparency = 1
    slot.LayoutOrder = self._toastCount
    slot.ZIndex = 151
    slot.Parent = self.ToastHolder

    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(1, 0, 1, 0)
    toast.Position = UDim2.new(0, 260, 0, 0)
    toast.BackgroundColor3 = T.Background
    toast.BorderSizePixel = 1
    toast.BorderColor3 = T.Border
    toast.ZIndex = 152
    toast.Parent = slot
    corner(toast, 4)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = col
    bar.BorderSizePixel = 0
    bar.ZIndex = 153
    bar.Parent = toast

    local y = 5
    if o.Title then
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -16, 0, 16)
        t.Position = UDim2.new(0, 10, 0, y)
        t.BackgroundTransparency = 1
        t.Font = Enum.Font.GothamBold
        t.TextSize = 12
        t.TextColor3 = T.White
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Text = tostring(o.Title)
        t.ZIndex = 153
        t.Parent = toast
        y = y + 18
    end
    if text ~= "" then
        local b = Instance.new("TextLabel")
        b.Size = UDim2.new(1, -16, 0, textH)
        b.Position = UDim2.new(0, 10, 0, y)
        b.BackgroundTransparency = 1
        b.Font = Enum.Font.Gotham
        b.TextSize = 11
        b.TextColor3 = T.Body
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.TextYAlignment = Enum.TextYAlignment.Top
        b.TextWrapped = true
        b.Text = text
        b.ZIndex = 153
        b.Parent = toast
    end

    local life = Instance.new("Frame")
    life.Size = UDim2.new(1, 0, 0, 2)
    life.Position = UDim2.new(0, 0, 1, -2)
    life.BackgroundColor3 = col
    life.BorderSizePixel = 0
    life.ZIndex = 153
    life.Parent = toast

    table.insert(self._toasts, slot)
    while #self._toasts > 5 do
        local old = table.remove(self._toasts, 1)
        if old then old:Destroy() end
    end

    tween(toast, { Position = UDim2.new(0, 0, 0, 0) }, 0.2)
    tween(life, { Size = UDim2.new(0, 0, 0, 2) }, dur)

    local closed = false
    local function dismiss()
        if closed then return end
        closed = true
        tween(toast, { Position = UDim2.new(0, 260, 0, 0) }, 0.2)
        task.delay(0.22, function()
            for i, s in ipairs(self._toasts) do
                if s == slot then table.remove(self._toasts, i) break end
            end
            slot:Destroy()
        end)
    end
    toast.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dismiss()
        end
    end)
    task.delay(dur, dismiss)
end

----------------------------------------------------------------
-- TABS
----------------------------------------------------------------
function Window:SelectTab(index)
    self:_closePopup()
    for i, tab in ipairs(self.Tabs) do
        local active = i == index
        tab.Content.Visible = active
        tab.Active = active
        tween(tab.Button, {
            BackgroundColor3 = active and self.Theme.TabActive or self.Theme.TabBar,
            TextColor3 = active and self.Theme.White or self.Theme.Subtitle,
        })
        tween(tab.Underline, { BackgroundTransparency = active and 0 or 1 })
    end
end

function Window:AddTab(name)
    local win = self
    local tab = setmetatable({}, Tab)
    tab.Window = self
    tab.Name = name
    tab._items = {}
    tab._conns = self._conns

    local index = #self.Tabs + 1
    tab.Index = index
    tab.Active = index == 1
    table.insert(self.Tabs, tab)

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

    local btn = Instance.new("TextButton")
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
    underline.BorderSizePixel = 0
    underline.ZIndex = 13
    underline.Parent = btn
    tab.Underline = underline

    self:_themed(function()
        btn.BackgroundColor3 = tab.Active and win.Theme.TabActive or win.Theme.TabBar
        btn.TextColor3 = tab.Active and win.Theme.White or win.Theme.Subtitle
        underline.BackgroundColor3 = win.Theme.Accent
        underline.BackgroundTransparency = tab.Active and 0 or 1
    end)

    btn.MouseButton1Click:Connect(function() self:SelectTab(index) end)
    btn.MouseEnter:Connect(function()
        if not tab.Active then tween(btn, { TextColor3 = win.Theme.Text }) end
    end)
    btn.MouseLeave:Connect(function()
        if not tab.Active then tween(btn, { TextColor3 = win.Theme.Subtitle }) end
    end)

    local n = #self.Tabs
    for i, t in ipairs(self.Tabs) do
        t.Button.Size = UDim2.new(1 / n, 0, 1, 0)
        t.Button.Position = UDim2.new((i - 1) / n, 0, 0, 0)
    end

    return tab
end

function Tab:Select() self.Window:SelectTab(self.Index) end

----------------------------------------------------------------
-- LAYOUT ENGINE (rows stack top-to-bottom, same spacing as before)
----------------------------------------------------------------
function Tab:_relayout()
    local y = 4
    local searching = (self._searchQuery or "") ~= ""
    for _, e in ipairs(self._items) do
        local collapsed = e.section and e.section.collapsed and not searching
        local show = e.visible and not e.searchHidden and not collapsed
        if show then
            if e.frame then
                e.frame.Visible = true
                e.frame.Position = UDim2.new(0, 10 + e.indent, 0, y)
            end
            y = y + e.height
        elseif e.frame then
            e.frame.Visible = false
        end
    end
    self.Content.CanvasSize = UDim2.new(0, 0, 0, y + 4)
end

function Tab:_search(q)
    q = (q or ""):lower()
    self._searchQuery = q
    for _, e in ipairs(self._items) do
        if q == "" or e.keepVisible then
            e.searchHidden = false
        else
            e.searchHidden = not e.name:find(q, 1, true)
        end
    end
    self:_relayout()
end

local function newEntry(tab, height, name, indentSize)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20 - (indentSize or 0), 0, height)
    row.BackgroundTransparency = 1
    row.ZIndex = 12
    row.Parent = tab.Content
    local entry = {
        frame = row, height = height, indent = indentSize or 0,
        visible = true, searchHidden = false,
        section = tab._curSection, name = tostring(name or ""):lower(),
        userEnabled = true, depEnabled = true,
    }
    table.insert(tab._items, entry)
    tab:_relayout()
    return row, entry
end

local function applyEnabled(win, entry)
    if not entry.frame then return end
    local off = not (entry.userEnabled and entry.depEnabled)
    if off and not entry.cover then
        local c = Instance.new("TextButton")
        c.Size = UDim2.new(1, 0, 1, 0)
        c.Text = ""
        c.AutoButtonColor = false
        c.BorderSizePixel = 0
        c.BackgroundTransparency = 0.45
        c.ZIndex = 20
        c.Parent = entry.frame
        entry.cover = c
        bind(win, c, "BackgroundColor3", "Background")
    end
    if entry.cover then entry.cover.Visible = off end
end

-- shared element plumbing: enable/visible/tooltip/dependencies/flags
local function finalize(tab, obj, entry, opts, kind, indent)
    opts = opts or {}
    local win = tab.Window
    obj.Frame = entry.frame
    obj.Window = win
    obj.Tab = tab
    obj._entry = entry
    obj.Kind = kind

    function obj:SetVisible(v)
        entry.visible = v and true or false
        tab:_relayout()
    end
    function obj:GetVisible() return entry.visible end
    function obj:SetEnabled(v)
        entry.userEnabled = v and true or false
        applyEnabled(win, entry)
    end
    function obj:GetEnabled() return entry.userEnabled end
    function obj:SetTooltip(t) entry.tooltip = t end

    entry.tooltip = opts.Tooltip
    if entry.frame then win:_attachTooltip(entry.frame, function() return entry.tooltip end) end

    local dep = opts.DependsOn
    if not dep and tab._parentToggle then
        if kind == "toggle" and indent then dep = tab._parentToggle end
        if opts.Child then dep = tab._parentToggle end
    end
    if dep and dep._addChild then dep:_addChild(obj) end

    if opts.Enabled == false then obj:SetEnabled(false) end
    if opts.Visible == false then obj:SetVisible(false) end
    return obj
end

local function themedText(win, parent, text, font, size, colorKey, z)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = font
    l.TextSize = size
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = z or 13
    l.Parent = parent
    bind(win, l, "TextColor3", colorKey)
    return l
end

local function hoverBorder(win, btn)
    btn.MouseEnter:Connect(function() tween(btn, { BorderColor3 = win.Theme.Accent }) end)
    btn.MouseLeave:Connect(function() tween(btn, { BorderColor3 = win.Theme.Border }) end)
end

----------------------------------------------------------------
-- SECTIONS (collapsible)
----------------------------------------------------------------
local SectionMT = {}
SectionMT.__index = function(sec, key)
    local f = Tab[key]
    if type(f) == "function" and type(key) == "string" and key:sub(1, 3) == "Add" then
        return function(_, ...)
            local tab = sec.Tab
            local prev = tab._curSection
            tab._curSection = sec
            local r = table.pack(f(tab, ...))
            tab._curSection = prev
            return table.unpack(r, 1, r.n)
        end
    end
    return nil
end

function Tab:AddSection(text, startOpen, opts)
    opts = opts or {}
    local win = self.Window
    local row, entry = newEntry(self, 22, text)
    self._parentToggle = nil

    local arrow = themedText(win, row, "▼", Enum.Font.GothamBold, 10, "Heading", 12)
    arrow.Size = UDim2.new(0, 14, 1, 0)
    local label = themedText(win, row, text, Enum.Font.GothamBold, 13, "Heading", 12)
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 16, 0, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 15
    btn.Parent = row

    local sec = setmetatable({ Tab = self, collapsed = startOpen == false }, SectionMT)
    local tab = self
    local function paint()
        arrow.Text = sec.collapsed and "▶" or "▼"
    end
    paint()
    function sec:SetOpen(b)
        sec.collapsed = not b
        paint()
        tab:_relayout()
    end
    function sec:Toggle() sec:SetOpen(sec.collapsed) end
    function sec:IsOpen() return not sec.collapsed end
    btn.MouseButton1Click:Connect(function() sec:Toggle() end)
    btn.MouseEnter:Connect(function() tween(label, { TextColor3 = win.Theme.White }) end)
    btn.MouseLeave:Connect(function() tween(label, { TextColor3 = win.Theme.Heading }) end)

    sec.Frame = row
    finalize(self, sec, entry, opts, "section")
    -- finalize adds Set* methods onto sec (rawset); keep section content flowing
    return sec
end

----------------------------------------------------------------
-- TOGGLE
----------------------------------------------------------------
function Tab:AddToggle(text, default, callback, indent, opts)
    if type(indent) == "table" then opts, indent = indent, indent.Indent end
    opts = opts or {}
    local win = self.Window
    local value, fromCfg = Library:_initial(opts.Flag, default or false, function(v)
        if type(v) == "boolean" then return v end
    end)

    local row, entry = newEntry(self, 22, text, indent and 14 or 0)

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 14, 0, 14)
    box.Position = UDim2.new(0, 0, 0.5, -7)
    box.BorderSizePixel = 1
    box.ZIndex = 13
    box.Parent = row

    local tick = Instance.new("TextLabel")
    tick.Size = UDim2.new(1, 0, 1, 0)
    tick.BackgroundTransparency = 1
    tick.Font = Enum.Font.GothamBold
    tick.TextSize = 10
    tick.Text = value and "✓" or ""
    tick.ZIndex = 14
    tick.Parent = box

    local label = themedText(win, row, text, Enum.Font.Gotham, indent and 11 or 12,
        indent and "TextDim" or "Text")
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 20, 0, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 15
    btn.Parent = row

    local obj = { _children = {} }
    win:_themed(function()
        box.BackgroundColor3 = value and win.Theme.Accent or win.Theme.Surface
        box.BorderColor3 = win.Theme.Border
        tick.TextColor3 = win.Theme.White
    end)
    btn.MouseEnter:Connect(function() tween(box, { BorderColor3 = win.Theme.Accent }) end)
    btn.MouseLeave:Connect(function() tween(box, { BorderColor3 = win.Theme.Border }) end)

    local function commit()
        tick.Text = value and "✓" or ""
        tween(box, { BackgroundColor3 = value and win.Theme.Accent or win.Theme.Surface })
        Library:_commit(opts.Flag, value)
        for _, c in ipairs(obj._children) do
            c._entry.depEnabled = value
            applyEnabled(win, c._entry)
        end
    end

    btn.MouseButton1Click:Connect(function()
        value = not value
        commit()
        safe(text, callback, value)
    end)

    function obj:Set(v, silent)
        value = v and true or false
        commit()
        if not silent then safe(text, callback, value) end
    end
    function obj:Get() return value end
    function obj:SetText(t) label.Text = t entry.name = tostring(t):lower() end
    function obj:_addChild(child)
        table.insert(obj._children, child)
        child._entry.depEnabled = value
        applyEnabled(win, child._entry)
    end
    obj._ser = function() return value end
    obj._de = function(raw) if type(raw) == "boolean" then return raw end end

    finalize(self, obj, entry, opts, "toggle", indent)
    Library:_register(opts.Flag, obj, value)

    if opts.DisableChildren and not indent then
        self._parentToggle = obj
    elseif not indent then
        self._parentToggle = nil
    end

    if fromCfg then task.defer(safe, text, callback, value) end
    return obj
end

----------------------------------------------------------------
-- SLIDER
----------------------------------------------------------------
function Tab:AddSlider(text, min, max, default, callback, opts)
    opts = opts or {}
    local win = self.Window
    local inc = opts.Increment or 1
    local suffix = opts.Suffix or ""

    local value, fromCfg = Library:_initial(opts.Flag, default or min, function(v)
        if type(v) == "number" then return math.clamp(v, min, max) end
    end)
    value = math.clamp(value, min, max)

    local row, entry = newEntry(self, 34, text)

    local label = themedText(win, row, text, Enum.Font.Gotham, 12, "Text")
    label.Size = UDim2.new(0.6, 0, 0, 18)

    local valueLbl = themedText(win, row, "", Enum.Font.GothamBold, 11, "TextButton")
    valueLbl.Size = UDim2.new(0.4, 0, 0, 18)
    valueLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 4)
    track.Position = UDim2.new(0, 0, 0, 24)
    track.BorderSizePixel = 1
    track.ZIndex = 13
    track.Parent = row
    bind(win, track, "BackgroundColor3", "Surface")
    bind(win, track, "BorderColor3", "Border")

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 14
    fill.Parent = track
    bind(win, fill, "BackgroundColor3", "Accent")

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 0, 16)
    hit.Position = UDim2.new(0, 0, 0, 18)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 15
    hit.Parent = row

    local decimals = 0
    local s = tostring(inc)
    local dot = s:find("%.")
    if dot then decimals = #s - dot end

    local function render()
        local alpha = (max - min) == 0 and 0 or (value - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        valueLbl.Text = string.format("%." .. decimals .. "f", value) .. suffix
    end
    render()

    local obj = {}
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = min + rel * (max - min)
        v = math.floor(v / inc + 0.5) * inc
        v = math.clamp(v, min, max)
        if v ~= value then
            value = v
            render()
            Library:_commit(opts.Flag, value)
            safe(text, callback, value)
        end
    end

    local sliding = false
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            win._busy = true
            setFromX(win:_screenPos(input).X)
        end
    end)
    table.insert(self._conns, UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(win:_screenPos(input).X)
        end
    end))
    table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            sliding = false
            win._busy = false
        end
    end))

    function obj:Set(v, silent)
        value = math.clamp(v, min, max)
        render()
        Library:_commit(opts.Flag, value)
        if not silent then safe(text, callback, value) end
    end
    function obj:Get() return value end
    obj._ser = function() return value end
    obj._de = function(raw) if type(raw) == "number" then return math.clamp(raw, min, max) end end

    finalize(self, obj, entry, opts, "slider")
    obj.Label = label
    Library:_register(opts.Flag, obj, value)
    if fromCfg then task.defer(safe, text, callback, value) end
    return obj
end

----------------------------------------------------------------
-- DROPDOWN (cycle by default; List=true for popup list) + MULTI
----------------------------------------------------------------
local function buildDropdown(tab, text, options, current, callback, opts, multi)
    opts = opts or {}
    local win = tab.Window
    options = options or {}

    local selected = {}   -- multi: map of option -> true
    local value           -- single: current option
    local fromCfg = false

    if multi then
        local init
        init, fromCfg = Library:_initial(opts.Flag, current or {}, function(raw)
            if type(raw) == "table" then return raw end
        end)
        for _, v in ipairs(init or {}) do selected[v] = true end
    else
        value, fromCfg = Library:_initial(opts.Flag, current, function(raw)
            if type(raw) == "string" then return raw end
        end)
        if value == nil then value = options[1] end
    end

    local row, entry = newEntry(tab, 22, text)

    local label = themedText(win, row, text, Enum.Font.Gotham, 12, "Text")
    label.Size = UDim2.new(0.45, 0, 1, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5, 0, 0, 18)
    btn.Position = UDim2.new(0.5, 0, 0.5, -9)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.BorderSizePixel = 1
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.ZIndex = 13
    btn.Parent = row
    bind(win, btn, "BackgroundColor3", "Surface")
    bind(win, btn, "BorderColor3", "Border")
    bind(win, btn, "TextColor3", "TextButton")
    hoverBorder(win, btn)

    local function getList()
        local out = {}
        for _, o in ipairs(options) do
            if selected[o] then table.insert(out, o) end
        end
        return out
    end
    local function render()
        if multi then
            local l = getList()
            if #l == 0 then btn.Text = "None"
            elseif #l <= 2 then btn.Text = table.concat(l, ", ")
            else btn.Text = #l .. " selected" end
        else
            btn.Text = value ~= nil and tostring(value) or "None"
        end
    end
    render()

    local obj = {}
    local function result()
        if multi then return getList() end
        return value
    end
    local function commit(fire)
        render()
        Library:_commit(opts.Flag, result())
        if fire then safe(text, callback, result()) end
    end

    local idx = 1
    for i, o in ipairs(options) do if o == value then idx = i break end end

    btn.MouseButton1Click:Connect(function()
        if multi or opts.List then
            if win:_justClosed(obj) then return end
            win:_openList(btn, obj, function() return options end,
                function(o) if multi then return selected[o] == true end return o == value end,
                function(o)
                    if multi then
                        selected[o] = not selected[o] or nil
                    else
                        value = o
                    end
                    commit(true)
                end, multi)
        else
            if #options == 0 then return end
            idx = idx % #options + 1
            value = options[idx]
            commit(true)
        end
    end)

    function obj:Set(v, silent)
        if multi then
            selected = {}
            for _, o in ipairs(v or {}) do selected[o] = true end
        else
            for i, o in ipairs(options) do
                if o == v then idx = i value = v end
            end
        end
        commit(not silent)
    end
    function obj:Get() return result() end
    function obj:SetOptions(newOptions, keep)
        options = newOptions or {}
        if multi then
            if not keep then selected = {} end
        else
            local found = false
            for i, o in ipairs(options) do
                if o == value then idx = i found = true end
            end
            if not found then value = options[1] idx = 1 end
        end
        render()
    end
    obj._ser = function() return result() end
    obj._de = function(raw)
        if multi and type(raw) == "table" then return raw end
        if not multi and type(raw) == "string" then return raw end
    end

    finalize(tab, obj, entry, opts, multi and "multidropdown" or "dropdown")
    obj.Label = label
    obj.Button = btn
    Library:_register(opts.Flag, obj, result())
    if fromCfg then task.defer(safe, text, callback, result()) end
    return obj
end

function Tab:AddDropdown(text, options, current, callback, opts)
    return buildDropdown(self, text, options, current, callback, opts, false)
end

function Tab:AddMultiDropdown(text, options, defaults, callback, opts)
    return buildDropdown(self, text, options, defaults, callback, opts, true)
end

----------------------------------------------------------------
-- COLOR PICKER
----------------------------------------------------------------
function Tab:AddColorPicker(text, default, callback, opts)
    opts = opts or {}
    local win = self.Window
    local value, fromCfg = Library:_initial(opts.Flag, default or Color3.fromRGB(255, 255, 255), tableToColor)

    local row, entry = newEntry(self, 24, text)

    local label = themedText(win, row, text, Enum.Font.Gotham, 12, "Text")
    label.Size = UDim2.new(1, -60, 1, 0)

    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 52, 0, 18)
    sw.Position = UDim2.new(1, -52, 0.5, -9)
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.BackgroundColor3 = value
    sw.BorderSizePixel = 1
    sw.ZIndex = 13
    sw.Parent = row
    bind(win, sw, "BorderColor3", "Border")
    hoverBorder(win, sw)

    local obj = {}
    local function commit(fire)
        sw.BackgroundColor3 = value
        Library:_commit(opts.Flag, value)
        if fire then safe(text, callback, value) end
    end

    sw.MouseButton1Click:Connect(function()
        if win:_justClosed(obj) then return end
        win:_openColorPicker(sw, obj, value, function(c)
            value = c
            commit(true)
        end)
    end)

    function obj:Set(c, silent)
        if typeof(c) == "table" then c = tableToColor(c) end
        if typeof(c) ~= "Color3" then return end
        value = c
        commit(not silent)
    end
    function obj:Get() return value end
    obj._ser = function() return colorToTable(value) end
    obj._de = tableToColor

    finalize(self, obj, entry, opts, "colorpicker")
    obj.Label = label
    Library:_register(opts.Flag, obj, value)
    if fromCfg then task.defer(safe, text, callback, value) end
    return obj
end

----------------------------------------------------------------
-- TEXTBOX
----------------------------------------------------------------
function Tab:AddTextbox(text, default, callback, opts)
    opts = opts or {}
    local win = self.Window
    local value, fromCfg = Library:_initial(opts.Flag, default or "", function(raw)
        if type(raw) == "string" then return raw end
    end)

    local row, entry = newEntry(self, 22, text)

    local label = themedText(win, row, text, Enum.Font.Gotham, 12, "Text")
    label.Size = UDim2.new(0.45, 0, 1, 0)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.5, 0, 0, 18)
    box.Position = UDim2.new(0.5, 0, 0.5, -9)
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.Text = value
    box.PlaceholderText = opts.Placeholder or ""
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 1
    box.ZIndex = 13
    box.TextTruncate = Enum.TextTruncate.AtEnd
    box.Parent = row
    bind(win, box, "BackgroundColor3", "Surface")
    bind(win, box, "BorderColor3", "Border")
    bind(win, box, "TextColor3", "TextButton")
    bind(win, box, "PlaceholderColor3", "Subtitle")
    box.Focused:Connect(function() tween(box, { BorderColor3 = win.Theme.Accent }) end)
    box.MouseEnter:Connect(function() tween(box, { BorderColor3 = win.Theme.Accent }) end)
    box.MouseLeave:Connect(function()
        if not box:IsFocused() then tween(box, { BorderColor3 = win.Theme.Border }) end
    end)

    local obj = {}
    local function accept(t)
        if opts.Numeric then
            local n = tonumber(t)
            if n == nil then return nil end
            return tostring(n)
        end
        return t
    end

    box.FocusLost:Connect(function()
        tween(box, { BorderColor3 = win.Theme.Border })
        local v = accept(box.Text)
        if v == nil then
            box.Text = value
            return
        end
        value = v
        box.Text = v
        Library:_commit(opts.Flag, value)
        safe(text, callback, opts.Numeric and tonumber(value) or value)
    end)
    if opts.Live then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if box:IsFocused() then
                local v = accept(box.Text)
                if v ~= nil then safe(text, opts.Live == true and callback or opts.Live, opts.Numeric and tonumber(v) or v) end
            end
        end)
    end

    function obj:Set(v, silent)
        value = tostring(v)
        box.Text = value
        Library:_commit(opts.Flag, value)
        if not silent then safe(text, callback, opts.Numeric and tonumber(value) or value) end
    end
    function obj:Get() return opts.Numeric and tonumber(value) or value end
    obj._ser = function() return value end
    obj._de = function(raw) if type(raw) == "string" then return raw end end

    finalize(self, obj, entry, opts, "textbox")
    obj.Label = label
    obj.Box = box
    Library:_register(opts.Flag, obj, value)
    if fromCfg then task.defer(safe, text, callback, opts.Numeric and tonumber(value) or value) end
    return obj
end

----------------------------------------------------------------
-- KEYBIND (modes: Press / Toggle / Hold / Always; Esc/Backspace clears)
----------------------------------------------------------------
function Tab:AddKeybind(text, defaultKey, callback, opts)
    opts = opts or {}
    local win = self.Window
    local init, fromCfg = Library:_initial(opts.Flag,
        { Key = defaultKey or "None", Mode = opts.Mode or "Press" },
        function(raw)
            if type(raw) == "table" and type(raw.Key) == "string" then
                return { Key = raw.Key, Mode = raw.Mode or opts.Mode or "Press" }
            end
        end)

    local currentKey = init.Key ~= "None" and init.Key or nil
    local mode = init.Mode
    local state, held = false, false

    local row, entry = newEntry(self, 24, text)

    local label = themedText(win, row, text, Enum.Font.Gotham, 12, "Text")
    label.Size = UDim2.new(1, -60, 1, 0)

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 52, 0, 18)
    keyBtn.Position = UDim2.new(1, -52, 0.5, -9)
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 11
    keyBtn.BorderSizePixel = 1
    keyBtn.TextTruncate = Enum.TextTruncate.AtEnd
    keyBtn.ZIndex = 13
    keyBtn.Parent = row
    bind(win, keyBtn, "BackgroundColor3", "Surface")
    bind(win, keyBtn, "BorderColor3", "Border")
    hoverBorder(win, keyBtn)

    local listening = false
    local function paint()
        keyBtn.Text = listening and "..." or (currentKey or "None")
        keyBtn.TextColor3 = listening and win.Theme.Accent or win.Theme.Text
    end
    win:_themed(paint)

    local obj = {}
    local function value() return { Key = currentKey or "None", Mode = mode } end
    local function commit() Library:_commit(opts.Flag, value()) end
    local function matches(input)
        return currentKey ~= nil and input.KeyCode ~= Enum.KeyCode.Unknown
            and input.KeyCode.Name == currentKey
    end

    keyBtn.MouseButton1Click:Connect(function()
        if anyListening then return end
        listening = true
        anyListening = true
        paint()
    end)

    table.insert(self._conns, UserInputService.InputBegan:Connect(function(input, gp)
        if listening then
            if input.KeyCode == Enum.KeyCode.Unknown then return end
            listening = false
            anyListening = false
            if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
                currentKey = nil
            else
                currentKey = input.KeyCode.Name
            end
            paint()
            commit()
            return
        end
        if gp or mode == "Always" or not matches(input) then return end
        if mode == "Press" then
            safe(text, callback)
        elseif mode == "Toggle" then
            state = not state
            safe(text, callback, state)
        elseif mode == "Hold" then
            held = true
            safe(text, callback, true)
        end
    end))
    table.insert(self._conns, UserInputService.InputEnded:Connect(function(input)
        if mode == "Hold" and held and matches(input) then
            held = false
            safe(text, callback, false)
        end
    end))

    local function tipText()
        return opts.Tooltip or ("Mode: " .. mode .. " · Esc/Backspace clears")
    end

    function obj:Get() return currentKey end
    function obj:GetMode() return mode end
    function obj:Set(k)
        if type(k) == "table" then
            if k.Mode then mode = k.Mode end
            k = k.Key
        end
        currentKey = (k ~= nil and k ~= "None") and k or nil
        paint()
        commit()
    end
    function obj:SetMode(m)
        if m ~= "Press" and m ~= "Toggle" and m ~= "Hold" and m ~= "Always" then return end
        mode = m
        state, held = false, false
        entry.tooltip = tipText()
        if m == "Always" then safe(text, callback, true) end
        commit()
    end
    obj._ser = value
    obj._de = function(raw)
        if type(raw) == "table" and type(raw.Key) == "string" then return raw end
        if type(raw) == "string" then return raw end
    end

    finalize(self, obj, entry, opts, "keybind")
    entry.tooltip = tipText()
    obj.Label = label
    obj.Button = keyBtn
    Library:_register(opts.Flag, obj, value())

    if mode == "Always" then task.defer(safe, text, callback, true) end
    return obj
end

----------------------------------------------------------------
-- BUTTON
----------------------------------------------------------------
function Tab:AddButton(text, callback, opts)
    opts = opts or {}
    local win = self.Window
    local height = opts.Height or 32
    local row, entry = newEntry(self, height + 8, text)
    self._parentToggle = nil

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, height)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = text
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.ZIndex = 12
    btn.Parent = row
    bind(win, btn, "TextColor3", "White")

    local hovering, pressed = false, false
    local function base() return opts.Color or win.Theme.Accent end
    local function target()
        local b = base()
        if pressed then return b:Lerp(Color3.new(0, 0, 0), 0.2) end
        if hovering then return b:Lerp(Color3.new(1, 1, 1), 0.12) end
        return b
    end
    win:_themed(function() btn.BackgroundColor3 = target() end)

    btn.MouseEnter:Connect(function() hovering = true tween(btn, { BackgroundColor3 = target() }) end)
    btn.MouseLeave:Connect(function() hovering, pressed = false, false tween(btn, { BackgroundColor3 = target() }) end)
    btn.MouseButton1Down:Connect(function() pressed = true tween(btn, { BackgroundColor3 = target() }, 0.06) end)
    btn.MouseButton1Up:Connect(function() pressed = false tween(btn, { BackgroundColor3 = target() }, 0.06) end)
    btn.MouseButton1Click:Connect(function() safe(text, callback) end)

    local obj = { Button = btn }
    function obj:SetText(t) btn.Text = t entry.name = tostring(t):lower() end
    function obj:Flash(t, seconds)
        local old = btn.Text
        btn.Text = t
        task.delay(seconds or 2, function()
            if btn.Parent then btn.Text = old end
        end)
    end
    finalize(self, obj, entry, opts, "button")
    return obj
end

----------------------------------------------------------------
-- TEXT ELEMENTS
----------------------------------------------------------------
function Tab:AddHeading(text, opts)
    local win = self.Window
    local row, entry = newEntry(self, 22, text)
    self._parentToggle = nil
    local l = themedText(win, row, text, Enum.Font.GothamBold, 13, "Heading", 12)
    l.Size = UDim2.new(1, 0, 1, 0)
    local obj = { Label = l }
    function obj:SetText(t) l.Text = t entry.name = tostring(t):lower() end
    return finalize(self, obj, entry, opts, "heading")
end

function Tab:AddLabel(text, height, opts)
    local win = self.Window
    height = height or 18
    local row, entry = newEntry(self, height, text)
    local l = themedText(win, row, text, Enum.Font.Gotham, 11, "Muted", 12)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    local obj = { Label = l }
    function obj:SetText(t) l.Text = t entry.name = tostring(t):lower() end
    function obj:Get() return l.Text end
    return finalize(self, obj, entry, opts, "label")
end

function Tab:AddParagraph(text, height, opts)
    local win = self.Window
    height = height or 50
    local row, entry = newEntry(self, height, text)
    local l = themedText(win, row, text, Enum.Font.Gotham, 12, "Body", 12)
    l.Size = UDim2.new(1, 0, 1, 0)
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.TextWrapped = true
    local obj = { Label = l }
    function obj:SetText(t) l.Text = t entry.name = tostring(t):lower() end
    return finalize(self, obj, entry, opts, "paragraph")
end

function Tab:AddSeparator()
    local win = self.Window
    local row, entry = newEntry(self, 8, "")
    self._parentToggle = nil
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BorderSizePixel = 0
    line.ZIndex = 12
    line.Parent = row
    bind(win, line, "BackgroundColor3", "Surface")
    return finalize(self, {}, entry, nil, "separator")
end

function Tab:AddSpacer(height)
    local _, entry = newEntry(self, height or 8, "")
    entry.frame:Destroy()
    entry.frame = nil
    self:_relayout()
    return { _entry = entry }
end

-- Label on the left, live-updating value on the right
function Tab:AddLiveLabel(text, fn, interval, opts)
    local win = self.Window
    local row, entry = newEntry(self, 18, text)
    local l = themedText(win, row, text, Enum.Font.Gotham, 11, "Muted", 12)
    l.Size = UDim2.new(0.6, 0, 1, 0)
    local v = themedText(win, row, "", Enum.Font.GothamBold, 11, "TextButton", 12)
    v.Size = UDim2.new(0.4, 0, 1, 0)
    v.Position = UDim2.new(0.6, 0, 0, 0)
    v.TextXAlignment = Enum.TextXAlignment.Right

    local obj = { Label = l, Value = v }
    local running = true
    function obj:Stop() running = false end
    task.spawn(function()
        while running and row.Parent and not win._destroyed do
            local ok, res = pcall(fn)
            if ok and res ~= nil then v.Text = tostring(res) end
            task.wait(interval or 1)
        end
    end)
    return finalize(self, obj, entry, opts, "livelabel")
end

-- Progress bar (read-only)
function Tab:AddProgress(text, value, opts)
    opts = opts or {}
    local win = self.Window
    local min, max = opts.Min or 0, opts.Max or 100
    value = math.clamp(value or min, min, max)

    local row, entry = newEntry(self, 34, text)
    local label = themedText(win, row, text, Enum.Font.Gotham, 12, "Text")
    label.Size = UDim2.new(0.6, 0, 0, 18)
    local valueLbl = themedText(win, row, "", Enum.Font.GothamBold, 11, "TextButton")
    valueLbl.Size = UDim2.new(0.4, 0, 0, 18)
    valueLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 4)
    track.Position = UDim2.new(0, 0, 0, 24)
    track.BorderSizePixel = 1
    track.ZIndex = 13
    track.Parent = row
    bind(win, track, "BackgroundColor3", "Surface")
    bind(win, track, "BorderColor3", "Border")
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 14
    fill.Parent = track
    bind(win, fill, "BackgroundColor3", "Accent")

    local function render(animate)
        local alpha = (max - min) == 0 and 0 or (value - min) / (max - min)
        local size = UDim2.new(alpha, 0, 1, 0)
        if animate then tween(fill, { Size = size }, 0.2) else fill.Size = size end
        if opts.Format then
            local ok, res = pcall(opts.Format, value, min, max)
            valueLbl.Text = ok and tostring(res) or tostring(value)
        else
            valueLbl.Text = tostring(round(value)) .. (opts.Suffix or "%")
        end
    end
    render(false)

    local obj = {}
    function obj:Set(v) value = math.clamp(v, min, max) render(true) end
    function obj:Get() return value end
    finalize(self, obj, entry, opts, "progress")
    obj.Label = label
    return obj
end

-- Search box: filters this tab's rows by their text
function Tab:AddSearch(placeholder)
    local win = self.Window
    local row, entry = newEntry(self, 26, "")
    entry.keepVisible = true
    self._parentToggle = nil

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 20)
    box.Position = UDim2.new(0, 0, 0, 2)
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.Text = ""
    box.PlaceholderText = placeholder or "Search..."
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 1
    box.ZIndex = 13
    box.Parent = row
    bind(win, box, "BackgroundColor3", "Surface")
    bind(win, box, "BorderColor3", "Border")
    bind(win, box, "TextColor3", "TextButton")
    bind(win, box, "PlaceholderColor3", "Subtitle")
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.Parent = box
    box.Focused:Connect(function() tween(box, { BorderColor3 = win.Theme.Accent }) end)
    box.FocusLost:Connect(function() tween(box, { BorderColor3 = win.Theme.Border }) end)

    local tab = self
    box:GetPropertyChangedSignal("Text"):Connect(function() tab:_search(box.Text) end)

    local obj = { Box = box }
    function obj:Clear() box.Text = "" end
    return finalize(self, obj, entry, nil, "search")
end

----------------------------------------------------------------
-- CONFIG SECTION (name box + list + Save / Load / Delete / Refresh)
----------------------------------------------------------------
function Tab:AddConfigSection(title)
    local win = self.Window
    local objs = {}
    objs.Heading = self:AddHeading(title or "Configs")
    objs.Name = self:AddTextbox("Config Name", "", nil, { Placeholder = "new config" })
    objs.List = self:AddDropdown("Configs", Library:ListConfigs(), nil, nil, { List = true })

    local function pick()
        local n = cleanName(objs.Name:Get())
        if n == "" then n = objs.List:Get() or "" end
        return n
    end
    local function refresh()
        objs.List:SetOptions(Library:ListConfigs())
    end
    local function report(ok, err, okText)
        if ok then
            win:Notify({ Title = "Config", Text = okText, Type = "success" })
        else
            win:Notify({ Title = "Config", Text = tostring(err or "failed"), Type = "error" })
        end
    end

    objs.Save = self:AddButton("SAVE CONFIG", function()
        local n = pick()
        local ok, err = Library:SaveConfig(n)
        report(ok, err, "Saved '" .. n .. "'")
        refresh()
        if ok then objs.List:Set(n, true) end
    end, { Height = 24 })
    objs.Load = self:AddButton("LOAD CONFIG", function()
        local n = objs.List:Get() or pick()
        local ok, err = Library:LoadConfig(n or "")
        report(ok, err, "Loaded '" .. tostring(n) .. "'")
    end, { Height = 24 })
    objs.Delete = self:AddButton("DELETE CONFIG", function()
        local n = objs.List:Get()
        if not n then return report(false, "nothing selected") end
        local ok, err = Library:DeleteConfig(n)
        report(ok, err, "Deleted '" .. n .. "'")
        refresh()
    end, { Height = 24, Color = win.Theme.Danger })
    objs.Refresh = self:AddButton("REFRESH LIST", refresh, { Height = 24, Color = win.Theme.Surface })
    return objs
end

return Library
