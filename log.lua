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

    log.Quests = self:BuildQuestLog()
    log.Quests:Show()
    log.Vignettes = self:BuildVignetteLog()
    log.Vignettes:Hide()

    local QuestButton = CreateFrame("EventButton", nil, log, "UIPanelButtonTemplate")
    QuestButton:SetText("Quests")
    QuestButton:SetSize(120, 22)
    QuestButton:SetPoint("TOP", log, "BOTTOM", -71, 8)
    QuestButton:SetScript("OnClick", function()
        log.Vignettes:Hide()
        log.Quests:Show()
    end)
    local VignetteButton = CreateFrame("EventButton", nil, log, "UIPanelButtonTemplate")
    VignetteButton:SetText("Vignettes")
    VignetteButton:SetSize(120, 22)
    VignetteButton:SetPoint("LEFT", QuestButton, "RIGHT", 22, 0)
    VignetteButton:SetScript("OnClick", function()
        log.Quests:Hide()
        log.Vignettes:Show()
    end)
end

function ns:BuildLogPanel(initializer, dataProvider)
    local Container = CreateFrame("Frame", nil, log)
    Container:SetPoint("TOPLEFT", 12, -32)
    Container:SetPoint("BOTTOMRIGHT", -3, 4)

    local ScrollBar = CreateFrame("EventFrame", nil, Container, "WowTrimScrollBar")
    ScrollBar:SetPoint("TOPRIGHT", 0, 5)
    ScrollBar:SetPoint("BOTTOMRIGHT")
    Container.ScrollBar = ScrollBar

    local ScrollBox = CreateFrame("Frame", nil, Container, "WowScrollBoxList")
    ScrollBox:SetPoint("TOPLEFT")
    ScrollBox:SetPoint("BOTTOMRIGHT", ScrollBar, "BOTTOMLEFT")
    Container.ScrollBox = ScrollBox

    local ScrollView = CreateScrollBoxListLinearView()
    ScrollView:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
    ScrollView:SetElementExtent(32)  -- Fixed height for each row; required as we're not using XML.
    ScrollView:SetElementInitializer("Button", initializer)
    Container.ScrollView = ScrollView

    ScrollUtil.InitScrollBoxWithScrollBar(ScrollBox, ScrollBar, ScrollView)

    -- This causes errors when removing lines:
    -- Container:SetScript("OnShow", function()
    --     -- for the timestamps
    --     ScrollView:Rebuild()
    -- end)

    return Container
end

