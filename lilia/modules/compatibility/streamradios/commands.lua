﻿lia.command.add("3dradioclean", {
    superAdminOnly = true,
    privilege = "Clean Radios",
    onRun = function(client)
        for _, entity in pairs(ents.FindByClass("sent_streamradio")) do
            entity:Remove()
        end

        client:notify("Cleanup done")
    end
})
