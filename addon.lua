local myname, ns = ...

local icon = LibStub("LibDBIcon-1.0", true)

local db
local quests
local quests_completed = {}

local f = CreateFrame('Frame')
f:SetScript("OnEvent", function(self, event, ...)
    ns[event](ns, event, ...)
end)
f:RegisterEvent("ADDON_LOADED")
f:Hide()

function ns:ADDON_LOADED(event, name)
    if name ~= myname then return end

    _G[myname.."DB"] = setmetatable(_G[myname.."DB"] or {}, {
        __index = {
            minimap = false,
        },
    })
    db = _G[myname.."DB"]

    if icon then
        icon:Register(myname, ns.dataobject, db)
    end

    f:UnregisterEvent("ADDON_LOADED")

    if IsLoggedIn() then self:PLAYER_LOGIN() else f:RegisterEvent("PLAYER_LOGIN") end
end
function ns:PLAYER_LOGIN()
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
    f:UnregisterEvent("PLAYER_LOGIN")

    quests = GetQuestsCompleted()
end
function ns:QUEST_LOG_UPDATE()
    f:Show()
end
function ns.ENCOUNTER_LOOT_RECEIVED = ns.QUEST_LOG_UPDATE

do
    local time_since = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        time_since = time_since + elapsed
        if time_since < 0.3 then
            return
        end
        ns:CheckQuests()
        f:Hide()
    end)
end

local quest_names = {}
do
    local tooltip
    local function tooltip_line(link, line)
        if not tooltip then
            tooltip = CreateFrame("GameTooltip", myname.."_Tooltip", nil, "GameTooltipTemplate")
            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end
        tooltip:ClearLines()
        tooltip:SetHyperlink(link)
        
        if tooltip:NumLines() < line then return false end
        return _G[myname.."_TooltipTextLeft"..line]:GetText()
    end
    quest_names = setmetatable({}, {__index = function(self, key)
        local link = (type(key) == 'string') and key or ('quest:'..key)
        local uid = string.match(link, '%d+')
        local name = tooltip_line(link, 1)
        if name then
            self[uid] = name
            return name
        end
        return false
    end,})
end

function ns:CheckQuests()
    if not quests then
        return
    end
    local new_quests = GetQuestsCompleted()
    for questid in pairs(new_quests) do
        if not quests[questid] then
            local mapFile, _, _, isMicroDungeon, microDungeon = GetMapInfo()
            local x, y = GetPlayerMapPosition("player")
            local questName = quest_names[questid] -- prime it
            table.insert(quests_completed, {
                id = questid,
                time = time(),
                map = microDungeon or mapFile,
                x = x,
                y = y,
                level = GetCurrentMapDungeonLevel(),
            })
        end
    end
    quests = new_quests
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobject = ldb:GetDataObjectByName("QuestsChanged") or ldb:NewDataObject("QuestsChanged", {
    type = "data source",
    label = "QuestsChanged",
    icon = [[Interface\Icons\Ability_Spy]],
})

dataobject.OnClick = function(frame, button)
    if button == "RightButton" then
        -- clear the list!
        quests_completed = {}
    end
end

dataobject.OnTooltipShow = function(tooltip)
    ns:CheckQuests() -- in case
    tooltip:AddLine("QuestsChanged")
    for _, quest in ipairs(quests_completed) do
        tooltip:AddDoubleLine(
            ("%d: %s"):format(quest.id, quest_names[quest.id] or UNKNOWN),
            ("%s (%d) %.2f, %.2f"):format(quest.map, quest.level, quest.x * 100, quest.y * 100)
        )
    end

    local mapFile, _, _, isMicroDungeon, microDungeon = GetMapInfo()
    local x, y = GetPlayerMapPosition("player")
    tooltip:AddDoubleLine("Location", ("%s (%d) %.2f, %.2f"):format(microDungeon or mapFile, GetCurrentMapDungeonLevel(), x * 100, y * 100), 1, 0, 1, 1, 0, 1)
    tooltip:AddLine("Right-click to clear the list", 0, 1, 1)
end

ns.dataobject = dataobject

-- slash

_G["SLASH_".. myname:upper().."1"] = "/questschanged"
SlashCmdList[myname:upper()] = function(msg)
    if not icon then return end
    db.hide = not db.hide
    if db.hide then
        icon:Hide(myname)
    else
        icon:Show(myname)
    end
end
