local myname, ns = ...

local floor = math.floor
local PAGESIZE, lastSize = 13, 0
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
        local index = #ns.dbpc.log - log.offset - (self.index - 1)
        local quest = ns.dbpc.log[index]
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
        GameTooltip:Show()
        end
    end

    local function Line_OnClick(self,button,down)
        local index = #ns.dbpc.log - log.offset - (self.index - 1)
        local quest = ns.dbpc.log[index]
        if button == "RightButton" then
            ns:RemoveQuest(index)
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
                end
            end
        end
    end

    log.lines = {}
    for i = 1, PAGESIZE do
        local height = 32
        local line = CreateFrame("Button", nil, log)
        line:SetHeight(height)
        line:SetPoint("TOPLEFT", 12, -((height * i)))
        line:SetPoint("RIGHT", -12, 0)
        line:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        line:GetHighlightTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)
        line:GetHighlightTexture():SetAlpha(0.5)

        line.title = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
        line.title:SetPoint("TOPLEFT")
        line.title:SetPoint("TOPRIGHT", line, "TOPLEFT", 260, 0)
        line.title:SetPoint("BOTTOM", 0, 16)
        line.time = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
        line.time:SetPoint("TOPRIGHT")
        line.time:SetPoint("TOPLEFT", line, "TOPRIGHT", -100, 0)
        line.time:SetPoint("BOTTOM", 0, 16)
        line.location = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
        line.location:SetPoint("TOPRIGHT", line.time, "TOPLEFT")
        line.location:SetPoint("TOPLEFT", line.title, "TOPRIGHT")
        line.location:SetPoint("BOTTOM", 0, 16)
        line.coords = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightRight")
        line.coords:SetPoint("TOPLEFT", line.location, "BOTTOMLEFT")
        line.coords:SetPoint("TOPRIGHT", line.location, "BOTTOMRIGHT")
        line.coords:SetPoint("BOTTOM")

        line:SetScript("OnEnter", Line_OnEnter)
        line:SetScript("OnLeave", GameTooltip_Hide)
        line:SetScript("OnClick", Line_OnClick)
        line:RegisterForClicks("LeftButtonUp","RightButtonUp")

        line.index = i

        log.lines[i] = line
    end

    local nextpage = ns.CreatePageButton(log, "Next")
    nextpage:SetPoint("BOTTOMRIGHT", -40, 6)
    nextpage:SetScript("OnClick", function(self)
        log.offset = log.offset + PAGESIZE
        ns:RefreshLog()
    end)
    log.nextpage = nextpage
    local prevpage = ns.CreatePageButton(log, "Prev")
    prevpage:SetPoint("BOTTOMLEFT", 40, 6)
    prevpage:SetScript("OnClick", function(self)
        log.offset = math.max(0, log.offset - PAGESIZE)
        ns:RefreshLog()
    end)
    log.prevpage = prevpage

    log.page = log:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    log.page:SetPoint("BOTTOM", 0, 16)

    log.offset = 0
end

function ns:RefreshLog()
    if not self:LogShown() then return end
    local size = #ns.dbpc.log
    local dirtySize = math.max(size,lastSize)

    if log.offset == 0 then
        log.prevpage:Disable()
    else
        log.prevpage:Enable()
    end
    if (log.offset + PAGESIZE) >= size then
        log.nextpage:Disable()
    else
        log.nextpage:Enable()
    end

    for i = 1, math.min(dirtySize,PAGESIZE) do
        -- Reverse-order, so offset=0 should get us the final row in log
        local index = size - log.offset - (i - 1)
        local quest = ns.dbpc.log[index]
        if quest then
            local map, level
            if type(quest.map) == 'string' then
                -- pre-8.0 quest logging has mapFiles, just show them
                map = quest.map
                level = quest.level
            else
                map, level = ns.MapNameFromID(quest.map)
            end
            log.lines[i].title:SetFormattedText("%d: %s", quest.id, ns.quest_names[quest.id] or UNKNOWN)
            log.lines[i].location:SetFormattedText("%s (%s)", quest.map, map .. (level and (' / ' .. level) or ''))
            log.lines[i].coords:SetFormattedText("%.2f, %.2f", quest.x * 100, quest.y * 100)
            log.lines[i].time:SetText(ns.FormatLastSeen(quest.time))
            log.lines[i]:Show()
        else
            log.lines[i]:Hide()
        end
    end

    log.page:SetFormattedText(MERCHANT_PAGE_NUMBER, math.ceil(log.offset / PAGESIZE) + 1, math.ceil(#ns.dbpc.log / PAGESIZE))
    lastSize = size
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
        self:RefreshLog()
    end
end

local function ClickSound(self)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function ns.CreatePageButton(parent, type)
    assert(type == "Next" or type == "Prev", "`type` must be 'Next' or 'Prev'")

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)

    button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. type .. "Page-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. type .. "Page-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. type .. "Page-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    button:HookScript("OnClick", ClickSound)

    return button
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
