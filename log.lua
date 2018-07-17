local myname, ns = ...

local PAGESIZE = 20
local log
function ns:ShowLog()
    if not log then
        log = CreateFrame("GameTooltip", "QuestsChangedLogTooltip", UIParent, "GameTooltipTemplate")

        log:RegisterForDrag("LeftButton")
        log:EnableMouse(true)
        log:SetMovable(true)
        log:SetClampedToScreen(true)
        log:SetFrameStrata("DIALOG")
        log:Hide()

        log:SetPoint("TOP", 0, -80)

        log:SetScript("OnDragStart", function(self) self:StartMoving() end)
        log:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            ValidateFramePosition(self)
        end)

        log:SetPadding(0, 24) -- width, height
        local close = ns.CreateCloseButton(log)
        close:SetPoint("TOPRIGHT", 1, 1)
        close:SetScript("OnClick", function(self)
            HideUIPanel(log)
        end)
        local nextpage = ns.CreatePageButton(log, "Next")
        nextpage:SetPoint("BOTTOMRIGHT", -40, 2)
        nextpage:SetScript("OnClick", function(self)
            log.offset = log.offset + PAGESIZE
            ns:RefreshLog()
        end)
        log.nextpage = nextpage
        local prevpage = ns.CreatePageButton(log, "Prev")
        prevpage:SetPoint("BOTTOMLEFT", 40, 2)
        prevpage:SetScript("OnClick", function(self)
            log.offset = math.max(1, log.offset - PAGESIZE)
            ns:RefreshLog()
        end)
        log.prevpage = prevpage

        log.page = log:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        log.page:SetPoint("BOTTOM", 0, 12)

        log.offset = 1 + PAGESIZE * math.floor(#ns.dbpc.log / PAGESIZE)
    end

    ShowUIPanel(log)
    if not log:IsShown() then
        log:SetOwner(UIParent, "ANCHOR_PRESERVE")
    end

    self:RefreshLog()
end

function ns:RefreshLog()
    log:ClearLines()

    if log.offset == 1 then
        log.prevpage:Disable()
    else
        log.prevpage:Enable()
    end
    if (log.offset + PAGESIZE + 1) > #ns.dbpc.log then
        log.nextpage:Disable()
    else
        log.nextpage:Enable()
    end

    log:AddLine("QuestsChanged")

    for i = log.offset, math.min(#ns.dbpc.log, log.offset + PAGESIZE - 1) do
        local quest = ns.dbpc.log[i]
        if quest then
            local map, level
            if type(quest.map) == 'string' then
                -- pre-8.0 quest logging has mapFiles, just show them
                map = quest.map
                level = quest.level
            else
                map, level = ns.MapNameFromID(quest.map)
            end
            log:AddDoubleLine(
                ("%d: %s"):format(quest.id, ns.quest_names[quest.id] or UNKNOWN),
                ("%s (%s) %.2f, %.2f"):format(quest.map, map .. (level and (' / ' .. level) or ''), quest.x * 100, quest.y * 100)
            )
        end
    end

    log.page:SetFormattedText(MERCHANT_PAGE_NUMBER, math.ceil(log.offset / PAGESIZE), math.ceil(#ns.dbpc.log / PAGESIZE))

    log:Show()
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

function ns.CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent)
    close:SetSize(32, 32)

    close:SetNormalTexture([[Interface\Buttons\UI-Panel-MinimizeButton-Up]])
    close:SetPushedTexture([[Interface\Buttons\UI-Panel-MinimizeButton-Down]])
    close:SetHighlightTexture([[Interface\Buttons\UI-Panel-MinimizeButton-Highlight]], "ADD")

    close:HookScript("OnClick", ClickSound)

    return close
end
