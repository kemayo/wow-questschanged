local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local icon = LibStub("LibDBIcon-1.0", true)

local db, dbpc
local quests = {}
local new_quests = {}
local session_quests = {}
ns.quests_completed = {}

local SPAM_QUESTS = {
    [32468] = true, -- Crystal Clarity
    [32469] = true, -- Crystal Clarity
}

local Callbacks = CreateFrame("EventFrame")
Callbacks:SetUndefinedEventsAllowed(true)
Callbacks:SetScript("OnEvent", function(self, event, ...)
    self:TriggerEvent(event, event, ...)
end)
Callbacks:RegisterEvent("ADDON_LOADED")
Callbacks:Hide()
ns.Callbacks = Callbacks

Callbacks:GenerateCallbackEvents{
    "OnQuestAdded", "OnQuestRemoved", "OnAllQuestsRemoved",
    "OnVignetteAdded", "OnVignetteRemoved", "OnAllVignettesRemoved",
}
ns.Event = Callbacks.Event

-- help out with callback boilerplate:
function ns:RegisterCallback(event, func)
    if not func and ns[event] then func = ns[event] end
    if not Callbacks:DoesFrameHaveEvent(event) then
        Callbacks:RegisterEvent(event)
    end
    return Callbacks:RegisterCallback(event, func, self)
end
function ns:UnregisterCallback(event)
    if not Callbacks:DoesFrameHaveEvent(event) then
        Callbacks:UnregisterEvent(event)
    end
    return Callbacks:UnregisterCallback(event, self)
end
function ns:TriggerEvent(...)
    return Callbacks:TriggerEvent(...)
end

ns:RegisterCallback("ADDON_LOADED", function(self, event, name)
    if name ~= myname then return end

    _G[myname.."DB"] = setmetatable(_G[myname.."DB"] or {}, {
        __index = {
            minimap = false,
            announce = false,
            showInCompartment=true,
        },
    })
    _G[myname.."DBPC"] = setmetatable(_G[myname.."DBPC"] or {}, {
        __index = {
            -- nothing right now
        },
    })
    db = _G[myname.."DB"]
    dbpc = _G[myname.."DBPC"]
    if not dbpc.log then
        dbpc.log = {}
    end

    ns.db = db
    ns.dbpc = dbpc

    if icon then
        icon:Register(myname, ns.dataobject, db)
    end

    self:UnregisterCallback("ADDON_LOADED")
    if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterCallback("PLAYER_LOGIN") end
end)
function ns:PLAYER_LOGIN()
    -- Quests
    self:RegisterCallback("QUEST_LOG_UPDATE")
    self:RegisterCallback("ENCOUNTER_LOOT_RECEIVED")
    self:UnregisterCallback("PLAYER_LOGIN")

    new_quests = C_QuestLog.GetAllCompletedQuestIDs(new_quests)
    for _, questid in pairs(new_quests) do
        quests[questid] = true
    end

    -- Vignettes
    self:RegisterCallback("PLAYER_ENTERING_WORLD")
    self:RegisterCallback("VIGNETTE_MINIMAP_UPDATED")
    self:RegisterCallback("VIGNETTES_UPDATED")
end
function ns:QUEST_LOG_UPDATE()
    Callbacks:Show()
end
ns.ENCOUNTER_LOOT_RECEIVED = ns.QUEST_LOG_UPDATE

do
    local time_since = 0
    Callbacks:SetScript("OnUpdate", function(self, elapsed)
        time_since = time_since + elapsed
        if time_since < 0.3 then
            return
        end
        ns:CheckQuests()
        time_since = 0
        self:Hide()
    end)
end

ns.quest_names = {}
setmetatable(ns.quest_names, {__index = function(self, key)
    local name = C_QuestLog.GetTitleForQuestID(key)
    if name then
        self[key] = name
        return name
    end
    return false
end,})

function QuestsChangedGetQuestTitle(id)
    return ns.quest_names[id]
end

