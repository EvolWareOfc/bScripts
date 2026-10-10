-- Example: the original bScripts window rebuilt with the library (UI only).
-- Swap the loadstring line for wherever you host bScriptsUI.lua.
local UI = loadstring(game:HttpGet("YOUR_RAW_URL/bScriptsUI.lua"))()

local CFG = { ESP = false, Chams = false, BoxStyle = "Corner", MaxDist = 5000 }

local Window = UI:CreateWindow({
    Title = "bScripts",
    Subtitle = "apoc2",
    Version = "0.1.1",
    ToggleKey = "PageUp",
})

local Players = Window:AddTab("Players")
Players:AddToggle("ESP Master", CFG.ESP, function(v) CFG.ESP = v end)
Players:AddToggle("Chams", CFG.Chams, function(v) CFG.Chams = v end, true)
Players:AddDropdown("Box Style", { "2D", "Corner", "3D" }, CFG.BoxStyle, function(v) CFG.BoxStyle = v end)
Players:AddSlider("Max Distance", 0, 5000, CFG.MaxDist, function(v) CFG.MaxDist = v end, { Increment = 50, Suffix = "m" })

local World = Window:AddTab("World")
local status = World:AddLabel("P:0 Z:0 V:0 C:0 L:0 F:0")
-- status:SetText("P:3 Z:12 ...")

local Misc = Window:AddTab("Misc")
Misc:AddKeybind("Toggle GUI", "PageUp", function() Window:Toggle() end)
Misc:AddHeading("Credits")
Misc:AddParagraph("Made by Evol\nbScripts · Apocalypse Rising 2 ESP\nEverything off by default")
local discord = Misc:AddButton("JOIN DISCORD", function()
    if setclipboard then
        setclipboard("https://discord.gg/aQUSCJmgxh")
        -- feedback handled below
    end
end)