function ns:BuildQuestLog()
    local function Line_OnEnter(self)
        local quest = self.data
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
        local quest = self.data
        if button == "RightButton" then
            ns:RemoveQuest(quest)
        elseif IsShiftKeyDown() then
            StaticPopup_Show("QUESTSCHANGED_COPYBOX", nil, nil, ("[%d] = {quest=%d},"):format(
                ns.GetCoord(quest.x, quest.y),
                quest.id or "nil"
            ))
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

    local initializer = function(line, index)
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
            line:SetScript("OnShow", function(self) if self.data then self.Time:SetText(ns.FormatLastSeen(self.data.time)) end end)
            line:RegisterForClicks("LeftButtonUp","RightButtonUp")
        end

        -- It's an append table, but I want this to be newest-first
        -- (And the indexrange dataprovider doesn't have a sort comparator)
        local quest = self.dbpc.log[#self.dbpc.log - (index - 1)]
        line.data = quest

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
    end

    -- This is a vast table (my main has 18,586 entries in it), so use the IndexRange provider
    local dataProvider = CreateIndexRangeDataProvider(#self.dbpc.log)

    self:RegisterCallback(self.Event.OnQuestAdded, function(_, quest, index)
        dataProvider:SetSize(#self.dbpc.log)
    end)
    self:RegisterCallback(self.Event.OnQuestRemoved, function(_, quest, index)
        dataProvider:SetSize(#self.dbpc.log)
    end)
    self:RegisterCallback(self.Event.OnAllQuestsRemoved, function()
        dataProvider:Flush()
    end)

    return ns:BuildLogPanel(initializer, dataProvider)
end

function ns:BuildVignetteLog()
    local function Line_OnEnter(self)
        local vignette = self.data
        if vignette then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(vignette.name or UNKNOWN)
            GameTooltip:AddDoubleLine("id", vignette.id)
            GameTooltip:AddDoubleLine("map", vignette.uiMapID)
            GameTooltip:AddDoubleLine("atlas", vignette.atlas)
            GameTooltip:AddDoubleLine("coords", ("%.2f, %.2f"):format(vignette.x * 100, vignette.y * 100))
            GameTooltip:AddDoubleLine("time", vignette.time)
            GameTooltip:AddLine("Left-click for waypoint", 0, 1, 1)
            GameTooltip:AddLine("Shift-click to copy", 0, 1, 1)
            GameTooltip:AddLine("Right-click to remove", 0, 1, 1)
            GameTooltip:Show()
        end
    end

    local function Line_OnClick(self, button, down)
        local vignette = self.data
        if button == "RightButton" then
            ns:RemoveVignette(vignette)
        elseif IsShiftKeyDown() then
            StaticPopup_Show("QUESTSCHANGED_COPYBOX", nil, nil, ("[%d] = {vignette=%d, label=\"%s\"},"):format(
                ns.GetCoord(vignette.x, vignette.y),
                vignette.id or "nil",
                vignette.name or UNKNOWN
            ))
        else
            if vignette and vignette.uiMapID and vignette.x and vignette.y then
                local m = tonumber(vignette.uiMapID)
                if C_Map.CanSetUserWaypointOnMap(m) then
                    if C_Map.HasUserWaypoint() then
                        C_Map.ClearUserWaypoint()
                    end
                    local p = UiMapPoint.CreateFromCoordinates(m, vignette.x, vignette.y)
                    C_Map.SetUserWaypoint(p)
                    OpenWorldMap(m)
                else
                    ns.Print('Can\'t set waypoint for', m, vignette.x, vignette.y)
                end
            end
        end
    end

    local initializer = function(line, vignetteGUID)
        if not line.Title then
            line:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            line:GetHighlightTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)
            line:GetHighlightTexture():SetAlpha(0.5)

            line.Texture = line:CreateTexture(nil, "ARTWORK")
            line.Texture:SetPoint("TOPLEFT")
            line.Texture:SetPoint("BOTTOMLEFT")
            line.Texture:SetWidth(line:GetHeight())
            line.Title = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
            line.Title:SetPoint("TOPLEFT", line.Texture, "TOPRIGHT")
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
            line:SetScript("OnShow", function(self) if self.data then self.Time:SetText(ns.FormatLastSeen(self.data.time)) end end)
            line:RegisterForClicks("LeftButtonUp","RightButtonUp")
        end

        local vignette = self.vignetteLog[vignetteGUID]
        line.data = vignette

        local map, level = self.MapNameFromID(vignette.uiMapID)
        line.Texture:SetAtlas(vignette.atlas)
        line.Title:SetFormattedText("%d: %s", vignette.id, vignette.name or UNKNOWN)
        line.Location:SetFormattedText("%s (%s)", vignette.uiMapID or "?", map .. (level and (' / ' .. level) or ''))
        line.Coords:SetFormattedText("%.2f, %.2f", vignette.x * 100, vignette.y * 100)
        line.Time:SetText(self.FormatLastSeen(vignette.time))
    end

    -- This is a tiny table that's its own source-of-truth, so regular dataprovider is fine
    local dataProvider = CreateDataProvider(self.vignetteLogOrder)
    -- It's stored in an append-table, but I want the new events at the top:
    dataProvider:SetSortComparator(function(lhs, rhs)
        return self.vignetteLog[lhs].time > self.vignetteLog[rhs].time
    end)

    self:RegisterCallback(self.Event.OnVignetteAdded, function(_, vignette, guid)
        dataProvider:Insert(guid)
    end)
    self:RegisterCallback(self.Event.OnVignetteRemoved, function(_, vignette, guid)
        dataProvider:Remove(guid)
    end)
    self:RegisterCallback(self.Event.OnAllVignettesRemoved, function()
        dataProvider:Flush()
    end)

    return ns:BuildLogPanel(initializer, dataProvider)
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
