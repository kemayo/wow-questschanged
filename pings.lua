local myname, ns = ...
local myfullname = C_AddOns.GetAddOnMetadata(myname, "Title")

local MinimapPosition

local log = {}
ns.pingLog = log

function ns:MINIMAP_PING(_, unit, x, y)
    local uiMapID, mx, my = MinimapPosition(x, y)
    if not (uiMapID and mx and my) then
        return
    end
    ns:AddPing(uiMapID, mx, my, unit)
end

function ns:OnMinimapMouseDown(...)
    local scale, cx, cy = UIParent:GetEffectiveScale(), GetCursorPosition()
    local mWidth, mHeight = Minimap:GetSize()
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    local ix, iy = (cx / scale) - left, (cy / scale) - bottom
    local uiMapID, mx, my = MinimapPosition((ix / mWidth) - 0.5, (iy / mHeight) - 0.5)
    self:AddPing(uiMapID, mx, my, "player")
end

function ns:AddPing(uiMapID, x, y, unit)
    table.insert(log, {
        time = time(),
        uiMapID = uiMapID,
        x = x,
        y = y,
        from = unit,
    })

    self:TriggerEvent(self.Event.OnPingAdded, log[#log], #log)
end

function ns:RemovePing(ping)
    local index = tIndexOf(log, ping)
    if index then
        table.remove(log, index)
        self:TriggerEvent(self.Event.OnPingRemoved, ping, index)
    end
end

do
    -- The classic fallbacks here are from HereBeDragons:
    local GetViewRadius, GetZoneSize
    if C_Minimap and C_Minimap.GetViewRadius then
        GetViewRadius = function() return C_Minimap.GetViewRadius() end
    else
        -- classic / mists
        local f = CreateFrame("FRAME")
        local indoors
        f:SetScript("OnEvent", function(self, event, ...)
            local zoom = Minimap:GetZoom()
            if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
                Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
            end
            indoors = GetCVar("minimapZoom")+0 == Minimap:GetZoom() and "outdoor" or "indoor"
            Minimap:SetZoom(zoom)
        end)
        f:RegisterEvent("MINIMAP_UPDATE_ZOOM")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")

        local minimap_size = {
            indoor = {
                [0] = 300, -- scale
                [1] = 240, -- 1.25
                [2] = 180, -- 5/3
                [3] = 120, -- 2.5
                [4] = 80,  -- 3.75
                [5] = 50,  -- 6
            },
            outdoor = {
                [0] = 466 + 2/3, -- scale
                [1] = 400,       -- 7/6
                [2] = 333 + 1/3, -- 1.4
                [3] = 266 + 2/6, -- 1.75
                [4] = 200,       -- 7/3
                [5] = 133 + 1/3, -- 3.5
            },
        }
        GetViewRadius = function()
            local zoom = Minimap:GetZoom()
            return minimap_size[indoors][zoom] / 2
        end
    end
    if C_Map and C_Map.GetMapWorldSize then
        GetZoneSize = function(uiMapID) return C_Map.GetMapWorldSize(uiMapID) end
    else
        -- classic and mists again
        local vector00, vector05 = CreateVector2D(0, 0), CreateVector2D(0.5, 0.5)
        GetZoneSize = function(uiMapID)
            local instance, center = C_Map.GetWorldPosFromMapPos(uiMapID, vector05)
            local width, height

            local _, topleft = C_Map.GetWorldPosFromMapPos(uiMapID, vector00)
            if center and topleft then
                local top, left = topleft:GetXY()
                local bottom, right = center:GetXY()
                width = (left - right) * 2
                height = (top - bottom) * 2
            end

            return width, height
        end
    end

    function MinimapPosition(x, y)
        -- x and y are offsets from the center of the minimap at its current
        -- zoom level, between -0.5 and 0.5. They're this because that's what
        -- the arguments to MINIMAP_PING are.
        local mapRadius = GetViewRadius()
        local uiMapID = C_Map.GetBestMapForUnit('player')
        if not uiMapID then return end
        local position = C_Map.GetPlayerMapPosition(uiMapID, 'player')
        if not position then return end
        local px, py = position:GetXY()
        if not (px and py) then return end
        local zoneWidth, zoneHeight = GetZoneSize(uiMapID)
        if not zoneWidth and zoneHeight then return end
        -- Now we work out the yard-offset for the minimap
        local minimapWidth = mapRadius / zoneWidth
        local minimapHeight = mapRadius / zoneHeight
        return uiMapID, px + (2 * x * minimapWidth), py - (2 * y * minimapHeight)
    end
end
