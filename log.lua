local myname, ns = ...

local floor = math.floor
local log, copybox
function ns:BuildLog()
    log = CreateFrame("Frame", "QuestsChangedFrame", UIParent, "UIPanelDialogTemplate")
    log:EnableMouse(true)
    log:SetMovable(true)
    log:SetClampedToScreen(true)
    log:SetFrameStrata("DIALOG")
    log:SetSize(600, 500)
    log:SetPoint("TOP", 0, -80)
    log:Hide()

    log.Title:SetText("QuestsChanged")

    local drag = CreateFrame("Frame", "$parentTitleButton", log, "TitleDragAreaTemplate")
    drag:SetPoint("TOPLEFT", _G["QuestsChangedFrameTitleBG"])
    drag:SetPoint("BOTTOMRIGHT", _G["QuestsChangedFrameTitleBG"])

    local function Line_OnEnter(self)
        local quest = self.quest
        if quest then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(ns.quest_names[quest.id] or UNKNOWN)
            GameTooltip:AddDoubleLine("id", quest.id)
            GameTooltip:AddDoubleLine("map", quest.map)
            if quest.level then
                -- pre-8.0
                GameTooltip:AddDoubleLine("level", quest.level)
            end
            GameTooltip:AddDoubleLine("coords", ("%.2f, %.2f"):format(quest.x * 100, quest.y * 100))
            GameTooltip:AddDoubleLine("time", quest.time)
            GameTooltip:AddLine("Left-click for waypoint", 0, 1, 1)
            GameTooltip:AddLine("Shift-click to copy", 0, 1, 1)
            GameTooltip:AddLine("Right-click to remove", 0, 1, 1)
            GameTooltip:Show()
        end
    end

    local function Line_OnClick(self, button, down)
        local quest = self.quest
        if button == "RightButton" then
            print("Requesting quest removal", quest)
            ns:RemoveQuest(quest)
        elseif IsShiftKeyDown() then
            StaticPopup_Show("QUESTSCHANGED_COPYBOX", nil, nil, quest)
        else
            if quest and quest.map and quest.x and quest.y then
                local m = tonumber(quest.map)
                if C_Map.CanSetUserWaypointOnMap(m) then
                    if C_Map.HasUserWaypoint() then
                        C_Map.ClearUserWaypoint()
                    end
                    local p = UiMapPoint.CreateFromCoordinates(m,quest.x,quest.y)
                    C_Map.SetUserWaypoint(p)
                    OpenWorldMap(m)
                else
                    ns.Print('Can\'t set waypoint for', m, quest.x, quest.y)
                end
            end
        end
    end

    local ScrollBar = CreateFrame("EventFrame", nil, log, "WowTrimScrollBar")
    ScrollBar:SetPoint("TOPRIGHT", -3, -28)
    ScrollBar:SetPoint("BOTTOMRIGHT", -12, 4)

    local ScrollBox = CreateFrame("Frame", nil, log, "WowScrollBoxList")
    ScrollBox:SetPoint("TOPLEFT", 12, -32)
    ScrollBox:SetPoint("BOTTOMRIGHT", ScrollBar, "BOTTOMLEFT")

    local ScrollView = CreateScrollBoxListLinearView()
    ScrollView:SetElementExtent(32)  -- Fixed height for each row; required as we're not using XML.
    ScrollView:SetElementInitializer("Button", function(line, quest, isNew)
        if not line.Title then
            line:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            line:GetHighlightTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)
            line:GetHighlightTexture():SetAlpha(0.5)

            line.Title = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
            line.Title:SetPoint("TOPLEFT")
            line.Title:SetPoint("TOPRIGHT", line, "TOPLEFT", 260, 0)
            line.Title:SetPoint("BOTTOM", 0, 16)
            line.Time = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
            line.Time:SetPoint("TOPRIGHT")
            line.Time:SetPoint("TOPLEFT", line, "TOPRIGHT", -100, 0)
            line.Time:SetPoint("BOTTOM", 0, 16)
            line.Location = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
            line.Location:SetPoint("TOPRIGHT", line.Time, "TOPLEFT")
            line.Location:SetPoint("TOPLEFT", line.Title, "TOPRIGHT")
            line.Location:SetPoint("BOTTOM", 0, 16)
            line.Coords = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
            line.Coords:SetPoint("TOPLEFT", line.Location, "BOTTOMLEFT")
            line.Coords:SetPoint("TOPRIGHT", line.Location, "BOTTOMRIGHT")
            line.Coords:SetPoint("BOTTOM")

            line:SetScript("OnEnter", Line_OnEnter)
            line:SetScript("OnLeave", GameTooltip_Hide)
            line:SetScript("OnClick", Line_OnClick)
            line:RegisterForClicks("LeftButtonUp","RightButtonUp")
        end

        line.quest = quest

        local map, level
        if type(quest.map) == 'string' then
            -- pre-8.0 quest logging has mapFiles, just show them
            map = quest.map
            level = quest.level
        else
            map, level = self.MapNameFromID(quest.map)
        end
        line.Title:SetFormattedText("%d: %s", quest.id, self.quest_names[quest.id] or UNKNOWN)
        line.Location:SetFormattedText("%s (%s)", quest.map, map .. (level and (' / ' .. level) or ''))
        line.Coords:SetFormattedText("%.2f, %.2f", quest.x * 100, quest.y * 100)
        line.Time:SetText(self.FormatLastSeen(quest.time))
    end)

    ScrollUtil.InitScrollBoxWithScrollBar(ScrollBox, ScrollBar, ScrollView)

    log.DataProvider = CreateDataProvider(self.dbpc.log)
    -- It's stored in an append-table, but I want the new events at the top:
    log.DataProvider:SetSortComparator(function(lhs, rhs)
        return lhs.time > rhs.time
    end)

    ScrollBox:SetDataProvider(log.DataProvider)

    self:RegisterCallback(self.Event.OnQuestAdded, function(_, quest, index)
        log.DataProvider:Insert(quest)
    end)
    self:RegisterCallback(self.Event.OnQuestRemoved, function(_, quest, index)
        log.DataProvider:Remove(quest)
    end)
    self:RegisterCallback(self.Event.OnAllQuestsRemoved, function()
        log.DataProvider:Flush()
    end)

    log:SetScript("OnShow", function()
        -- for the timestamps
        ScrollView:Rebuild()
    end)
end

function ns:LogShown()
    return log and log:IsShown()
end

function ns:ToggleLog()
    if not log then self:BuildLog() end
    if log:IsShown() then
        log:Hide()
    else
        log:Show()
    end
end

local function ClickSound(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function ns.FormatLastSeen(t)
    t = tonumber(t)
    if not t or t == 0 then return NEVER end
    local currentTime = time()
    local minutes = floor(((currentTime - t) / 60) + 0.5)
    if minutes > 119 then
        local hours = floor(((currentTime - t) / 3600) + 0.5)
        if hours > 23 then
            return floor(((currentTime - t) / 86400) + 0.5).." day(s)"
        else
            return hours.." hour(s)"
        end
    else
        return minutes.." minute(s)"
    end
end
