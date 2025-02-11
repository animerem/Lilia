﻿lia.command.add("playglobalsound", {
    superAdminOnly = true,
    privilege = "Play Sounds",
    onRun = function(client, arguments)
        local sound = arguments[1]
        if not sound or sound == "" then
            client:notify("You must specify a sound to play.")
            return
        end

        for _, v in player.Iterator() do
            v:PlaySound(sound)
        end
    end
})

lia.command.add("playsound", {
    superAdminOnly = true,
    privilege = "Play Sounds",
    syntax = "[string name] <string sound>",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local sound = arguments[2]
        if not target or not sound or sound == "" then
            client:notify("Invalid target or sound.")
            return
        end

        target:PlaySound(sound)
    end
})

lia.command.add("returntodeathpos", {
    adminOnly = true,
    privilege = "Return Players",
    onRun = function(client)
        if IsValid(client) and client:Alive() then
            local character = client:getChar()
            local oldPos = character:getData("deathPos")
            if oldPos then
                client:SetPos(oldPos)
                character:setData("deathPos", nil)
            else
                client:notify("No death position saved.")
            end
        else
            client:notify("Wait until you respawn.")
        end
    end
})

lia.command.add("roll", {
    adminOnly = false,
    onRun = function(client)
        local rollValue = math.random(0, 100)
        lia.chat.send(client, "roll", rollValue)
    end
})

lia.command.add("chardesc", {
    adminOnly = false,
    syntax = "[string desc]",
    onRun = function(client, arguments)
        local desc = table.concat(arguments, " ")
        if not desc:find("%S") then return client:requestString("Change Description", "Change Your Description", function(text) lia.command.run(client, "chardesc", {text}) end, client:getChar():getDesc()) end
        local character = client:getChar()
        character:setDesc(desc)
        return "@descChanged"
    end
})

lia.command.add("chargetup", {
    adminOnly = false,
    onRun = function(client)
        if not client:hasRagdoll() then
            client:notify("You don't have a ragdoll to get up from!")
            return
        end

        local entity = client:getRagdoll()
        if not IsValid(entity) then return end
        if entity.liaGrace and entity.liaGrace < CurTime() and entity:GetVelocity():Length2D() < 8 and not entity.liaWakingUp then
            entity.liaWakingUp = true
            client:setAction("@gettingUp", 5, function()
                if not IsValid(entity) then return end
                hook.Run("OnCharGetup", client, entity)
                entity:Remove()
            end)
        end
    end
})

lia.command.add("givemoney", {
    adminOnly = false,
    syntax = "[string name] <number amount>",
    privilege = "Give Money",
    onRun = function(client, arguments)
        local amount = tonumber(arguments[2])
        if not amount or not isnumber(amount) or amount <= 0 then
            client:notify("Invalid amount.")
            return
        end

        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            if not client:getChar():hasMoney(amount) then
                client:notify("You don't have enough money.")
                return
            end

            target:getChar():giveMoney(math.floor(amount))
            client:getChar():takeMoney(math.floor(amount))
            local character = client:getChar()
            local id = target:getChar():getID()
            local tCharacter = target:getChar()
            local charID = character:getID()
            target:notify("You were given " .. lia.currency.get(math.floor(amount)) .. " by " .. (hook.Run("isCharRecognized", tCharacter, charID) and client:Name() or "someone you don't recognize"))
            client:notify("You gave " .. lia.currency.get(math.floor(amount)) .. " to " .. (hook.Run("isCharRecognized", character, id) and target:Name() or "someone you don't recognize"))
            client:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_GMOD_GESTURE_ITEM_PLACE, true)
            lia.log.add(client, "moneyGiven", target:Name(), amount)
        else
            client:notify("You need to be looking at someone!")
        end
    end
})

lia.command.add("fallover", {
    adminOnly = false,
    syntax = "[number time]",
    onRun = function(client, arguments)
        if client:GetNW2Bool("FallOverCooldown", false) then
            client:notify("This Command Is In Cooldown!")
            return
        elseif client:IsFrozen() then
            client:notify("You cannot use this while frozen!")
            return
        elseif not client:Alive() then
            client:notify("You cannot use this while dead!")
            return
        elseif client:hasValidVehicle() then
            client:notify("You cannot use this as you are in a vehicle!")
            return
        elseif client:GetMoveType() == MOVETYPE_NOCLIP then
            client:notify("You cannot use this while in noclip!")
            return
        end

        local time = tonumber(arguments[1])
        if not isnumber(time) then time = 5 end
        if time > 0 then
            time = math.Clamp(time, 1, 60)
        else
            time = nil
        end

        client:SetNW2Bool("FallOverCooldown", true)
        if not client:hasRagdoll() then
            client:setRagdolled(true, time)
            timer.Simple(10, function() if IsValid(client) then client:SetNW2Bool("FallOverCooldown", false) end end)
        end
    end
})

