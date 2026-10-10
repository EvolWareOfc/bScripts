-- Example: the original bScripts window rebuilt with bScriptsUI v2 (UI only).
-- Swap the loadstring line for wherever you host bScriptsUI.lua.
local UI = loadstring(game:HttpGet("YOUR_RAW_URL/bScriptsUI.lua"))()

local Window = UI:CreateWindow({
    Title = "bScripts",
    Subtitle = "apoc2",
    Version = "0.1.1",
    ToggleKey = "PageUp",
    AutoSave = "autosave",      -- every element with a Flag is saved/loaded automatically
})

----------------------------------------------------------------
-- Players tab
----------------------------------------------------------------
local Players = Window:AddTab("Players")
Players:AddSearch("Search options...")

-- DisableChildren: the indented toggles below grey out while this one is off
Players:AddToggle("ESP Master", false, function(v) print("ESP", v) end, false,
    { Flag = "ESP", DisableChildren = true, Tooltip = "Master switch for everything below" })
Players:AddToggle("Chams", false, function(v) end, true, { Flag = "Chams" })
Players:AddToggle("Box ESP", false, function(v) end, true, { Flag = "Box" })
Players:AddDropdown("Box Style", { "2D", "Corner", "3D" }, "Corner", function(v) end,
    { Flag = "BoxStyle", Child = true })
Players:AddColorPicker("Box Colour", Color3.fromRGB(255, 255, 255), function(c) end,
    { Flag = "BoxColour", Child = true })
Players:AddSlider("Max Distance", 0, 5000, 5000, function(v) end,
    { Flag = "MaxDist", Increment = 50, Suffix = "m" })

-- Collapsible group
local Info = Players:AddSection("Info to show", true)
Info:AddToggle("Show Name", false, function(v) end, true, { Flag = "ShowName" })
Info:AddToggle("Show Distance", false, function(v) end, true, { Flag = "ShowDistance" })
Info:AddToggle("Show Health", false, function(v) end, true, { Flag = "ShowHealth" })

----------------------------------------------------------------
-- Loot tab
----------------------------------------------------------------
local Loot = Window:AddTab("Loot")
Loot:AddMultiDropdown("Categories", { "Weapons", "Ammo", "Medical", "Food", "Clothing" },
    { "Weapons" }, function(list) print("Loot:", table.concat(list, ", ")) end, { Flag = "LootCats" })
Loot:AddDropdown("Sort By", { "Distance", "Rarity", "Name" }, "Distance", function(v) end,
    { Flag = "LootSort", List = true })
Loot:AddTextbox("Filter", "", function(v) end, { Flag = "LootFilter", Placeholder = "keyword" })

----------------------------------------------------------------
-- World tab
----------------------------------------------------------------
local World = Window:AddTab("World")
local count = 0
World:AddLiveLabel("Tracked objects", function() count = count + 1 return count end, 1)
local bar = World:AddProgress("Scan", 0, { Suffix = "%" })
World:AddButton("RUN SCAN", function()
    bar:Set(100)
    Window:Notify({ Title = "Scan", Text = "Scan finished", Type = "success" })
end)

----------------------------------------------------------------
-- Misc tab
----------------------------------------------------------------
local Misc = Window:AddTab("Misc")
Misc:AddKeybind("Toggle GUI", "PageUp", function() Window:Toggle() end)
Misc:AddKeybind("Hold to peek", "LeftAlt", function(down) print("peek", down) end, { Mode = "Hold" })
Misc:AddDropdown("Theme", { "Default", "Crimson", "Emerald", "Ocean", "Amber", "Violet", "Rose", "Mono" },
    "Default", function(v) Window:SetTheme(v) end, { List = true })

Misc:AddSection("Configs", false):AddConfigSection("Save / Load")

Misc:AddHeading("Credits")
Misc:AddParagraph("Made by Evol\nbScripts · Apocalypse Rising 2 ESP\nEverything off by default")
local discord
discord = Misc:AddButton("JOIN DISCORD", function()
    if setclipboard then
        setclipboard("https://discord.gg/aQUSCJmgxh")
        discord:Flash("LINK COPIED")
    end
end)

-- Read any value anywhere:  UI.Flags.ESP, UI.Flags.MaxDist, UI.Flags.BoxColour (Color3) ...
