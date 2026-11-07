--[[
    Presence Lite - Options
    Settings panel (Esc > Options > AddOns > Presence Lite) and slash commands.
]]

local ADDON, ns = ...
local PL = ns.PL

-- ============================================================================
-- Fonts (built-in + anything registered with LibSharedMedia)
-- ============================================================================

local BUILTIN_FONTS = {
    { "Friz Quadrata (default)", "Fonts\\FRIZQT__.TTF" },
    { "Morpheus",                "Fonts\\MORPHEUS.TTF" },
    { "Skurri",                  "Fonts\\SKURRI.TTF" },
    { "Arial Narrow",            "Fonts\\ARIALN.TTF" },
}

local function GetFontList()
    local list, seen = {}, {}
    for _, f in ipairs(BUILTIN_FONTS) do
        list[#list + 1] = f
        seen[f[2]:lower()] = true
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            local path = LSM:Fetch("font", name)
            if path and not seen[path:lower()] then
                seen[path:lower()] = true
                list[#list + 1] = { name, path }
            end
        end
    end
    return list
end

-- ============================================================================
-- Colour picker
-- ============================================================================

local function PickColor(key)
    local c = PL.db.colors[key]
    local r, g, b = c[1], c[2], c[3]
    local function apply(nr, ng, nb)
        c[1], c[2], c[3] = nr, ng, nb
        PL:ApplySettings()
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b,
        hasOpacity = false,
        swatchFunc = function()
            apply(ColorPickerFrame:GetColorRGB())
        end,
        cancelFunc = function()
            apply(r, g, b)
        end,
    })
end

-- ============================================================================
-- Settings panel
-- ============================================================================

