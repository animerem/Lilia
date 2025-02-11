﻿function MODULE:ShouldDrawAmmo(weapon)
    if IsValid(weapon) and weapon.DrawAmmo ~= false and lia.config.get("AmmoDrawEnabled", false) then return true end
end

function MODULE:DrawAmmo(weapon)
    local client = LocalPlayer()
    if not IsValid(weapon) then return end
    local clip = weapon:Clip1()
    local count = client:GetAmmoCount(weapon:GetPrimaryAmmoType())
    local secondary = client:GetAmmoCount(weapon:GetSecondaryAmmoType())
    local x, y = ScrW() - 80, ScrH() - 80
    if secondary > 0 then
        lia.util.drawBlurAt(x, y, 64, 64)
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawRect(x, y, 64, 64)
        surface.SetDrawColor(255, 255, 255, 3)
        surface.DrawOutlinedRect(x, y, 64, 64)
        lia.util.drawText(secondary, x + 32, y + 32, nil, 1, 1, "liaBigFont")
    end

    if weapon.GetClass(weapon) ~= "weapon_slam" and clip > 0 or count > 0 then
        x = x - (secondary > 0 and 144 or 64)
        lia.util.drawBlurAt(x, y, 128, 64)
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawRect(x, y, 128, 64)
        surface.SetDrawColor(255, 255, 255, 3)
        surface.DrawOutlinedRect(x, y, 128, 64)
        lia.util.drawText(clip == -1 and count or clip .. "/" .. count, x + 64, y + 32, nil, 1, 1, "liaBigFont")
    end
end