function ns:CheckQuests()
    if not quests then
        return
    end
    local mapdata, x, y
    new_quests = C_QuestLog.GetAllCompletedQuestIDs(new_quests)
    for _, questid in pairs(new_quests) do
        if not quests[questid] and not session_quests[questid] and not SPAM_QUESTS[questid] then
            if not mapdata then
                local mapID = C_Map.GetBestMapForUnit('player')
                if mapID then
                    mapdata = C_Map.GetMapInfo(mapID)
                    local position = C_Map.GetPlayerMapPosition(mapdata.mapID, 'player')
                    if position then
                        x, y = position:GetXY()
                    end
                end
            end
            local questName = self.quest_names[questid] -- prime it
            local quest = {
                id = questid,
                time = time(),
                map = mapdata and mapdata.mapID or 0,
                x = x or 0,
                y = y or 0,
            }
            table.insert(self.quests_completed, quest)
            table.insert(self.dbpc.log, quest)
            session_quests[questid] = true

            if db.announce then
                self.Print("Quest complete:", questid, questName or UNKNOWN)
            end

            self:TriggerEvent(self.Event.OnQuestAdded, quest, #self.dbpc.log)
        end
        quests[questid] = true
    end
end

function ns:RemoveQuest(index)
    if index == 0 then
        table.wipe(self.quests_completed)
        table.wipe(self.dbpc.log)
        self:TriggerEvent(self.Event.OnAllQuestsRemoved)
    else
        local quest
        if type(index) == "table" then
            quest = index
            index = tIndexOf(self.dbpc.log, quest)
            if not index then return end
        else
            quest = self.dbpc.log[index]
        end

        for i, q in ipairs(self.quests_completed) do
            if q.id == quest.id then
                tremove(self.quests_completed, i)
                break
            end
        end
        tremove(self.dbpc.log, index)
        self:TriggerEvent(self.Event.OnQuestRemoved, quest, index)
    end
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobject = ldb:GetDataObjectByName("QuestsChanged") or ldb:NewDataObject("QuestsChanged", {
    type = "data source",
    label = "QuestsChanged",
    icon = [[Interface\Minimap\Tracking\QuestBlob]],
})

dataobject.OnClick = function(frame, button)
    if button == "RightButton" then
        if IsShiftKeyDown() then
            -- *really* clear the whole log
            ns:RemoveQuest(0)
        else
            -- clear the current session
            table.wipe(ns.quests_completed)
        end
    else
        if IsShiftKeyDown() then
            local data = ns.dbpc.log[#ns.dbpc.log]
            StaticPopup_Show("QUESTSCHANGED_COPYBOX", nil, nil, ("[%d] = {quest=%d, label=\"\"},"):format(
                ns.GetCoord(data.x, data.y),
                (data.id or "nil")
            ))
        else
            ns:ToggleLog()
        end
    end
end

dataobject.OnTooltipShow = function(tooltip)
    ns:CheckQuests() -- in case
    tooltip:AddLine("QuestsChanged")
    for _, quest in ipairs(ns.quests_completed) do
        local map, level
        if type(quest.map) == 'string' then
            -- pre-8.0 quest logging has mapFiles, just show them
            map = quest.map
            level = quest.level
        else
            map, level = ns.MapNameFromID(quest.map)
        end
        tooltip:AddDoubleLine(
            ("%d: %s"):format(quest.id, ns.quest_names[quest.id] or UNKNOWN),
            ("%s (%s) %.2f, %.2f"):format(quest.map, map .. (level and (' / ' .. level) or ''), quest.x * 100, quest.y * 100)
        )
    end

    local x, y
    local mapID = C_Map.GetBestMapForUnit('player')
    if mapID then
        local position = C_Map.GetPlayerMapPosition(mapID, 'player')
        if position then
            x, y = position:GetXY()
        end
    end
    local mapname, subname = ns.MapNameFromID(mapID)

    tooltip:AddDoubleLine("Location", ("%s (%s) %.2f, %.2f"):format(mapID or UNKNOWN, mapname .. (subname and (' / ' .. subname) or ''), (x or 0) * 100, (y or 0) * 100), 1, 0, 1, 1, 0, 1)
    tooltip:AddLine("Left-click to show your quest history", 0, 1, 1)
    tooltip:AddLine("Shift-left-click to copy the last quest", 0, 1, 1)
    tooltip:AddLine("Right-click to clear the current session", 0, 1, 1)
    tooltip:AddLine("Shift-right-click to clear the entire history", 1, 0, 0)
end

ns.dataobject = dataobject

-- slash

_G["SLASH_".. myname:upper().."1"] = "/questschanged"
SlashCmdList[myname:upper()] = function(msg)
    msg = msg:trim()
    if msg == "log" or msg == "" then
        ns:ToggleLog()
    elseif msg == "icon" then
        if not icon then return end
        db.hide = not db.hide
        if db.hide then
            icon:Hide(myname)
        else
            icon:Show(myname)
        end
        ns.Print("icon", db.hide and "hidden" or "shown")
    elseif msg == "announce" then
        db.announce = not db.announce
        ns.Print("announce in chat", db.announce and "enabled" or "disabled")
    end
end

-- utility

function ns.Print(...) print("|cFF33FF99".. myfullname.. "|r:", ...) end

function ns.MapNameFromID(mapID)
    if not mapID then
        return UNKNOWN
    end
    local mapdata = C_Map.GetMapInfo(mapID)
    if not mapdata then
        return UNKNOWN
    end
    local groupID = C_Map.GetMapGroupID(mapID)
    if groupID then
        local groupdata = C_Map.GetMapGroupMembersInfo(groupID)
        for _, subzonedata in ipairs(groupdata) do
            if subzonedata.mapID == mapID then
                return mapdata.name, subzonedata.name
            end
        end
    end
    return mapdata.name
end

function ns.GetCoord(x, y)
    return floor(x * 10000 + 0.5) * 10000 + floor(y * 10000 + 0.5)
end

StaticPopupDialogs["QUESTSCHANGED_COPYBOX"] = {
    text = "Copy me",
    hasEditBox = true,
    hideOnEscape = true,
    whileDead = true,
    closeButton = true,
    editBoxWidth = 350,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    button1 = "Done",
    OnButton1 = function(self, data)
        return false
    end,
    OnShow = function(self, data)
        if data then
            self.editBox:SetText(data)
            self.editBox:HighlightText()
        end
    end,
}
