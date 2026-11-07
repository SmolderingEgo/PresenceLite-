--[[
    Presence Lite - Core
    Display frame, animation, queue and saved settings.
    Visual style and queue rules adapted from Horizon Suite's Presence module
    (https://github.com/Tacit-Labs/Horizon-Suite, MIT License, (c) 2026 Crystilac).
]]

local ADDON, ns = ...

local PL = CreateFrame("Frame", "PresenceLiteFrame", UIParent)
ns.PL = PL
_G.PresenceLite = PL

-- ============================================================================
-- Defaults
-- ============================================================================

ns.DEFAULTS = {
    enabled              = true,

    -- What to show
    showZone             = true,
    showSubzone          = true,
    showDiscovery        = true,
    showQuestAccept      = true,
    showWorldQuestAccept = true,
    showQuestProgress    = true,
    showQuestReady       = true,
    showQuestComplete    = true,
    showLevelUp          = true,

    -- Behaviour
    hideBlizzZoneText    = true,   -- hide the default zone/subzone text
    hideBlizzLevelUp     = true,   -- hide the default level-up toast
    hideBlizzQuestText   = true,   -- hide the yellow "Bandana: 3/10" and "Discovered" center text
    zonePvPColors        = false,  -- colour zone names green/red/orange by PvP status
    questNameAsTitle     = true,   -- progress pop-up: quest name as title (else "QUEST UPDATE")
    hideInCombat         = false,
    hideInInstances      = false,  -- dungeons and raids

    -- Look
    style                = "midnight",
    font                 = "Fonts\\FRIZQT__.TTF",
    subFont              = "Fonts\\FRIZQT__.TTF",
    dividerStyle         = "line",     -- "line" or "ornate"
    backdrop             = false,      -- dark banner behind the text
    slide                = true,       -- slide text in/out (off = classic straight fade)
    outline              = "OUTLINE",
    shadow               = true,
    titleSize            = 48,
    subSize              = 24,
    discoverySize        = 16,
    showDivider          = true,
    dividerWidth         = 400,

    -- Position and timing
    scale                = 1.0,
    posX                 = 0,
    posY                 = -180,
    fadeIn               = 0.7,
    fadeOut              = 0.8,
    holdScale            = 1.0,

    colors = {
        zone       = { 0.90, 0.90, 0.90 },
        subzone    = { 1.00, 0.82, 0.20 },
        discovery  = { 0.40, 1.00, 0.50 },
        quest      = { 0.90, 0.90, 0.90 },
        questSub   = { 1.00, 1.00, 1.00 },
        worldQuest = { 0.78, 0.42, 0.95 },
        progress   = { 0.90, 0.90, 0.90 },
        levelUp    = { 0.20, 1.00, 0.40 },
        divider    = { 1.00, 1.00, 1.00 },
    },
}

-- Style presets: picking one writes these values; everything stays tweakable afterwards.
ns.PRESETS = {
    midnight = {
        label = "Midnight (Horizon)",
        values = {
            font = "Fonts\\FRIZQT__.TTF", subFont = "Fonts\\FRIZQT__.TTF", outline = "OUTLINE", shadow = true,
            titleSize = 48, subSize = 24, discoverySize = 16,
            showDivider = true, dividerStyle = "line", dividerWidth = 400,
            backdrop = false, slide = true, fadeIn = 0.7, fadeOut = 0.8,
        },
        colors = {
            zone = { 0.90, 0.90, 0.90 }, subzone = { 1.00, 0.82, 0.20 }, discovery = { 0.40, 1.00, 0.50 },
            quest = { 0.90, 0.90, 0.90 }, questSub = { 1.00, 1.00, 1.00 }, worldQuest = { 0.78, 0.42, 0.95 },
            progress = { 0.90, 0.90, 0.90 }, levelUp = { 0.20, 1.00, 0.40 }, divider = { 1.00, 1.00, 1.00 },
        },
    },
    forever = {
        label = "Forever (classic gold)",
        values = {
            font = "Fonts\\MORPHEUS.TTF", subFont = "Fonts\\FRIZQT__.TTF", outline = "OUTLINE", shadow = true,
            titleSize = 54, subSize = 22, discoverySize = 15,
            showDivider = true, dividerStyle = "ornate", dividerWidth = 440,
            backdrop = true, slide = false, fadeIn = 1.0, fadeOut = 1.2,
        },
        colors = {
            zone = { 1.00, 0.82, 0.00 }, subzone = { 0.96, 0.89, 0.72 }, discovery = { 0.35, 0.88, 0.82 },
            quest = { 1.00, 0.82, 0.00 }, questSub = { 0.96, 0.89, 0.72 }, worldQuest = { 0.80, 0.55, 1.00 },
            progress = { 1.00, 0.82, 0.00 }, levelUp = { 1.00, 0.93, 0.50 }, divider = { 0.98, 0.78, 0.28 },
        },
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function PL:InitDB()
    if type(PresenceLiteDB) ~= "table" then PresenceLiteDB = {} end
    CopyDefaults(ns.DEFAULTS, PresenceLiteDB)
    self.db = PresenceLiteDB
end

function PL:ResetDB()
    wipe(PresenceLiteDB)
    CopyDefaults(ns.DEFAULTS, PresenceLiteDB)
    self.db = PresenceLiteDB
    self:ApplySettings()
end

function PL:ResetColors()
    self.db.colors = {}
    CopyDefaults(ns.DEFAULTS.colors, self.db.colors)
    self:ApplySettings()
end

-- Apply a style preset. ns.SyncSetting (from Options) keeps the settings panel in step.
function PL:ApplyPreset(name)
    local preset = ns.PRESETS[name]
    if not preset then return end
    self.db.style = name
    for k, v in pairs(preset.values) do
        if ns.SyncSetting then ns.SyncSetting(k, v) end
        self.db[k] = v
    end
    for k, c in pairs(preset.colors) do
        self.db.colors[k] = { c[1], c[2], c[3] }
    end
    self:ApplySettings()
end

function PL:Print(msg)
    print("|cff33ffddPresence Lite|r: " .. tostring(msg))
end

-- ============================================================================
-- Notification types
--   pri:   higher plays first when several are queued
--   size:  L / M / S text scale
--   dur:   seconds held on screen (times holdScale)
--   color / subColor: keys into db.colors
-- ============================================================================

local TYPES = {
    LEVEL_UP           = { pri = 4, size = "L", dur = 5.0, color = "levelUp",    subColor = "questSub" },
    QUEST_COMPLETE     = { pri = 3, size = "L", dur = 4.0, color = "quest",      subColor = "questSub" },
    WORLD_QUEST        = { pri = 3, size = "L", dur = 4.0, color = "worldQuest", subColor = "questSub" },
    ZONE_CHANGE        = { pri = 2, size = "L", dur = 4.0, color = "zone",       subColor = "subzone", zoneish = true },
    QUEST_READY        = { pri = 2, size = "M", dur = 3.0, color = "levelUp",    subColor = "questSub" },
    WORLD_QUEST_ACCEPT = { pri = 2, size = "M", dur = 3.0, color = "worldQuest", subColor = "questSub" },
    QUEST_ACCEPT       = { pri = 1, size = "M", dur = 3.0, color = "quest",      subColor = "questSub" },
    SUBZONE_CHANGE     = { pri = 1, size = "M", dur = 3.0, color = "zone",       subColor = "subzone", zoneish = true },
    QUEST_UPDATE       = { pri = 1, size = "S", dur = 2.5, color = "progress",   subColor = "questSub" },
}
ns.TYPES = TYPES

local TITLE_MULT = { L = 1.0, M = 0.75, S = 0.58 }
local SUB_MULT   = { L = 1.0, M = 0.92, S = 0.83 }
local MAX_QUEUE  = 5
local DISCOVERY_WINDOW = 3.0  -- seconds a "Discovered" message waits for its zone pop-up

local PVP_COLORS = {
    sanctuary = { 0.41, 0.80, 0.94 },
    friendly  = { 0.10, 1.00, 0.10 },
    hostile   = { 1.00, 0.10, 0.10 },
    contested = { 1.00, 0.70, 0.00 },
    combat    = { 1.00, 0.10, 0.10 },
}

local DISCOVERED_TEXT = "Discovered"

-- ============================================================================
-- Frame
-- ============================================================================

PL:SetSize(800, 200)
PL:SetFrameStrata("HIGH")
PL:SetClampedToScreen(true)
PL:EnableMouse(false)
PL:Hide()

local moveBG = PL:CreateTexture(nil, "BACKGROUND")
moveBG:SetAllPoints()
moveBG:SetColorTexture(0.2, 1, 0.87, 0.18)
moveBG:Hide()

local moveHint = PL:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
moveHint:SetPoint("BOTTOM", PL, "BOTTOM", 0, 6)
moveHint:SetText("Drag to move  -  /pl lock when done")
moveHint:Hide()

local title = PL:CreateFontString(nil, "OVERLAY")
local divider = PL:CreateTexture(nil, "ARTWORK")
local sub = PL:CreateFontString(nil, "OVERLAY")
local disc = PL:CreateFontString(nil, "OVERLAY")

divider:SetColorTexture(1, 1, 1, 1)
divider:SetHeight(2)

-- Ornate divider (Forever style): double gold rule fading out at the ends, with Blizzard's
-- boss-banner filigree in the middle when the client has that art.
local ornate = CreateFrame("Frame", nil, PL)
ornate:SetSize(400, 30)
local function GradientHalf(parent, height, leftSide)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetHeight(height)
    t.leftSide = leftSide
    return t
end
ornate.l1 = GradientHalf(ornate, 2, true)
ornate.r1 = GradientHalf(ornate, 2, false)
ornate.l2 = GradientHalf(ornate, 1, true)
ornate.r2 = GradientHalf(ornate, 1, false)
ornate.l1:SetPoint("RIGHT", ornate, "CENTER", 0, 2)
ornate.r1:SetPoint("LEFT", ornate, "CENTER", 0, 2)
ornate.l2:SetPoint("RIGHT", ornate, "CENTER", 0, -3)
ornate.r2:SetPoint("LEFT", ornate, "CENTER", 0, -3)
ornate.fill = ornate:CreateTexture(nil, "OVERLAY")
ornate.fill:SetPoint("CENTER", ornate, "CENTER", 0, -1)
ornate.hasFill = false
for _, atlas in ipairs({ "BossBanner-BottomFillagree", "BossBanner-TopFillagree" }) do
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if info then
        ornate.fill:SetAtlas(atlas)
        ornate.fillAspect = (info.width and info.height and info.height > 0) and (info.width / info.height) or 6
        ornate.hasFill = true
        break
    end
end
if not ornate.hasFill then ornate.fill:Hide() end
ornate:Hide()

-- Banner backdrop: dark band that fades out to the sides.
local backdropL = PL:CreateTexture(nil, "BACKGROUND", nil, 1)
local backdropR = PL:CreateTexture(nil, "BACKGROUND", nil, 1)
for _, t in ipairs({ backdropL, backdropR }) do t:SetTexture("Interface\\Buttons\\WHITE8X8") end
backdropL.leftSide = true   -- fade toward the outer edges, darkest in the middle
backdropL:SetPoint("TOPRIGHT", PL, "TOP", 0, 14)
backdropR:SetPoint("TOPLEFT", PL, "TOP", 0, 14)

for _, fs in ipairs({ title, sub, disc }) do
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("TOP")
    fs:SetWidth(780)
    fs:SetWordWrap(true)
    if fs.SetMaxLines then fs:SetMaxLines(2) end
end
disc:SetPoint("TOP", sub, "BOTTOM", 0, -5)

local function ApplyFont(fs, size, path)
    local db = PL.db
    local flags = (db.outline and db.outline ~= "NONE") and db.outline or ""
    if not fs:SetFont(path or db.font, size, flags) then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flags)
    end
    if db.shadow then
        fs:SetShadowColor(0, 0, 0, 0.8)
        fs:SetShadowOffset(2, -2)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function GetColor(key)
    local c = PL.db.colors[key] or ns.DEFAULTS.colors[key] or { 1, 1, 1 }
    return c[1], c[2], c[3]
end

-- ============================================================================
-- Animation state
-- ============================================================================

local anim = { phase = "idle", e = 0, hold = 4, hasDisc = false, subBaseY = -80 }
local active        -- item currently on screen
local queue = {}

local function SetGradientColor(t, r, g, b, a)
    local solid = CreateColor(r, g, b, a)
    local clear = CreateColor(r, g, b, 0)
    if t.leftSide then
        t:SetGradient("HORIZONTAL", clear, solid)
    else
        t:SetGradient("HORIZONTAL", solid, clear)
    end
end

local function SetBackdropState(alpha)
    if not PL.db.backdrop then
        backdropL:Hide()
        backdropR:Hide()
        return
    end
    backdropL:Show()
    backdropR:Show()
    SetGradientColor(backdropL, 0, 0, 0, 0.55 * alpha)
    SetGradientColor(backdropR, 0, 0, 0, 0.55 * alpha)
end

local function SetTitleState(alpha, offset)
    if not PL.db.slide then offset = 0 end
    SetBackdropState(alpha)
    title:SetAlpha(alpha)
    title:SetPoint("TOP", PL, "TOP", 0, offset)
end

local function SetSubState(alpha, offset)
    if not PL.db.slide then offset = 0 end
    sub:SetAlpha(alpha)
    sub:SetPoint("TOP", PL, "TOP", 0, anim.subBaseY + offset)
end

local function SetDividerState(progress)
    local db = PL.db
    if not db.showDivider then
        divider:Hide()
        ornate:Hide()
        return
    end
    if db.dividerStyle == "ornate" then
        divider:Hide()
        ornate:Show()
        local half = math.max(1, db.dividerWidth * 0.5 * progress)
        local c = db.colors.divider
        for _, t in ipairs({ ornate.l1, ornate.r1 }) do
            t:SetWidth(half)
            SetGradientColor(t, c[1], c[2], c[3], 0.95 * progress)
        end
        for _, t in ipairs({ ornate.l2, ornate.r2 }) do
            t:SetWidth(half * 0.8)
            SetGradientColor(t, c[1], c[2], c[3], 0.55 * progress)
        end
        if ornate.hasFill then
            ornate.fill:Show()
            -- Blizzard's art is red; desaturate and tint it to the divider colour.
            ornate.fill:SetDesaturated(true)
            ornate.fill:SetVertexColor(c[1] * 1.15, c[2] * 1.15, c[3] * 1.15)
            ornate.fill:SetAlpha(progress)
        end
    else
        ornate:Hide()
        divider:Show()
        divider:SetAlpha(0.5 * progress)
        divider:SetWidth(math.max(1, db.dividerWidth * progress))
    end
end

local function SetDiscState(alpha)
    disc:SetAlpha(anim.hasDisc and alpha or 0)
end

-- Sizes and anchors for the given type.
local function Layout(cfg)
    local db = PL.db
    local tSize = math.floor(db.titleSize * TITLE_MULT[cfg.size] + 0.5)
    local sSize = math.floor(db.subSize * SUB_MULT[cfg.size] + 0.5)
    ApplyFont(title, tSize, db.font)
    ApplyFont(sub, sSize, db.subFont)
    ApplyFont(disc, db.discoverySize, db.subFont)

    local dividerY = -math.floor(tSize * 1.35 + 0.5)
    divider:ClearAllPoints()
    divider:SetPoint("TOP", PL, "TOP", 0, dividerY)
    anim.subBaseY = dividerY - 12

    if db.dividerStyle == "ornate" then
        ornate:ClearAllPoints()
        ornate:SetPoint("CENTER", PL, "TOP", 0, dividerY - 1)
        if ornate.hasFill then
            local fw = math.min(db.dividerWidth * 0.45, 220)
            ornate.fill:SetSize(fw, fw / (ornate.fillAspect or 6))
            local fh = fw / (ornate.fillAspect or 6)
            anim.subBaseY = dividerY - math.max(12, math.floor(fh * 0.5 + 6))
        end
    end

    local bandH = (-anim.subBaseY) + sSize * 1.3 + db.discoverySize + 34
    local bandW = math.max(db.dividerWidth, 420) * 0.85
    backdropL:SetSize(bandW, bandH)
    backdropR:SetSize(bandW, bandH)
end

local function ApplyColors(item)
    local cfg = TYPES[item.type]
    local r, g, b = GetColor(cfg.color)
    if cfg.zoneish and PL.db.zonePvPColors and item.pvpType and PVP_COLORS[item.pvpType] then
        local c = PVP_COLORS[item.pvpType]
        r, g, b = c[1], c[2], c[3]
    end
    title:SetTextColor(r, g, b, 1)
    sub:SetTextColor(GetColor(cfg.subColor))
    disc:SetTextColor(GetColor("discovery"))
    divider:SetVertexColor(GetColor("divider"))
end

local function ResetVisuals()
    if not PL.db then return end
    SetTitleState(0, 0)
    SetSubState(0, 0)
    SetDividerState(0)
    disc:SetAlpha(0)
end

-- ============================================================================
-- Playback
-- ============================================================================

local PlayNext

local function Play(item)
    active = item
    local cfg = TYPES[item.type]
    Layout(cfg)
    ApplyColors(item)

    title:SetText(item.title or "")
    sub:SetText(item.sub or "")

    anim.hasDisc = false
    if cfg.zoneish and PL.db.showDiscovery then
        if item.discovery then
            anim.hasDisc = true
        elseif PL.pendingDiscovery and (GetTime() - PL.pendingDiscovery) < DISCOVERY_WINDOW then
            anim.hasDisc = true
        end
    end
    if anim.hasDisc then PL.pendingDiscovery = nil end
    disc:SetText(anim.hasDisc and DISCOVERED_TEXT or "")

    anim.phase = "entrance"
    anim.e = 0
    anim.hold = cfg.dur * PL.db.holdScale
    ResetVisuals()
    PL:Show()
end

local function Finish()
    active = nil
    anim.phase = "idle"
    ResetVisuals()
    if not PL.unlocked then PL:Hide() end
    PlayNext()
end

PlayNext = function()
    if PL.unlocked or #queue == 0 then return end
    local bestIdx, bestPri = 1, -1
    for i, q in ipairs(queue) do
        local p = TYPES[q.type].pri
        if p > bestPri then bestIdx, bestPri = i, p end
    end
    Play(table.remove(queue, bestIdx))
end

local function EaseOut(t)
    if t <= 0 then return 0 elseif t >= 1 then return 1 end
    local inv = 1 - t
    return 1 - inv * inv * inv
end

PL:SetScript("OnUpdate", function(self, dt)
    local phase = anim.phase
    if phase == "idle" or phase == "preview" then return end
    anim.e = anim.e + dt
    local db = self.db

    if phase == "entrance" then
        -- Staggered: title, then divider, then subtitle, then "Discovered".
        local k = math.max(db.fadeIn, 0.05) / 0.7
        local elem = 0.4 * k
        local e = anim.e
        local te = EaseOut(e / elem)
        local de = EaseOut((e - 0.15 * k) / elem)
        local se = EaseOut((e - 0.30 * k) / elem)
        local xe = EaseOut((e - 0.45 * k) / elem)
        SetTitleState(te, (1 - te) * 20)
        SetDividerState(de)
        SetSubState(se, (1 - se) * -10)
        SetDiscState(xe)
        if e >= 0.45 * k + elem then
            anim.phase = "hold"
            anim.e = 0
        end
    elseif phase == "hold" then
        if anim.e >= anim.hold then
            anim.phase = "exit"
            anim.e = 0
        end
    elseif phase == "exit" then
        local t = math.min(anim.e / math.max(db.fadeOut, 0.05), 1)
        local inv = 1 - t
        SetTitleState(inv, t * 15)
        SetDividerState(inv)
        SetSubState(inv, t * -10)
        SetDiscState(inv)
        if t >= 1 then Finish() end
    end
end)

-- Update the pop-up already on screen instead of queueing another one.
local function TryMerge(item)
    if not active or (anim.phase ~= "entrance" and anim.phase ~= "hold") then return false end
    local a = active

    if item.type == "QUEST_UPDATE" and a.type == "QUEST_UPDATE" and a.questID == item.questID then
        a.sub = item.sub
        sub:SetText(item.sub)
        if anim.phase == "hold" then anim.e = 0 end
        return true
    end

    if item.type == "SUBZONE_CHANGE" and TYPES[a.type].zoneish and a.zone == item.zone then
        if a.type == "ZONE_CHANGE" then
            a.sub = item.title
            sub:SetText(item.title)
        else
            a.title = item.title
            title:SetText(item.title)
        end
        if anim.phase == "hold" then anim.e = 0 end
        return true
    end

    return false
end

function PL:IsSuppressed(typ)
    local db = self.db
    if db.hideInCombat and typ ~= "LEVEL_UP" and InCombatLockdown() then return true end
    if db.hideInInstances then
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "party" or instanceType == "raid") then return true end
    end
    return false
end

-- Public entry point. opts: questID, zone, pvpType, discovery, force
function PL:Queue(typ, titleText, subText, opts)
    opts = opts or {}
    if not TYPES[typ] then return end
    if not opts.force then
        if not self.db.enabled or self:IsSuppressed(typ) then return end
    end
    if self.unlocked then return end

    local item = {
        type = typ,
        title = titleText or "",
        sub = subText or "",
        questID = opts.questID,
        zone = opts.zone,
        pvpType = opts.pvpType,
        discovery = opts.discovery,
    }

    if not active then
        Play(item)
        return
    end
    if TryMerge(item) then return end
    if active.type == item.type and active.title == item.title and active.sub == item.sub then return end

    for i, q in ipairs(queue) do
        if q.type == item.type and q.title == item.title and q.sub == item.sub then return end
        if item.type == "QUEST_UPDATE" and q.type == "QUEST_UPDATE" and q.questID == item.questID then
            queue[i] = item
            return
        end
    end

    queue[#queue + 1] = item
    while #queue > MAX_QUEUE do
        local lowIdx, lowPri = #queue, math.huge
        for i = #queue, 1, -1 do
            local p = TYPES[queue[i].type].pri
            if p < lowPri then lowIdx, lowPri = i, p end
        end
        table.remove(queue, lowIdx)
    end
end

-- Called when the game reports "Discovered: <area>".
function PL:OnDiscovery()
    if not self.db.enabled or not self.db.showDiscovery then return end
    if active and TYPES[active.type].zoneish and (anim.phase == "entrance" or anim.phase == "hold") then
        if not anim.hasDisc then
            anim.hasDisc = true
            disc:SetText(DISCOVERED_TEXT)
            disc:SetTextColor(GetColor("discovery"))
            if anim.phase == "hold" then
                disc:SetAlpha(1)
                anim.e = 0
            end
        end
        return
    end
    self.pendingDiscovery = GetTime()
end

-- Drop queued progress pop-ups for a quest that was just turned in / abandoned.
function PL:PurgeQuest(questID)
    for i = #queue, 1, -1 do
        if queue[i].type == "QUEST_UPDATE" and queue[i].questID == questID then
            table.remove(queue, i)
        end
    end
end

function PL:ClearAll()
    wipe(queue)
    if active then
        active = nil
        anim.phase = "idle"
        ResetVisuals()
        if not self.unlocked then self:Hide() end
    end
end

-- ============================================================================
-- Positioning / move mode
-- ============================================================================

function PL:ApplyPosition()
    local s = self.db.scale
    self:SetScale(s)
    self:ClearAllPoints()
    self:SetPoint("TOP", UIParent, "TOP", self.db.posX / s, self.db.posY / s)
end

local function ShowPreview()
    local item = { type = "ZONE_CHANGE", title = "Westfall", sub = "Sentinel Hill", pvpType = "friendly" }
    Layout(TYPES.ZONE_CHANGE)
    ApplyColors(item)
    title:SetText(item.title)
    sub:SetText(item.sub)
    anim.hasDisc = PL.db.showDiscovery
    disc:SetText(DISCOVERED_TEXT)
    anim.phase = "preview"
    SetTitleState(1, 0)
    SetDividerState(1)
    SetSubState(1, 0)
    SetDiscState(1)
end

function PL:SetUnlocked(on)
    if on then
        self:ClearAll()
        self.unlocked = true
        moveBG:Show()
        moveHint:Show()
        self:EnableMouse(true)
        self:SetMovable(true)
        self:RegisterForDrag("LeftButton")
        ShowPreview()
        self:Show()
    else
        self.unlocked = false
        moveBG:Hide()
        moveHint:Hide()
        self:EnableMouse(false)
        self:SetMovable(false)
        anim.phase = "idle"
        ResetVisuals()
        self:Hide()
    end
end

PL:SetScript("OnDragStart", function(self)
    if self.unlocked then self:StartMoving() end
end)

PL:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local s = self:GetScale()
    local cx = self:GetCenter()
    local top = self:GetTop()
    local ux = UIParent:GetCenter()
    local utop = UIParent:GetTop()
    self.db.posX = math.floor(cx * s - ux + 0.5)
    self.db.posY = math.floor(top * s - utop + 0.5)
    self:ApplyPosition()
end)

function PL:ApplySettings()
    if not self.db then return end
    self:ApplyPosition()
    if self.unlocked then ShowPreview() end
    if ns.ApplyBlizzardSuppression then ns.ApplyBlizzardSuppression() end
end

-- Plays one of each kind, ignoring the on/off switches.
function PL:RunTest()
    if self.unlocked then self:SetUnlocked(false) end
    local f = { force = true }
    self:Queue("ZONE_CHANGE", "Westfall", "Sentinel Hill", { force = true, discovery = true, zone = "Westfall", pvpType = "friendly" })
    self:Queue("QUEST_UPDATE", "Red Leather Bandanas", "7/15 Red Leather Bandana", { force = true, questID = -1 })
    self:Queue("QUEST_COMPLETE", "QUEST COMPLETE", "Red Leather Bandanas", f)
    self:Queue("LEVEL_UP", "LEVEL UP", "You have reached level 23", f)
end
