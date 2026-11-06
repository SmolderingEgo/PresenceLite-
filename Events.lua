--[[
    Presence Lite - Events
    Zone / subzone / discovery, quest accept / progress / ready / complete, level up.
    Also hides the matching default Blizzard text when enabled.
]]

local ADDON, ns = ...
local PL = ns.PL

local ev = CreateFrame("Frame")

local function IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function Clean(s)
    if type(s) ~= "string" or IsSecret(s) then return "" end
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return strtrim(s)
end

-- Turn a Blizzard format string ("Discovered: %s") into a Lua pattern.
local function FormatToPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local p = fmt:gsub("%%%d?%$?([sd])", "\001%1")
    p = p:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("\001s", "(.+)"):gsub("\001d", "(%%d+)")
    return "^" .. p .. "$"
end

local DISCOVERY_PATTERNS = {}
local QUEST_DONE_PATTERNS = {}
local QUEST_ACCEPT_PATTERNS = {}
do
    for _, g in ipairs({ "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP" }) do
        local p = FormatToPattern(_G[g])
        if p then DISCOVERY_PATTERNS[#DISCOVERY_PATTERNS + 1] = p end
    end
    for _, g in ipairs({ "ERR_QUEST_OBJECTIVE_COMPLETE_S", "ERR_QUEST_COMPLETE_S", "ERR_QUEST_UNKNOWN_COMPLETE" }) do
        local p = FormatToPattern(_G[g])
        if p then QUEST_DONE_PATTERNS[#QUEST_DONE_PATTERNS + 1] = p end
    end
    for _, g in ipairs({ "ERR_QUEST_ACCEPTED_S" }) do
        local p = FormatToPattern(_G[g])
        if p then QUEST_ACCEPT_PATTERNS[#QUEST_ACCEPT_PATTERNS + 1] = p end
    end
end

local function MatchesAny(msg, list)
    for _, p in ipairs(list) do
        if msg:match(p) then return true end
    end
    return false
end

-- "Red Leather Bandana: 3/10" -> "3/10 Red Leather Bandana"
local function NormalizeObjective(s)
    s = Clean(s)
    if s == "" or s:match("^%d+/%d+%s") then return s end
    local text, x, y = s:match("^(.+):%s*(%d+)/(%d+)$")
    if text then
        s = ("%s/%s %s"):format(x, y, strtrim(text))
    else
        local text2, x2, y2 = s:match("^(.+)%s*%((%d+)/(%d+)%)$")
        if text2 then s = ("%s/%s %s"):format(x2, y2, strtrim(text2)) end
    end
    -- "0/1 Talk to Gryan" reads better as just "Talk to Gryan"
    s = s:gsub("^%d+/1%s+", "")
    return s
end

local function IsWorldQuest(questID)
    return C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) or false
end

local function IsJunkTitle(name)
    return name == "" or name:find("%[DNT%]") ~= nil
end

-- ============================================================================
-- Blizzard suppression
-- ============================================================================

local hiddenFrames = {}   -- frame -> list of events it had registered
local CANDIDATE_EVENTS = {
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
    "ZONE_UNDER_ATTACK", "PLAYER_ENTERING_WORLD",
}

local function MuteFrame(frame)
    if not frame or hiddenFrames[frame] then return end
    local had = {}
    for _, e in ipairs(CANDIDATE_EVENTS) do
        if frame:IsEventRegistered(e) then
            had[#had + 1] = e
            frame:UnregisterEvent(e)
        end
    end
    hiddenFrames[frame] = had
    frame:Hide()
    if not frame.__plHooked then
        frame.__plHooked = true
        frame:HookScript("OnShow", function(self)
            if hiddenFrames[self] then self:Hide() end
        end)
    end
end

local function UnmuteFrame(frame)
    if not frame or not hiddenFrames[frame] then return end
    for _, e in ipairs(hiddenFrames[frame]) do frame:RegisterEvent(e) end
    hiddenFrames[frame] = nil
end

local errorsMuted = false
local function SetErrorsFrameMuted(on)
    if not UIErrorsFrame or on == errorsMuted then return end
    if on then
        UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
    else
        UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
    end
    errorsMuted = on
end

function ns.ApplyBlizzardSuppression()
    local db = PL.db
    local on = db.enabled
    if on and db.hideBlizzZoneText and (db.showZone or db.showSubzone) then
        MuteFrame(ZoneTextFrame)
        MuteFrame(SubZoneTextFrame)
    else
        UnmuteFrame(ZoneTextFrame)
        UnmuteFrame(SubZoneTextFrame)
    end
    SetErrorsFrameMuted(on and db.hideBlizzQuestText and true or false)
end

-- Re-send info messages we don't replace back to Blizzard's center text.
local function ForwardInfoMessage(msgType, msg)
    if not UIErrorsFrame then return end
    local r, g, b = 1, 1, 0
    if YELLOW_FONT_COLOR then r, g, b = YELLOW_FONT_COLOR:GetRGB() end
    if UIErrorsFrame.TryDisplayMessage then
        UIErrorsFrame:TryDisplayMessage(msgType, msg, r, g, b)
    else
        UIErrorsFrame:AddMessage(msg, r, g, b, 1)
    end
end

-- Level-up toast lives in EventToastManagerFrame; fade it out briefly instead of killing all toasts.
local toastRestoreTimer
local function HideLevelUpToast()
    local etm = EventToastManagerFrame
    if not etm then return end
    etm:SetAlpha(0)
    if toastRestoreTimer then toastRestoreTimer:Cancel() end
    toastRestoreTimer = C_Timer.NewTimer(7, function()
        toastRestoreTimer = nil
        etm:SetAlpha(1)
    end)
end

-- ============================================================================
-- Zones
-- ============================================================================

local lastZone
local lastSub
local zoneTimer
local zoneQuietUntil = 0

local function GetPvPType()
    if C_PvP and C_PvP.GetZonePVPInfo then
        return (C_PvP.GetZonePVPInfo())
    elseif GetZonePVPInfo then
        return (GetZonePVPInfo())
    end
end

local function FireZone(isNewArea)
    zoneTimer = nil
    if GetTime() < zoneQuietUntil then
        lastZone = GetZoneText()
        return
    end
    local db = PL.db
    local zone = Clean(GetZoneText())
    local subz = Clean(GetSubZoneText())
    if zone == "" then return end
    local pvp = GetPvPType()

    if isNewArea or zone ~= lastZone then
        lastZone = zone
        lastSub = subz
        if not db.showZone then return end
        PL:Queue("ZONE_CHANGE", zone, (subz ~= zone) and subz or "", { zone = zone, pvpType = pvp })
    else
        local prev = lastSub
        lastSub = subz
        if subz == prev or subz == "" or subz == zone then return end
        if not db.showSubzone then return end
        PL:Queue("SUBZONE_CHANGE", subz, zone, { zone = zone, pvpType = pvp })
    end
end

local pendingNewArea = false
local function ScheduleZone(isNewArea)
    pendingNewArea = pendingNewArea or isNewArea
    if zoneTimer then zoneTimer:Cancel() end
    zoneTimer = C_Timer.NewTimer(0.25, function()
        local n = pendingNewArea
        pendingNewArea = false
        FireZone(n)
    end)
end

-- ============================================================================
-- Quests
-- ============================================================================

local cache = {}       -- questID -> { complete = bool, objs = { {text, nf, nr, fin}, ... } }
local titles = {}      -- questID -> title (kept so turn-ins still have a name)
local scanTimer
local questQuietUntil = 0

local function ReadObjectives(questID)
    local out = {}
    local objs = C_QuestLog.GetQuestObjectives(questID)
    if objs then
        for i, o in ipairs(objs) do
            out[i] = { text = o.text or "", nf = o.numFulfilled, nr = o.numRequired, fin = o.finished and true or false }
        end
    end
    return out
end

local function ScanQuestLog()
    scanTimer = nil
    local db = PL.db
    local silent = GetTime() < questQuietUntil
    local seen = {}
    local n = C_QuestLog.GetNumQuestLogEntries() or 0

    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID and info.questID > 0 then
            local id = info.questID
            seen[id] = true
            if info.title and info.title ~= "" then titles[id] = Clean(info.title) end

            local new = { complete = C_QuestLog.IsComplete(id) and true or false, objs = ReadObjectives(id) }
            local old = cache[id]
            cache[id] = new

            local name = titles[id] or ""
            if old and not silent and not IsJunkTitle(name) then
                if new.complete and not old.complete and db.showQuestReady then
                    PL:Queue("QUEST_READY", "OBJECTIVES COMPLETE", name, { questID = id })
                elseif db.showQuestProgress then
                    for k, o in ipairs(new.objs) do
                        local p = old.objs[k]
                        local changed = p and (o.nf ~= p.nf or o.fin ~= p.fin or o.text ~= p.text)
                        local forward = p and ((o.nf or 0) > (p.nf or 0) or (o.fin and not p.fin))
                        if changed and forward and o.text ~= "" then
                            local heading = db.questNameAsTitle and name or "QUEST UPDATE"
                            PL:Queue("QUEST_UPDATE", heading, NormalizeObjective(o.text), { questID = id })
                            break
                        end
                    end
                end
            end
        end
    end

    for id in pairs(cache) do
        if not seen[id] then cache[id] = nil end
    end
end

local function ScheduleScan(delay)
    if scanTimer then return end
    scanTimer = C_Timer.NewTimer(delay or 0.3, ScanQuestLog)
end

local function OnQuestAccepted(questID)
    if not questID then return end
    -- Give the log a moment so the title is available.
    C_Timer.After(0.2, function()
        local db = PL.db
        local idx = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = idx and C_QuestLog.GetInfo(idx)
        if info and info.isHidden then return end
        local name = Clean(C_QuestLog.GetTitleForQuestID(questID) or (info and info.title) or "")
        if IsJunkTitle(name) then return end
        titles[questID] = name
        cache[questID] = { complete = C_QuestLog.IsComplete(questID) and true or false, objs = ReadObjectives(questID) }

        if IsWorldQuest(questID) then
            if db.showWorldQuestAccept then
                PL:Queue("WORLD_QUEST_ACCEPT", "WORLD QUEST ACCEPTED", name, { questID = questID })
            end
        elseif db.showQuestAccept then
            PL:Queue("QUEST_ACCEPT", "QUEST ACCEPTED", name, { questID = questID })
        end
    end)
end

local function OnQuestTurnedIn(questID)
    if not questID then return end
    local db = PL.db
    -- Only quests we saw in the visible log (skips hidden tracking-flag quests).
    local name = titles[questID]
    if not name and IsWorldQuest(questID) then
        name = Clean(C_QuestLog.GetTitleForQuestID(questID) or "")
    end
    cache[questID] = nil
    titles[questID] = nil
    PL:PurgeQuest(questID)
    if not name or IsJunkTitle(name) or not db.showQuestComplete then return end

    if IsWorldQuest(questID) then
        PL:Queue("WORLD_QUEST", "WORLD QUEST COMPLETE", name, { questID = questID })
    else
        PL:Queue("QUEST_COMPLETE", "QUEST COMPLETE", name, { questID = questID })
    end
end

-- ============================================================================
-- Info messages (discovery detection + hiding Blizzard's yellow quest text)
-- ============================================================================

local function OnInfoMessage(msgType, msg)
    if type(msg) ~= "string" or IsSecret(msg) then
        if errorsMuted and msg then ForwardInfoMessage(msgType, msg) end
        return
    end
    local db = PL.db

    if MatchesAny(msg, DISCOVERY_PATTERNS) then
        PL:OnDiscovery()
        if errorsMuted and not (db.showDiscovery and (db.showZone or db.showSubzone)) then
            ForwardInfoMessage(msgType, msg)
        end
        return
    end

    if errorsMuted then
        local isProgress = msg:find("%d+/%d+") or MatchesAny(msg, QUEST_DONE_PATTERNS)
        local isAccept = MatchesAny(msg, QUEST_ACCEPT_PATTERNS)
        local swallow = (isProgress and (db.showQuestProgress or db.showQuestReady))
            or (isAccept and db.showQuestAccept)
        if not swallow then ForwardInfoMessage(msgType, msg) end
    end
end

-- ============================================================================
-- Dispatch
-- ============================================================================

local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    PL:InitDB()
    -- Backup "Discovered" detection in case the message reaches the center text some other way.
    if UIErrorsFrame and not ns.errorsHooked then
        ns.errorsHooked = true
        hooksecurefunc(UIErrorsFrame, "AddMessage", function(_, msg)
            if type(msg) == "string" and not IsSecret(msg) and MatchesAny(msg, DISCOVERY_PATTERNS) then
                PL:OnDiscovery()
            end
        end)
    end
    if ns.BuildOptions then
        local ok, err = pcall(ns.BuildOptions)
        if not ok then PL:Print("Settings panel failed to load (" .. tostring(err) .. "). Slash commands still work: /pl help") end
    end
    PL:ApplySettings()
end

function handlers.PLAYER_ENTERING_WORLD(isLogin, isReload)
    lastZone = Clean(GetZoneText())
    lastSub = Clean(GetSubZoneText())
    if isLogin or isReload then
        zoneQuietUntil = GetTime() + 2
        questQuietUntil = GetTime() + 3
        wipe(cache)
    end
    ns.ApplyBlizzardSuppression()
    ScheduleScan(0.5)
end

function handlers.ZONE_CHANGED_NEW_AREA()
    ScheduleZone(true)
end

function handlers.ZONE_CHANGED()
    ScheduleZone(false)
end
handlers.ZONE_CHANGED_INDOORS = handlers.ZONE_CHANGED

function handlers.QUEST_LOG_UPDATE()
    ScheduleScan(0.3)
end
handlers.QUEST_WATCH_UPDATE = handlers.QUEST_LOG_UPDATE
handlers.UNIT_QUEST_LOG_CHANGED = function(unit)
    if unit == "player" then ScheduleScan(0.3) end
end

function handlers.QUEST_ACCEPTED(questID)
    OnQuestAccepted(questID)
end

function handlers.QUEST_TURNED_IN(questID)
    OnQuestTurnedIn(questID)
end

function handlers.QUEST_REMOVED(questID)
    -- Abandoned (turn-ins are handled by QUEST_TURNED_IN, which fires first).
    if questID then
        cache[questID] = nil
        PL:PurgeQuest(questID)
    end
end

function handlers.PLAYER_LEVEL_UP(level)
    local db = PL.db
    if not db.enabled or not db.showLevelUp then return end
    if db.hideBlizzLevelUp then HideLevelUpToast() end
    PL:Queue("LEVEL_UP", "LEVEL UP", ("You have reached level %s"):format(tostring(level or "??")))
end

function handlers.UI_INFO_MESSAGE(msgType, msg)
    OnInfoMessage(msgType, msg)
end

ev:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if not fn then return end
    if event ~= "ADDON_LOADED" and not PL.db then return end
    fn(...)
end)

for event in pairs(handlers) do
    if event == "UNIT_QUEST_LOG_CHANGED" then
        ev:RegisterUnitEvent(event, "player")
    else
        ev:RegisterEvent(event)
    end
end
