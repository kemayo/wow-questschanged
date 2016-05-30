local myname, ns = ...

local quests
local quests_completed = {}

local f = CreateFrame('Frame')
f:SetScript("OnEvent", function(self, event, ...)
    quests = GetQuestsCompleted()
    f:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
f:RegisterEvent("PLAYER_ENTERING_WORLD")

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
qcqn = quest_names

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
    local new_quests = GetQuestsCompleted()
    for questid in pairs(new_quests) do
        if not quests[questid] then
            table.insert(quests_completed, questid)
        end
    end
    quests = new_quests

    tooltip:AddLine("QuestsChanged")
    for _, questid in ipairs(quests_completed) do
        tooltip:AddDoubleLine(quest_names[questid] or UNKNOWN, questid)
    end

    local x, y = GetPlayerMapPosition("player")
    tooltip:AddDoubleLine("Location", ("%.2f, %.2f"):format(x * 100, y * 100), 1, 0, 1, 1, 0, 1)
    tooltip:AddLine("Right-click to clear the list", 0, 1, 1)
end

-- local icon = LibStub("LibDBIcon-1.0", true)
-- if icon then
--     icon:Register("QuestsChanged", dataobject, self.db.profile.minimap)
-- end