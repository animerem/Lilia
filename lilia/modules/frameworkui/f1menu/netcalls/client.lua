﻿netstream.Hook(
    "removeF1",
    function()
        if IsValid(lia.gui.menu) then
            lia.gui.menu:remove()
        end
    end
)