lia.command.add("dropmoney", {
    adminOnly = false,
    syntax = "[number amount]",
    onRun = function(client, arguments)
        if client:GetNW2Bool("DropMoneyCooldown", false) then
            local remainingTime = math.ceil(client:GetNW2Float("DropMoneyCooldownEnd", 0) - CurTime())
            client:notify("You can't use this command yet. Cooldown remaining: " .. remainingTime .. " seconds.")
            return
        end

        local amount = tonumber(arguments[1])
        if not amount or not isnumber(amount) or amount < 1 then
            client:notify("@invalidArg")
            return
        end

        amount = math.Round(amount)
        if not client:getChar():hasMoney(amount) then
            client:notify("You lack the funds for this!")
            return
        end

        local moneyCount = 0
        for _, v in pairs(lia.util.findPlayerEntities(client)) do
            if not v:IsPlayer() and v:isMoney() and v.client == client then moneyCount = moneyCount + 1 end
        end

        if moneyCount >= 3 then
            local admins = lia.util.getAdmins()
            for _, admin in ipairs(admins) do
                admin:ChatPrint("Player " .. client:Nick() .. " attempted to drop more than 3 pieces of money. They might be exploiting!")
            end

            client:notify("You can't drop more than 3 pieces of money at a time.")
            return
        end

        client:getChar():takeMoney(amount)
        local money = lia.currency.spawn(client:getItemDropPos(), amount)
        money.client = client
        money.charID = client:getChar():getID()
        money.isMoney = true
        client:SetNW2Bool("DropMoneyCooldown", true)
        client:SetNW2Float("DropMoneyCooldownEnd", CurTime() + 5)
        timer.Simple(5, function() if IsValid(client) then client:SetNW2Bool("DropMoneyCooldown", false) end end)
    end
})

