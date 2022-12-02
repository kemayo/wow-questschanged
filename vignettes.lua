local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local function VignettePosition(vignetteGUID)
    local uiMapID = C_Map.GetBestMapForUnit('player')
    if not uiMapID then return end
    local position = C_VignetteInfo.GetVignettePosition(vignetteGUID, uiMapID)
    if position then
        return uiMapID, position, position:GetXY()
    end
end

local log = {}
local ordered = {}
ns.vignetteLog = log
ns.vignetteLogOrder = ordered
-- QClog = log
function ns:OnVignetteEvent()
	local vignetteids = C_VignetteInfo.GetVignettes()
	if not vignetteids then return end

	for i, instanceid in ipairs(vignetteids) do
        local vignetteInfo = C_VignetteInfo.GetVignetteInfo(instanceid)
        if vignetteInfo and vignetteInfo.vignetteGUID and not log[vignetteInfo.vignetteGUID] then
            local uiMapID, _, x, y = VignettePosition(vignetteInfo.vignetteGUID)
            log[vignetteInfo.vignetteGUID] = {
                id = vignetteInfo.vignetteID,
                guid = vignetteInfo.vignetteGUID,
                -- locations might be nil if it's from an instance
                uiMapID = uiMapID or 0,
                x = x or 0,
                y = y or 0,
                name = vignetteInfo.name,
                time = time(),
                atlas = vignetteInfo.atlasName,
            }
            table.insert(ordered, vignetteInfo.vignetteGUID)
            self:TriggerEvent(self.Event.OnVignetteAdded, log[vignetteInfo.vignetteGUID], vignetteInfo.vignetteGUID)
        end
    end
end
ns.PLAYER_ENTERING_WORLD = ns.OnVignetteEvent
ns.VIGNETTE_MINIMAP_UPDATED = ns.OnVignetteEvent
ns.VIGNETTES_UPDATED = ns.OnVignetteEvent

function ns:RemoveVignette(vignette)
	if not (vignette and vignette.guid) then return end
	log[vignette.guid] = nil
	table.remove(ordered, tIndexOf(ordered, vignette.guid))
	self:TriggerEvent(self.Event.OnVignetteRemoved, vignette, vignette.guid)
end
