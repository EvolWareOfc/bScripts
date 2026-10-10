# bScripts UI Library — v2.0.0

A single-file Roblox UI library extracted from the bScripts Apocalypse Rising 2 script.
Same look and layout as the original window: dark panel, accent bar, Bangers title, underline tabs.
Everything from v1 still works unchanged.

```lua
local UI = loadstring(game:HttpGet("YOUR_RAW_URL/bScriptsUI.lua"))()
local Window = UI:CreateWindow({ Title = "bScripts", Subtitle = "apoc2", Version = "0.1.1", ToggleKey = "PageUp" })
local Tab = Window:AddTab("Main")
Tab:AddToggle("Enabled", false, function(v) print(v) end, false, { Flag = "Enabled" })
print(UI.Flags.Enabled)
```

## Window options
| Option | Meaning |
|---|---|
| `Title`, `Subtitle`, `Version` | Header text. Shows as `Subtitle · vVersion` |
| `Size` | `Vector2`, default `280 x 560` |
| `ToggleKey` | KeyCode name that shows/hides the window |
| `AutoSave` | Config name; flags are loaded on start and saved (debounced) on change |
| `Theme` | Preset name or table (see Themes) |
| `Minimise` / `Resizable` | `false` removes the minimise button / resize grip |
| `MobileButton` | Floating toggle button (auto-enabled on touch-only devices) |
| `Protect` | `false` skips `gethui`/`protect_gui` and parents to CoreGui |

## Elements
Every element takes a trailing `opts` table. **Common opts:** `Flag`, `Tooltip`, `DependsOn`, `Child`, `Enabled`, `Visible`.

| Call | Extra opts |
|---|---|
| `Tab:AddToggle(text, default, cb, indent, opts)` | `DisableChildren` |
| `Tab:AddSlider(text, min, max, default, cb, opts)` | `Increment`, `Suffix` |
| `Tab:AddDropdown(text, options, current, cb, opts)` | `List = true` for a popup list (otherwise click cycles) |
| `Tab:AddMultiDropdown(text, options, defaults, cb, opts)` | callback receives an array |
| `Tab:AddColorPicker(text, color, cb, opts)` | |
| `Tab:AddTextbox(text, default, cb, opts)` | `Placeholder`, `Numeric`, `Live` |
| `Tab:AddKeybind(text, key, cb, opts)` | `Mode`: `Press` (default) / `Toggle` / `Hold` / `Always`. Esc/Backspace clears |
| `Tab:AddButton(text, cb, opts)` | `Color`, `Height` |
| `Tab:AddProgress(text, value, opts)` | `Min`, `Max`, `Suffix`, `Format` |
| `Tab:AddLiveLabel(text, fn, interval)` | |
| `Tab:AddHeading(text)` / `AddLabel(text, h)` / `AddParagraph(text, h)` | |
| `Tab:AddSeparator()` / `AddSpacer(h)` | |
| `Tab:AddSearch(placeholder)` | filters the tab's rows |
| `Tab:AddSection(title, startOpen)` | collapsible; call `section:AddToggle(...)` etc. |
| `Tab:AddConfigSection(title)` | name box, list, Save / Load / Delete / Refresh |

Element objects: `:Set(value, silent)`, `:Get()`, `:SetEnabled(b)`, `:SetVisible(b)`, `:SetTooltip(t)`.
Dropdowns also have `:SetOptions(list)`. Keybinds have `:SetMode(m)`. Buttons have `:Flash(text)`.

**Dependencies:** a toggle created with `DisableChildren = true` greys out the indented toggles after it
while it is off. Use `DependsOn = someToggle` (or `Child = true`) to attach any other element.

## Flags and configs
Give an element a `Flag` and its value lives in `UI.Flags.<Flag>` (Color3 for colour pickers,
`{Key, Mode}` for keybinds, an array for multi dropdowns).

```lua
UI:SaveConfig("legit")   UI:LoadConfig("legit")   UI:DeleteConfig("legit")   UI:ListConfigs()
```
Configs are stored in the `bScriptsUI/` workspace folder and need an executor with file functions.
Loading a config fires each element's callback so your script state updates too.

## Themes
Presets: `Default`, `Crimson`, `Emerald`, `Ocean`, `Amber`, `Violet`, `Rose`, `Mono`.
```lua
Window:SetTheme("Ocean")
Window:SetTheme({ Accent = Color3.fromRGB(255, 140, 0) })
Window:SetAccent(Color3.fromRGB(0, 200, 120))   -- live update
```

## Notifications
```lua
Window:Notify({ Title = "Saved", Text = "Config saved", Type = "success", Duration = 3 })
-- Type: info / success / warning / error      UI:Notify({...}) uses the newest window
```

## Safety / cleanup
* Callbacks run in `pcall`; errors are reported with `warn` and never break the UI.
* `Window:Destroy()` disconnects every connection and removes the window's flags. `UI:Unload()` destroys all windows.
