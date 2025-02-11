﻿local PANEL = {}
PANEL.pnlTypes = {
    [1] = {
        col = Color(200, 60, 60),
        icon = "icon16/exclamation.png"
    },
    [2] = {
        col = Color(255, 100, 100),
        icon = "icon16/cross.png"
    },
    [3] = {
        col = Color(255, 100, 100),
        icon = "icon16/cancel.png"
    },
    [4] = {
        col = Color(100, 185, 255),
        icon = "icon16/book.png"
    },
    [5] = {
        col = Color(220, 200, 110),
        icon = "icon16/error.png"
    },
    [6] = {
        col = Color(64, 185, 85),
        icon = "icon16/accept.png"
    },
    [7] = {
        col = Color(100, 185, 255),
        icon = "icon16/information.png"
    },
}

function PANEL:Init()
    self.type = 1
    self.text = self:Add("DLabel")
    self.text:SetFont("liaNoticeFont")
    self.text:SetContentAlignment(5)
    self.text:SetTextColor(color_white)
    self.text:SizeToContents()
    self.text:Dock(FILL)
    self.text:DockMargin(2, 2, 2, 2)
    self.text:SetExpensiveShadow(1, Color(25, 25, 25, 120))
    self:SetTall(28)
end

function PANEL:setType(value)
    self.type = value
    return
end

function PANEL:setText(value)
    self.text:SetText(value)
end

function PANEL:setFont(value)
    self.text:SetFont(value)
end

function PANEL:Paint()
    self.material = lia.util.getMaterial(self.pnlTypes[self.type].icon)
    local col = self.pnlTypes[self.type].col
    local mat = self.material
    local size = self:GetTall() * .6
    draw.RoundedBox(4, 0, 0, self:GetWide(), self:GetTall(), col)
    if mat then
        surface.SetDrawColor(color_white)
        surface.SetMaterial(mat)
        surface.DrawTexturedRect(size / 2, self:GetTall() / 2 - size / 2 + 1, size, size)
    end
end

vgui.Register("liaNoticeBar", PANEL, "DPanel")
