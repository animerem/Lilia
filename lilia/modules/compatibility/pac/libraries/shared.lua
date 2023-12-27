﻿------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:setupPACDataFromItems()
    for itemType, item in pairs(lia.item.list) do
        if istable(item.pacData) then self.partData[itemType] = item.pacData end
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:InitializedModules()
    timer.Simple(1, function() self:setupPACDataFromItems() end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:isAllowedToUsePAC(client)
    return CAMI.PlayerHasAccess(client, "Staff Permissions - Can Use PAC3", nil) or client:getChar():hasFlags("P")
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:CanWearParts(client)
    return self:isAllowedToUsePAC(client)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:PrePACEditorOpen(client)
    return self:isAllowedToUsePAC(client)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:PrePACConfigApply(client)
    return self:isAllowedToUsePAC(client)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:TryViewModel(ent)
    return ent == pac.LocalPlayer:GetViewModel() and pac.LocalPlayer or ent
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
function PACCompatibility:PAC3RegisterEvents()
    local playerMeta = FindMetaTable("Player")
    local events = {
        {
            name = "weapon_raised",
            args = {},
            available = function() return playerMeta.isWepRaised ~= nil end,
            func = function(_, _, ent)
                ent = self:TryViewModel(ent)
                return ent.isWepRaised and ent:isWepRaised() or false
            end
        }
    }

    for _, v in ipairs(events) do
        local available = v.available
        local eventObject = pac.CreateEvent(v.name, v.args)
        eventObject.Think = v.func
        function eventObject:IsAvailable()
            return available()
        end

        pac.RegisterEvent(eventObject)
    end
end
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------