lia.command.add("checkinventory", {
    adminOnly = true,
    privilege = "Check Inventories",
    syntax = "[string charname]",
    AdminStick = {
        Name = "Check Inventory",
        Category = "Character Management",
        SubCategory = "Items",
        Icon = "icon16/box.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local isTargDiff = target ~= client
        if IsValid(target) and target:getChar() and isTargDiff then
            local inventory = target:getChar():getInv()
            inventory:addAccessRule(function(_, action, _) return action == "transfer" end, 1)
            inventory:addAccessRule(function(_, action, _) return action == "repl" end, 1)
            inventory:sync(client)
            net.Start("OpenInvMenu")
            net.WriteEntity(target)
            net.WriteType(inventory:getID())
            net.Send(client)
        elseif not isTargDiff then
            client:notifyLocalized("This isn't meant for checking your own inventory.")
        end
    end
})

lia.command.add("flaggive", {
    adminOnly = true,
    syntax = "[string name] [string flags]",
    privilege = "Manage Flags",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local flags = arguments[2]
            if not flags then
                local available = ""
                for k in SortedPairs(lia.flag.list) do
                    if not target:getChar():hasFlags(k) then available = available .. k .. " " end
                end

                available = available:Trim()
                if available == "" then
                    client:notify("No available flags to give.")
                    return
                end
                return client:requestString("@flagGiveTitle", "@flagGiveDesc", function(text) lia.command.run(client, "flaggive", {target:Name(), text}) end, available)
            end

            target:getChar():giveFlags(flags)
            client:notifyLocalized("flagGive", client:Name(), target:Name(), flags)
        else
            client:notify("Invalid Target!")
        end
    end,
    alias = {"giveflag", "chargiveflag"}
})

lia.command.add("flaggiveall", {
    adminOnly = true,
    syntax = "[string name] [string flags]",
    privilege = "Manage Flags",
    AdminStick = {
        Name = "Give All Flags",
        Category = "Flags Management",
        SubCategory = "Manage All",
        Icon = "icon16/flag_blue.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if not IsValid(target) then
            client:notify("Invalid Target!")
            return
        end

        local character = target:getChar()
        for k, _ in SortedPairs(lia.flag.list) do
            if not character:hasFlags(k) then target:getChar():giveFlags(k) end
        end

        client:notify("You gave this player all flags!")
    end
})

lia.command.add("flagtakeall", {
    adminOnly = true,
    syntax = "[string name] [string flags]",
    privilege = "Manage Flags",
    AdminStick = {
        Name = "Take All Flags",
        Category = "Flags Management",
        SubCategory = "Manage All",
        Icon = "icon16/flag_green.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local character = target and target:getChar()
        if not character then
            client:notify("Invalid Target!")
            return
        end

        for k, _ in SortedPairs(lia.flag.list) do
            if character:hasFlags(k) then target:getChar():takeFlags(k) end
        end

        client:notify("You took this player's flags!")
    end
})

lia.command.add("flagtake", {
    adminOnly = true,
    syntax = "[string name] [string flags]",
    privilege = "Manage Flags",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local flags = arguments[2]
            if not flags then
                local currentFlags = target:getChar():getFlags()
                return client:requestString("@flagTakeTitle", "@flagTakeDesc", function(text) lia.command.run(client, "flagtake", {target:Name(), text}) end, table.concat(currentFlags, ", "))
            end

            target:getChar():takeFlags(flags)
            client:notifyLocalized("flagTake", client:Name(), flags, target:Name())
        else
            client:notify("Invalid Target!")
        end
    end,
    alias = {"takeflag"}
})

lia.command.add("bringlostitems", {
    superAdminOnly = true,
    privilege = "Manage Items",
    onRun = function(client)
        for _, v in pairs(ents.FindInSphere(client:GetPos(), 500)) do
            if v:isItem() then v:SetPos(client:GetPos()) end
        end
    end
})

lia.command.add("cleanitems", {
    superAdminOnly = true,
    privilege = "Clean Entities",
    onRun = function(client)
        local count = 0
        for _, v in pairs(ents.FindByClass("lia_item")) do
            count = count + 1
            v:Remove()
        end

        client:notify(count .. " items have been cleaned up from the map.")
    end
})

lia.command.add("cleanprops", {
    superAdminOnly = true,
    privilege = "Clean Entities",
    onRun = function(client)
        local count = 0
        for _, v in ents.Iterator() do
            if v:isProp() then
                count = count + 1
                v:Remove()
            end
        end

        client:notify(count .. " props have been cleaned up from the map.")
    end
})

lia.command.add("cleannpcs", {
    superAdminOnly = true,
    privilege = "Clean Entities",
    onRun = function(client)
        local count = 0
        for _, v in ents.Iterator() do
            if IsValid(v) and v:IsNPC() then
                count = count + 1
                v:Remove()
            end
        end

        client:notify(count .. " NPCs have been cleaned up from the map.")
    end
})

lia.command.add("charunban", {
    syntax = "[string name]",
    superAdminOnly = true,
    privilege = "Manage Characters",
    AdminStick = {
        Name = "Unban Character",
        Category = "Character Management",
        SubCategory = "Bans",
        Icon = "icon16/user_add.png",
    },
    onRun = function(client, arguments)
        if (client.liaNextSearch or 0) >= CurTime() then return L("charSearching", client) end
        local name = table.concat(arguments, " ")
        for _, v in pairs(lia.char.loaded) do
            if lia.util.stringMatches(v:getName(), name) then
                if v:getData("banned") then
                    v:setData("banned", nil)
                    v:setData("permakilled", nil)
                    return lia.notices.notifyLocalized("charUnBan", nil, client:Name(), v:getName())
                else
                    return "@charNotBanned"
                end
            end
        end

        client.liaNextSearch = CurTime() + 15
        lia.db.query("SELECT _id, _name, _data FROM lia_characters WHERE _name LIKE \"%" .. lia.db.escape(name) .. "%\" LIMIT 1", function(data)
            if data and data[1] then
                local charID = tonumber(data[1]._id)
                local charData = util.JSONToTable(data[1]._data or "[]")
                client.liaNextSearch = 0
                if not charData.banned then
                    client:notifyLocalized("charNotBanned")
                    return
                end

                charData.banned = nil
                lia.db.updateTable({
                    _data = util.TableToJSON(charData)
                }, nil, nil, "_id = " .. charID)

                lia.notices.notifyLocalized("charUnBan", nil, client:Name(), data[1]._name)
            end
        end)
    end
})

lia.command.add("clearinv", {
    superAdminOnly = true,
    syntax = "[string name]",
    privilege = "Manage Characters",
    AdminStick = {
        Name = "Clear Inventory",
        Category = "Character Management",
        SubCategory = "Items",
        Icon = "icon16/bin.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            target:getChar():getInv():wipeItems()
            client:notifyLocalized("resetInv", target:getChar():getName())
        else
            client:notify("Invalid Target!")
        end
    end
})

lia.command.add("charkick", {
    adminOnly = true,
    syntax = "[string name]",
    privilege = "Kick Characters",
    AdminStick = {
        Name = "Kick Character",
        Category = "Character Management",
        SubCategory = "Bans",
        Icon = "icon16/user_delete.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) then
            local character = target:getChar()
            if character then
                for _, v in player.Iterator() do
                    v:notifyLocalized("charKick", client:Name(), target:Name())
                end

                character:kick()
            else
                client:notify("Target does not have an active character.")
            end
        else
            client:notify("Invalid Target!")
        end
    end
})

lia.command.add("freezeallprops", {
    superAdminOnly = true,
    privilege = "Manage Characters",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) then
            local count = 0
            for _, v in pairs(cleanup.GetList(target)[target:UniqueID()] or {}) do
                for _, n in pairs(v) do
                    if IsValid(n) and IsValid(n:GetPhysicsObject()) then
                        n:GetPhysicsObject():EnableMotion(false)
                        count = count + 1
                    end
                end
            end

            client:notify("You have frozen all of " .. target:Name() .. "'s Entities.")
            client:ChatPrint("Frozen " .. count .. " Entities belonging to " .. target:Name())
        else
            client:notify("Invalid Target!")
        end
    end
})

lia.command.add("charban", {
    superAdminOnly = true,
    syntax = "[string name]",
    privilege = "Manage Characters",
    AdminStick = {
        Name = "Ban Character",
        Category = "Character Management",
        SubCategory = "Bans",
        Icon = "icon16/user_red.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) then
            local character = target:getChar()
            if character then
                character:setData("banned", true)
                character:setData("charBanInfo", {
                    name = client.steamName and client:steamName() or client:Name(),
                    steamID = client:SteamID(),
                    rank = client:GetUserGroup()
                })

                character:save()
                character:kick()
                client:notifyLocalized("charBan", client:Name(), target:Name())
            else
                client:notify("Target does not have an active character.")
            end
        else
            client:notify("Invalid Target!")
        end
    end
})

lia.command.add("checkallmoney", {
    superAdminOnly = true,
    privilege = "Get Character Info",
    onRun = function(client)
        for _, v in player.Iterator() do
            if v:getChar() then client:ChatPrint(v:Name() .. " has " .. lia.currency.get(v:getChar():getMoney()) .. "s") end
        end
    end
})

lia.command.add("checkflags", {
    adminOnly = true,
    privilege = "Get Character Info",
    syntax = "[string charname]",
    AdminStick = {
        Name = "Get Character Flags",
        Category = "Player Informations",
        SubCategory = "Get Informations",
        Icon = "icon16/flag_yellow.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local flags = target:getChar():getFlags()
            if flags and #flags > 0 then
                client:ChatPrint(target:Name() .. " — " .. table.concat(flags, ", "))
            else
                client:ChatPrint(target:Name() .. " has no flags.")
            end
        else
            client:notify("Invalid Target!")
        end
    end
})

lia.command.add("findallflags", {
    adminOnly = true,
    privilege = "Get Character Info",
    onRun = function(client)
        local onDutyStaffList = {}
        for _, target in player.Iterator() do
            if target:isStaffOnDuty() then
                local char = target:getChar()
                table.insert(onDutyStaffList, {
                    name = target:Nick(),
                    class = char:getClass() and lia.class.list[char:getClass()].name or "N/A",
                    faction = char:getFaction(),
                    characterID = char:getID(),
                    usergroup = target:GetUserGroup(),
                    flags = table.concat(char:getFlags(), ", ")
                })
            end
        end

        if #onDutyStaffList > 0 then
            lia.util.CreateTableUI(client, "On Duty Staff Flags", {
                {
                    name = "Name",
                    field = "name"
                },
                {
                    name = "Class",
                    field = "class"
                },
                {
                    name = "Faction",
                    field = "faction"
                },
                {
                    name = "Character ID",
                    field = "characterID"
                },
                {
                    name = "Usergroup",
                    field = "usergroup"
                },
                {
                    name = "Flags",
                    field = "flags"
                }
            }, onDutyStaffList)
        else
            client:notify("No on-duty staff members found!")
        end
    end
})

lia.command.add("checkmoney", {
    adminOnly = true,
    privilege = "Get Character Info",
    syntax = "[string charname]",
    AdminStick = {
        Name = "Check Money",
        Category = "Character Management",
        SubCategory = "Money",
        Icon = "icon16/money.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if target and target:getChar() then
            local money = target:getChar():getMoney()
            client:ChatPrint(target:GetName() .. " has: " .. lia.currency.get(money) .. "s")
        else
            client:ChatPrint("Invalid Target")
        end
    end
})

lia.command.add("listbodygroups", {
    adminOnly = true,
    privilege = "Get Character Info",
    syntax = "[string charname]",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if target then
            local bodygroups = {}
            for i = 0, target:GetNumBodyGroups() - 1 do
                if target:GetBodygroupCount(i) > 1 then
                    table.insert(bodygroups, {
                        group = i,
                        name = target:GetBodygroupName(i),
                        range = "0-" .. target:GetBodygroupCount(i) - 1
                    })
                end
            end

            if #bodygroups > 0 then
                lia.util.CreateTableUI(client, "Bodygroups for " .. target:Nick(), {
                    {
                        name = "Group ID",
                        field = "group"
                    },
                    {
                        name = "Name",
                        field = "name"
                    },
                    {
                        name = "Range",
                        field = "range"
                    }
                }, bodygroups)
            else
                client:notify("No bodygroups available for this model.")
            end
        else
            client:notify("Invalid Target!")
        end
    end
})

lia.command.add("chargetmodel", {
    adminOnly = true,
    syntax = "[string name]",
    privilege = "Get Character Info",
    AdminStick = {
        Name = "Get Character Model",
        Category = "Player Informations",
        SubCategory = "Get Informations",
        Icon = "icon16/user_gray.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local model = target:GetModel()
            client:notify("Character Model: " .. model)
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("chargetname", {
    adminOnly = true,
    syntax = "[string name]",
    privilege = "Get Character Info",
    AdminStick = {
        Name = "Get Character Name",
        Category = "Player Informations",
        SubCategory = "Get Informations",
        Icon = "icon16/user.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local name = target:getChar():getName()
            client:notify("Character Name: " .. name)
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("chargethealth", {
    adminOnly = true,
    syntax = "[string name]",
    privilege = "Get Character Info",
    AdminStick = {
        Name = "Get Character Health",
        Category = "Player Informations",
        SubCategory = "Get Informations",
        Icon = "icon16/heart.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local health = target:Health()
            client:notify("Character Health: " .. health)
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("chargetmoney", {
    adminOnly = true,
    syntax = "[string name]",
    privilege = "Get Character Info",
    AdminStick = {
        Name = "Get Character Money",
        Category = "Player Informations",
        SubCategory = "Get Informations",
        Icon = "icon16/money.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local money = target:getChar():getMoney()
            client:notify("Character Money: " .. lia.currency.get(money))
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("chargetinventory", {
    adminOnly = true,
    syntax = "[string name]",
    privilege = "Get Character Info",
    AdminStick = {
        Name = "Get Character Inventory",
        Category = "Player Informations",
        SubCategory = "Get Informations",
        Icon = "icon16/box.png",
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local inventory = target:getChar():getInv()
            local count = 0
            local items = ""
            for _, item in pairs(inventory:getItems()) do
                count = count + 1
                items = items .. item.name .. ", "
            end

            if count > 0 then
                items = string.sub(items, 1, -3)
                client:ChatPrint("Character Inventory: " .. items)
            else
                client:notify("Character Inventory is empty.")
            end
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("charsetspeed", {
    adminOnly = true,
    privilege = "Manage Character Stats",
    syntax = "[string name] <number speed>",
    AdminStick = {
        Name = "Set Character Speed",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/lightning.png",
        ExtraFields = {
            ["speed"] = "number"
        }
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local speed = tonumber(arguments[2]) or lia.config.WalkSpeed
        if IsValid(target) and target:getChar() then
            target:SetRunSpeed(speed)
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("charsetmodel", {
    adminOnly = true,
    syntax = "[string name] <string model>",
    privilege = "Manage Character Informations",
    AdminStick = {
        Name = "Set Character Model",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/user_gray.png",
        ExtraFields = {
            ["model"] = "text"
        }
    },
    onRun = function(client, arguments)
        if not arguments[2] then return L("invalidArg", 2) end
        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local oldModel = target:getChar():getModel()
            target:getChar():setModel(arguments[2])
            target:SetupHands()
            client:notifyLocalized("cChangeModel", client:Name(), target:Name(), arguments[2])
            lia.log.add(client, "charsetmodel", target:Name(), arguments[2], oldModel)
        end
    end
})

lia.command.add("chargiveitem", {
    superAdminOnly = true,
    syntax = "[string name] <string item>",
    privilege = "Manage Items",
    AdminStick = {
        Name = "Give Item",
        Category = "Character Management",
        SubCategory = "Items",
        Icon = "icon16/user_gray.png",
        ExtraFields = {
            ["item"] = function()
                local items = {}
                for _, v in pairs(lia.item.list) do
                    table.insert(items, v.uniqueID)
                end
                return items, "combo"
            end,
        }
    },
    onRun = function(client, arguments)
        if not arguments[2] then
            client:notify("You must specify an item to give.")
            return
        end

        local target = lia.command.findPlayer(client, arguments[1])
        if IsValid(target) and target:getChar() then
            local uniqueID = arguments[2]:lower()
            if not lia.item.list[uniqueID] then
                for k, v in SortedPairs(lia.item.list) do
                    if lia.util.stringMatches(v.name, uniqueID) then
                        uniqueID = k
                        break
                    end
                end
            end

            local inv = target:getChar():getInv()
            local succ, err = inv:add(uniqueID)
            if succ then
                target:notifyLocalized("itemCreated")
                if target ~= client then client:notifyLocalized("itemCreated") end
            else
                target:notify(tostring(succ))
                target:notify(tostring(err))
            end
        else
            client:notify("Invalid Target!")
        end
    end,
    alias = {"giveitem"}
})

lia.command.add("charsetdesc", {
    adminOnly = true,
    syntax = "[string name] [string desc]",
    privilege = "Manage Character Informations",
    AdminStick = {
        Name = "Set Character Description",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/user_comment.png",
        ExtraFields = {
            ["desc"] = "text"
        }
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if not IsValid(target) then
            client:notify("Invalid Target!")
            return
        end

        if not target:getChar() then
            client:notify("Target does not have an active character.")
            return
        end

        local desc = table.concat(arguments, " ", 2)
        if not desc:find("%S") then return client:requestString("Change " .. target:Name() .. "'s Description", "Enter new description", function(text) lia.command.run(client, "charsetdesc", {arguments[1], text}) end, target:getChar():getDesc()) end
        target:getChar():setDesc(desc)
        return "Successfully changed " .. target:Name() .. "'s description"
    end
})

lia.command.add("charsetname", {
    adminOnly = true,
    syntax = "[string name] [string newName]",
    privilege = "Manage Character Informations",
    AdminStick = {
        Name = "Set Character Name",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/user_edit.png",
        ExtraFields = {
            ["newName"] = "text"
        }
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if not IsValid(target) then
            client:notify("Invalid Target!")
            return
        end

        if not arguments[2] then return client:requestString("@chgName", "@chgNameDesc", function(text) lia.command.run(client, "charsetname", {target:Name(), text}) end, target:Name()) end
        local newName = table.concat(arguments, " ", 2)
        target:getChar():setName(newName:gsub("#", "#?"))
        client:notifyLocalized("cChangeName", client:Name(), target:Name(), newName)
    end
})

lia.command.add("charsetscale", {
    adminOnly = true,
    syntax = "[string name] <number value>",
    privilege = "Manage Character Stats",
    AdminStick = {
        Name = "Set Character Scale",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/arrow_out.png",
        ExtraFields = {
            ["value"] = "number"
        }
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local scale = tonumber(arguments[2]) or 1
        if IsValid(target) and target:getChar() then
            target:SetModelScale(scale, 0)
            client:notify("You changed " .. target:Name() .. "'s model scale to " .. scale)
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("charsetjump", {
    adminOnly = true,
    syntax = "[string name] <number power>",
    privilege = "Manage Character Stats",
    AdminStick = {
        Name = "Set Character Jump Height",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/arrow_up.png",
        ExtraFields = {
            ["power"] = "number"
        }
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local power = tonumber(arguments[2]) or 200
        if IsValid(target) and target:getChar() then
            target:SetJumpPower(power)
            client:notify("You changed " .. target:Name() .. "'s jump power to " .. power)
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("charsetbodygroup", {
    adminOnly = true,
    syntax = "[string name] <string bodyGroup> [number value]",
    privilege = "Manage Bodygroups",
    AdminStick = {
        Name = "Set Character Bodygroup",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/user_gray.png",
        ExtraFields = {
            ["bodyGroup"] = "text",
            ["value"] = "number"
        }
    },
    onRun = function(client, arguments)
        local name = arguments[1]
        local bodyGroup = arguments[2]
        local value = tonumber(arguments[3])
        local target = lia.command.findPlayer(client, name)
        if IsValid(target) and target:getChar() then
            local index = target:FindBodygroupByName(bodyGroup)
            if index > -1 then
                if value and value < 1 then value = nil end
                local groups = target:getChar():getData("groups", {})
                groups[index] = value
                target:getChar():setData("groups", groups)
                target:SetBodygroup(index, value or 0)
                client:notifyLocalized("cChangeGroups", client:Name(), target:Name(), bodyGroup, value or 0)
            else
                client:notify("@invalidArg")
            end
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("charsetskin", {
    adminOnly = true,
    syntax = "[string name] [number skin]",
    privilege = "Manage Character Stats",
    AdminStick = {
        Name = "Set Character Skin",
        Category = "Player Informations",
        SubCategory = "Set Informations",
        Icon = "icon16/user_gray.png",
        ExtraFields = {
            ["skin"] = "number"
        }
    },
    onRun = function(client, arguments)
        local name = arguments[1]
        local skin = tonumber(arguments[2])
        local target = lia.command.findPlayer(client, name)
        if IsValid(target) and target:getChar() then
            target:getChar():setData("skin", skin)
            target:SetSkin(skin or 0)
            client:notifyLocalized("cChangeSkin", client:Name(), target:Name(), skin or 0)
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("charsetmoney", {
    superAdminOnly = true,
    syntax = "[string charname] <number amount>",
    privilege = "Manage Characters",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local amount = tonumber(arguments[2])
        if not amount or not isnumber(amount) or amount < 0 then
            client:notify("@invalidArg")
            return
        end

        if IsValid(target) and target:getChar() then
            target:getChar():setMoney(math.floor(amount))
            client:notify("You set " .. target:Name() .. "'s money to " .. lia.currency.get(math.floor(amount)))
        else
            client:notify("Invalid Target")
        end
    end
})

lia.command.add("charaddmoney", {
    superAdminOnly = true,
    syntax = "[string charname] <number amount>",
    privilege = "Manage Characters",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local amount = tonumber(arguments[2])
        if not amount or not isnumber(amount) then
            client:notify("@invalidArg")
            return
        end

        if IsValid(target) and target:getChar() then
            amount = math.Round(amount)
            local currentMoney = target:getChar():getMoney()
            target:getChar():setMoney(currentMoney + amount)
            client:notify("You added " .. lia.currency.get(amount) .. " to " .. target:Name() .. "'s money. Total: " .. lia.currency.get(currentMoney + amount))
        else
            client:notify("Invalid Target")
        end
    end,
    alias = {"chargivemoney"}
})

lia.command.add("flaglist", {
    adminOnly = true,
    privilege = "Manage Flags",
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local flags = {}
        if IsValid(target) then
            local character = target:getChar()
            if character then
                for flag, data in pairs(lia.flag.list) do
                    if character:hasFlags(flag) then
                        table.insert(flags, {
                            flag = flag,
                            desc = data.desc
                        })
                    end
                end
            end
        else
            for flag, data in pairs(lia.flag.list) do
                table.insert(flags, {
                    flag = flag,
                    desc = data.desc
                })
            end
        end

        lia.util.CreateTableUI(client, "Flag List", {
            {
                name = "Flag",
                field = "flag"
            },
            {
                name = "Description",
                field = "desc"
            }
        }, flags)
    end,
    alias = {"flags"}
})

lia.command.add("itemlist", {
    adminOnly = true,
    privilege = "List Items",
    onRun = function(client)
        local items = {}
        for _, item in pairs(lia.item.list) do
            table.insert(items, {
                uniqueID = item.uniqueID or "N/A",
                name = item.name or "N/A",
                desc = item.desc or "N/A",
                category = item.category or "Miscellaneous",
                price = item.price or "0"
            })
        end

        lia.util.CreateTableUI(client, "Item List", {
            {
                name = "Unique ID",
                field = "uniqueID"
            },
            {
                name = "Name",
                field = "name"
            },
            {
                name = "Description",
                field = "desc"
            },
            {
                name = "Category",
                field = "category"
            },
            {
                name = "Price",
                field = "price"
            }
        }, items)
    end
})

lia.command.add("modulelist", {
    adminOnly = false,
    privilege = "List Players",
    onRun = function(client)
        local modules = {}
        for uniqueID, mod in pairs(lia.module.list) do
            table.insert(modules, {
                uniqueID = uniqueID,
                name = mod.name or "Unknown",
                desc = mod.desc or "No description available",
                author = mod.author or "Anonymous",
                discord = mod.discord or "N/A",
                version = mod.version or "N/A"
            })
        end

        lia.util.CreateTableUI(client, "Modules List", {
            {
                name = "Unique ID",
                field = "uniqueID"
            },
            {
                name = "Name",
                field = "name"
            },
            {
                name = "Description",
                field = "desc"
            },
            {
                name = "Author",
                field = "author"
            },
            {
                name = "Discord",
                field = "discord"
            },
            {
                name = "Version",
                field = "version"
            }
        }, modules)
    end,
    alias = {"modules"}
})

lia.command.add("listents", {
    adminOnly = true,
    privilege = "List Entities",
    onRun = function(client)
        local entityList = {}
        for _, v in ents.Iterator() do
            local creator = v:GetCreator()
            local model = v:GetModel()
            if not model or not isstring(model) or not model:find("%.mdl$") then continue end
            table.insert(entityList, {
                class = v:GetClass(),
                creator = IsValid(creator) and creator:Nick() or "N/A",
                model = model,
                health = v:Health() or "∞"
            })
        end

        lia.util.CreateTableUI(client, "Entity List", {
            {
                name = "Class",
                field = "class"
            },
            {
                name = "Creator",
                field = "creator"
            },
            {
                name = "Model",
                field = "model"
            },
            {
                name = "Health",
                field = "health"
            }
        }, entityList)
    end
})

lia.command.add("liststaff", {
    adminOnly = true,
    privilege = "List Players",
    onRun = function(client)
        local staffList = {}
        for _, target in player.Iterator() do
            if target:isStaff() then
                local char = target:getChar()
                table.insert(staffList, {
                    name = target:Nick(),
                    class = char:getClass() and lia.class.list[char:getClass()].name or "N/A",
                    faction = char:getFaction(),
                    characterID = char:getID(),
                    usergroup = target:GetUserGroup()
                })
            end
        end

        if #staffList > 0 then
            lia.util.CreateTableUI(client, "Staff List", {
                {
                    name = "Name",
                    field = "name"
                },
                {
                    name = "Class",
                    field = "class"
                },
                {
                    name = "Faction",
                    field = "faction"
                },
                {
                    name = "Character ID",
                    field = "characterID"
                },
                {
                    name = "Usergroup",
                    field = "usergroup"
                }
            }, staffList)
        else
            client:notify("No valid players found!")
        end
    end
})

lia.command.add("listondutystaff", {
    adminOnly = true,
    privilege = "List Players",
    onRun = function(client)
        local onDutyStaffList = {}
        for _, target in player.Iterator() do
            if target:isStaffOnDuty() then
                local char = target:getChar()
                table.insert(onDutyStaffList, {
                    name = target:Nick(),
                    class = char:getClass() and lia.class.list[char:getClass()].name or "N/A",
                    faction = char:getFaction(),
                    characterID = char:getID(),
                    usergroup = target:GetUserGroup()
                })
            end
        end

        if #onDutyStaffList > 0 then
            lia.util.CreateTableUI(client, "On Duty Staff List", {
                {
                    name = "Name",
                    field = "name"
                },
                {
                    name = "Class",
                    field = "class"
                },
                {
                    name = "Faction",
                    field = "faction"
                },
                {
                    name = "Character ID",
                    field = "characterID"
                },
                {
                    name = "Usergroup",
                    field = "usergroup"
                }
            }, onDutyStaffList)
        else
            client:notify("No on-duty staff members found!")
        end
    end
})

lia.command.add("listvip", {
    adminOnly = true,
    privilege = "List Players",
    onRun = function(client)
        local vipList = {}
        for _, target in player.Iterator() do
            if target:isVIP() then
                local char = target:getChar()
                table.insert(vipList, {
                    name = target:Nick(),
                    class = char:getClass() and lia.class.list[char:getClass()].name or "N/A",
                    faction = char:getFaction(),
                    characterID = char:getID(),
                    usergroup = target:GetUserGroup()
                })
            end
        end

        if #vipList > 0 then
            lia.util.CreateTableUI(client, "VIP List", {
                {
                    name = "Name",
                    field = "name"
                },
                {
                    name = "Class",
                    field = "class"
                },
                {
                    name = "Faction",
                    field = "faction"
                },
                {
                    name = "Character ID",
                    field = "characterID"
                },
                {
                    name = "Usergroup",
                    field = "usergroup"
                }
            }, vipList)
        else
            client:notify("No valid players found!")
        end
    end
})

lia.command.add("listusers", {
    adminOnly = true,
    privilege = "List Players",
    onRun = function(client)
        local userList = {}
        for _, target in player.Iterator() do
            if target:isUser() then
                local char = target:getChar()
                table.insert(userList, {
                    name = target:Nick(),
                    class = char:getClass() and lia.class.list[char:getClass()].name or "N/A",
                    faction = char:getFaction(),
                    characterID = char:getID(),
                    usergroup = target:GetUserGroup()
                })
            end
        end

        if #userList > 0 then
            lia.util.CreateTableUI(client, "User List", {
                {
                    name = "Name",
                    field = "name"
                },
                {
                    name = "Class",
                    field = "class"
                },
                {
                    name = "Faction",
                    field = "faction"
                },
                {
                    name = "Character ID",
                    field = "characterID"
                },
                {
                    name = "Usergroup",
                    field = "usergroup"
                }
            }, userList)
        else
            client:notify("No valid players found!")
        end
    end
})

lia.command.add("globalbotsay", {
    superAdminOnly = true,
    syntax = "<string message>",
    privilege = "Bot Say",
    onRun = function(client, arguments)
        local message = table.concat(arguments, " ")
        if message == "" then
            client:notify("You must specify a message.")
            return
        end

        for _, bot in player.Iterator() do
            if bot:IsBot() then bot:Say(message) end
        end
    end
})

lia.command.add("botsay", {
    superAdminOnly = true,
    syntax = "<string botName> <string message>",
    privilege = "Bot Say",
    onRun = function(client, arguments)
        if #arguments < 2 then
            client:notify("You must specify a bot and a message.")
            return
        end

        local botName = arguments[1]
        local message = table.concat(arguments, " ", 2)
        local targetBot
        for _, bot in player.Iterator() do
            if bot:IsBot() and string.find(string.lower(bot:Nick()), string.lower(botName)) then
                targetBot = bot
                break
            end
        end

        if not targetBot then
            client:notify("No bot found with the name: " .. botName)
            return
        end

        targetBot:Say(message)
    end
})

lia.command.add("forcesay", {
    superAdminOnly = true,
    syntax = "<string botName> <string message>",
    privilege = "Force Say",
    AdminStick = {
        Name = "Force Say",
        Category = "Moderation Tools",
        SubCategory = "Force Say",
        Icon = "icon16/comments.png",
        ExtraFields = {
            ["message"] = "text"
        }
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        local message = table.concat(arguments, " ", 2)
        if not IsValid(target) or not target:IsBot() then
            client:notify("Invalid bot target!")
            return
        end

        if message == "" then
            client:notify("You must specify a message.")
            return
        end

        target:Say(message)
    end
})

lia.command.add("pm", {
    syntax = "[string charname] <string message>",
    onRun = function(client, arguments)
        local targetName = arguments[1]
        local message = table.concat(arguments, " ", 2)
        local target = lia.command.findPlayer(client, targetName)
        if not target then
            client:notify("Invalid Target!")
            return
        end

        if not message:find("%S") then
            client:notify("You must specify a message.")
            return
        end

        lia.chat.send(client, "pm", message, false, {client, target})
    end
})