function ns.BuildOptions()
    local db = PL.db
    local category, layout = Settings.RegisterVerticalLayoutCategory("Presence Lite")
    ns.category = category

    local function onChange()
        PL:ApplySettings()
    end

    local settings = {}
    local function Register(key, label, callback)
        local setting = Settings.RegisterAddOnSetting(category, "PresenceLite_" .. key, key, db,
            type(ns.DEFAULTS[key]), label, ns.DEFAULTS[key])
        if setting.SetValueChangedCallback then
            setting:SetValueChangedCallback(callback or onChange)
        end
        settings[key] = setting
        return setting
    end

    -- Lets presets update the controls so the panel shows the new values.
    ns.SyncSetting = function(key, value)
        local setting = settings[key]
        if setting and setting.GetValue and setting:GetValue() ~= value then
            setting:SetValue(value)
        end
    end

    local function Header(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function Check(key, label, tooltip)
        Settings.CreateCheckbox(category, Register(key, label), tooltip)
    end

    local function Slider(key, label, minV, maxV, step, fmt, tooltip)
        local setting = Register(key, label)
        local opts = Settings.CreateSliderOptions(minV, maxV, step)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
            return (fmt or "%d"):format(v)
        end)
        Settings.CreateSlider(category, setting, opts, tooltip)
    end

    local function Dropdown(key, label, getOptions, tooltip, callback)
        Settings.CreateDropdown(category, Register(key, label, callback), getOptions, tooltip)
    end

    local function FontOptions()
        local c = Settings.CreateControlTextContainer()
        for _, f in ipairs(GetFontList()) do c:Add(f[2], f[1]) end
        return c:GetData()
    end

    local function Button(label, buttonText, onClick, tooltip)
        layout:AddInitializer(CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true))
    end

    -- General ---------------------------------------------------------------
    Header("General")
    Check("enabled", "Enable Presence Lite", "Master switch for every pop-up.")
    Dropdown("style", "Style", function()
        local c = Settings.CreateControlTextContainer()
        c:Add("midnight", ns.PRESETS.midnight.label)
        c:Add("forever", ns.PRESETS.forever.label)
        return c:GetData()
    end, "Midnight: clean Horizon look. Forever: gold Morpheus titles, ornate gold divider, dark banner and a slow classic fade. Picking one sets fonts, sizes, colours and timing; you can still change any of them below.",
    function(_, value)
        PL:ApplyPreset(value)
    end)
    Button("Preview", "Run test", function() PL:RunTest() end, "Plays a zone, quest progress, quest complete and level-up pop-up.")
    Button("Position", "Unlock / lock", function() PL:SetUnlocked(not PL.unlocked) end, "Shows a box you can drag. Click again (or /pl lock) when done.")

    -- Zones -------------------------------------------------------------------
    Header("Zones")
    Check("showZone", "Zone changes", "When you enter a new zone, e.g. Westfall.")
    Check("showSubzone", "Subzone changes", "When you move into an area inside a zone, e.g. Sentinel Hill.")
    Check("showDiscovery", "\"Discovered\" line", "Adds a green Discovered line the first time you visit an area.")
    Check("zonePvPColors", "Colour zone name by PvP status", "Green friendly, red hostile, orange contested, blue sanctuary. Overrides the zone title colour.")
    Check("hideBlizzZoneText", "Hide Blizzard's zone text", "Hides the default zone and subzone text in the middle of the screen.")

    -- Quests ------------------------------------------------------------------
    Header("Quests")
    Check("showQuestAccept", "Quest accepted")
    Check("showWorldQuestAccept", "World quest accepted")
    Check("showQuestProgress", "Objective progress", "E.g. 7/15 Red Leather Bandana.")
    Check("questNameAsTitle", "Use quest name as progress title", "Off shows QUEST UPDATE as the title instead.")
    Check("showQuestReady", "All objectives complete", "When a quest is ready to turn in.")
    Check("showQuestComplete", "Quest turned in")
    Check("hideBlizzQuestText", "Hide Blizzard's yellow quest text", "Hides the default yellow objective / Discovered text in the middle of the screen. Other yellow messages still show.")

    -- Level up ---------------------------------------------------------------
    Header("Level up")
    Check("showLevelUp", "Level up")
    Check("hideBlizzLevelUp", "Hide Blizzard's level-up banner", "Fades out the default toast for a few seconds after you level.")

    -- When to stay quiet ----------------------------------------------------
    Header("Stay quiet")
    Check("hideInCombat", "Hide during combat", "Level ups still show.")
    Check("hideInInstances", "Hide in dungeons and raids")

    -- Look ----------------------------------------------------------------------
    Header("Text")
    Dropdown("font", "Title font", FontOptions, "Install SharedMedia to get more fonts in this list.")
    Dropdown("subFont", "Subtitle font", FontOptions)
    Dropdown("outline", "Outline", function()
        local c = Settings.CreateControlTextContainer()
        c:Add("NONE", "None")
        c:Add("OUTLINE", "Thin")
        c:Add("THICKOUTLINE", "Thick")
        return c:GetData()
    end)
    Check("shadow", "Drop shadow")
    Slider("titleSize", "Title size", 16, 72, 1)
    Slider("subSize", "Subtitle size", 10, 40, 1)
    Slider("discoverySize", "\"Discovered\" size", 10, 32, 1)
    Check("showDivider", "Divider line")
    Dropdown("dividerStyle", "Divider style", function()
        local c = Settings.CreateControlTextContainer()
        c:Add("line", "Thin line")
        c:Add("ornate", "Ornate gold (Forever)")
        return c:GetData()
    end)
    Dropdown("ornament", "Ornate centrepiece", function()
        local c = Settings.CreateControlTextContainer()
        c:Add("diamond", "Gold diamond")
        c:Add("blizzard", "Blizzard filigree")
        c:Add("none", "None")
        return c:GetData()
    end, "The piece in the middle of the ornate divider.")
    Slider("dividerWidth", "Divider width", 100, 800, 10)

    Check("backdrop", "Dark banner behind text", "A soft dark band that fades out at the sides. Helps readability in bright zones.")
    Slider("backdropAlpha", "Banner darkness", 0.1, 1, 0.05, "%.2f")

    -- Position & timing -----------------------------------------------------
    Header("Position and timing")
    Slider("scale", "Scale", 0.5, 2, 0.05, "%.2f")
    Slider("posX", "Horizontal offset", -1200, 1200, 1)
    Slider("posY", "Vertical offset (from top)", -1100, 0, 1)
    Check("slide", "Slide text in and out", "Off gives a straight classic fade.")
    Slider("fadeIn", "Fade-in time", 0.1, 2, 0.05, "%.2fs")
    Slider("fadeOut", "Fade-out time", 0.1, 2, 0.05, "%.2fs")
    Slider("holdScale", "On-screen time", 0.5, 3, 0.05, "x%.2f", "Multiplies how long each pop-up stays (zone 4s, progress 2.5s, level up 5s at x1).")

    -- Colours -----------------------------------------------------------------
    Header("Colours")
    local COLOR_LABELS = {
        { "zone",       "Zone / subzone title" },
        { "subzone",    "Zone subtitle" },
        { "discovery",  "\"Discovered\"" },
        { "quest",      "Quest accepted / complete title" },
        { "questSub",   "Quest subtitle" },
        { "progress",   "Objective progress title" },
        { "worldQuest", "World quest" },
        { "levelUp",    "Level up / objectives complete" },
        { "divider",    "Divider" },
    }
    for _, entry in ipairs(COLOR_LABELS) do
        local key = entry[1]
        Button(entry[2], "Pick colour", function() PickColor(key) end)
    end
    Button("Colours", "Reset colours", function() PL:ResetColors() end)

    Settings.RegisterAddOnCategory(category)
end

-- ============================================================================
-- Slash commands
-- ============================================================================

local function OpenOptions()
    if ns.category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(ns.category:GetID())
    else
        PL:Print("Settings panel not available. Try /pl help")
    end
end

SLASH_PRESENCELITE1 = "/pl"
SLASH_PRESENCELITE2 = "/presencelite"
SlashCmdList.PRESENCELITE = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "" or msg == "config" or msg == "options" then
        OpenOptions()
    elseif msg == "test" then
        PL:RunTest()
    elseif msg == "unlock" or msg == "move" then
        PL:SetUnlocked(true)
    elseif msg == "lock" then
        PL:SetUnlocked(false)
    elseif msg == "on" or msg == "off" or msg == "toggle" then
        if msg == "toggle" then PL.db.enabled = not PL.db.enabled else PL.db.enabled = (msg == "on") end
        PL:ApplySettings()
        PL:Print(PL.db.enabled and "enabled" or "disabled")
    elseif msg == "forever" or msg == "midnight" then
        PL:ApplyPreset(msg)
        PL:Print("style set to " .. ns.PRESETS[msg].label)
        PL:RunTest()
    elseif msg == "reset" then
        PL:ResetDB()
        PL:Print("settings reset. /reload to refresh the options panel.")
    else
        PL:Print("commands:")
        print("  /pl - open settings")
        print("  /pl test - play sample pop-ups")
        print("  /pl unlock | lock - drag to reposition")
        print("  /pl forever | midnight - switch style")
        print("  /pl on | off | toggle")
        print("  /pl reset - restore defaults")
    end
end
