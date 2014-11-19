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
local cache_tooltip = CreateFrame("GameTooltip", "QuestsChangedCacheTooltip")
cache_tooltip:AddFontStrings(
    cache_tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"),
    cache_tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText")
)
local function quest_name(id)
    if not quest_names[id] then
        -- this doesn't work with just clearlines and the setowner outside of this, and I'm not sure why
        cache_tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        cache_tooltip:SetHyperlink(("quest:%d"):format(id))
        if cache_tooltip:IsShown() then
            quest_names[id] = QuestsChangedCacheTooltipTextLeft1:GetText()
        end
    end
    return quest_names[id]
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
    local new_quests = GetQuestsCompleted()
    for questid in pairs(new_quests) do
        if not quests[questid] then
            quest_name(questid) -- prep the cache for it
            table.insert(quests_completed, questid)
        end
    end
    quests = new_quests

    tooltip:AddLine("QuestsChanged")
    for _, questid in ipairs(quests_completed) do
        tooltip:AddDoubleLine(quest_name(questid) or UNKNOWN, questid)
    end

    tooltip:AddLine("Right-click to clear the list", 0, 1, 1)
end

-- local icon = LibStub("LibDBIcon-1.0", true)
-- if icon then
--     icon:Register("QuestsChanged", dataobject, self.db.profile.minimap)
-- end