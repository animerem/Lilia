local Inventory = lia.Inventory
-- Constants for inventory actions.
INV_REPLICATE = "repl" -- Replicate data about the inventory to a player.
local INV_TABLE_NAME = "inventories"
local INV_DATA_TABLE_NAME = "invdata"
util.AddNetworkString("ixInventoryInit")
util.AddNetworkString("ixInventoryData")
util.AddNetworkString("ixInventoryDelete")
util.AddNetworkString("ixInventoryAdd")
util.AddNetworkString("ixInventoryRemove")
util.AddNetworkString("liaInventoryInit")
util.AddNetworkString("liaInventoryData")
util.AddNetworkString("liaInventoryDelete")
util.AddNetworkString("liaInventoryAdd")
util.AddNetworkString("liaInventoryRemove")

-- Given an item type string, creates an instance of that item type
-- and adds it to this inventory. A promise is returned containing
-- the newly created item after it has been added to the inventory.
function Inventory:addItem(item)
    self.items[item:getID()] = item
    item.invID = self:getID()
    local id = self.id

    if not isnumber(id) then
        id = NULL
    end

    lia.db.updateTable({
        _invID = id
    }, nil, "items", "_itemID = " .. item:getID())

    -- Replicate adding the item to this inventory client-side
    self:syncItemAdded(item)

    return self
end

-- Sample implementation of Inventory:add - delegates to addItem
function Inventory:add(item)
    return self:addItem(item)
end

function Inventory:syncItemAdded(item)
    assert(istable(item) and item.getID, "cannot sync non-item")
    assert(self.items[item:getID()], "Item " .. item:getID() .. " does not belong to " .. self.id)
    local recipients = self:getRecipients()
    item:sync(recipients)
    net.Start("liaInventoryAdd")
    net.WriteUInt(item:getID(), 32)
    net.WriteType(self.id)
    net.Send(recipients)
end

-- Called to handle the logic for creating the data storage for this.
-- Returns a promise that is resolved after the storing is done.
function Inventory:initializeStorage(initialData)
    local d = deferred.new()
    local charID = initialData.char

    lia.db.insertTable({
        _invType = self.typeID,
        _charID = charID
    }, function(results, lastID)
        local count = 0
        local expected = table.Count(initialData)

        -- Ignore the char data since it is stored in the old charID column.
        if initialData.char then
            expected = expected - 1
        end

        if expected == 0 then return d:resolve(lastID) end

        for key, value in pairs(initialData) do
            if key == "char" then continue end

            lia.db.insertTable({
                _invID = lastID,
                _key = key,
                _value = {value}
            }, function()
                count = count + 1

                if count == expected then
                    d:resolve(lastID)
                end
            end, INV_DATA_TABLE_NAME)
        end
    end, INV_TABLE_NAME)

    return d
end

-- Called when some inventory with a certain ID needs to be loaded.
-- If this type is responsible for loading that inventory ID in particular,
-- then a promise that resolves to an inventory should be returned.
-- This allows for custom data storage of inventories.
function Inventory:restoreFromStorage(id)
end

-- Removes an item corresponding to the given item ID if it is in this
-- inventory. If the item belongs to this inventory, it is then deleted.
-- A promise is returned which is resolved after removal from this.
function Inventory:removeItem(itemID, preserveItem)
    assert(isnumber(itemID), "itemID must be a number for remove")
    local d = deferred.new()
    local instance = self.items[itemID]

    if instance then
        instance.invID = 0
        self.items[itemID] = nil
        net.Start("liaInventoryRemove")
        net.WriteUInt(itemID, 32)
        net.WriteType(self:getID())
        net.Send(self:getRecipients())

        if not preserveItem then
            d:resolve(instance:delete())
        else
            lia.db.updateTable({
                _invID = NULL
            }, function()
                d:resolve()
            end, "items", "_itemID = " .. itemID)
        end
    else
        d:resolve()
    end

    return d
end

-- Sample implementation of Inventory:remove() - delegate to removeItem
function Inventory:remove(itemID)
    return self:removeItem(itemID)
end

-- Stores arbitrary data that can later be looked up using the given key.
function Inventory:setData(key, value)
    local oldValue = self.data[key]
    self.data[key] = value
    local keyData = self.config.data[key]

    if key == "char" then
        -- Compatibility with NS1.1 inventory
        lia.db.updateTable({
            _charID = value
        }, nil, INV_TABLE_NAME, "_invID = " .. self:getID())
    elseif not keyData or not keyData.notPersistent then
        if value == nil then
            lia.db.delete(INV_DATA_TABLE_NAME, "_invID = " .. self.id .. " AND _key = '" .. lia.db.escape(key) .. "'")
        else
            lia.db.upsert({
                _invID = self.id,
                _key = key,
                _value = {value}
            }, INV_DATA_TABLE_NAME)
        end
    end

    self:syncData(key)
    self:onDataChanged(key, oldValue, value)

    return self
end

-- Whether or not a client can interact with this inventory.
function Inventory:canAccess(action, context)
    context = context or {}
    local result

    for _, rule in ipairs(self.config.accessRules) do
        result, reason = rule(self, action, context)
        if result ~= nil then return result, reason end
    end
end

-- Changes the canAccess method to also return the result of the rule
-- where the rule of a function of (inventory, player, action) -> boolean.
function Inventory:addAccessRule(rule, priority)
    if isnumber(priority) then
        table.insert(self.config.accessRules, priority, rule)
    else
        self.config.accessRules[#self.config.accessRules + 1] = rule
    end

    return self
end

-- Removes the first instance of a specific access rule from the inventory.
function Inventory:removeAccessRule(rule)
    table.RemoveByValue(self.config.accessRules, rule)

    return self
end

-- Returns a list of players who can interact with this inventory.
function Inventory:getRecipients()
    local recipients = {}

    for _, client in ipairs(player.GetAll()) do
        if self:canAccess(INV_REPLICATE, {
            client = client
        }) then
            recipients[#recipients + 1] = client
        end
    end

    return recipients
end

-- Called after this inventory has first been created and loaded.
function Inventory:onInstanced()
end

-- Called after this inventory has first been loaded, not including right
-- after it has been created.
function Inventory:onLoaded()
end

-- Loads the items contained in this inventory.
function Inventory:loadItems()
    local ITEM_TABLE = "items"

    local ITEM_FIELDS = {"_itemID", "_uniqueID", "_data", "_x", "_y", "_quantity"}
    -- Legacy support for x, y data

    return lia.db.select(ITEM_FIELDS, ITEM_TABLE, "_invID = " .. self.id):next(function(res)
        local items = {}

        for _, result in ipairs(res.results or {}) do
            local itemID = tonumber(result._itemID)
            local uniqueID = result._uniqueID
            local itemTable = lia.item.list[uniqueID]

            if not itemTable then
                ErrorNoHalt("Inventory " .. self.id .. " contains invalid item " .. uniqueID .. " (" .. itemID .. ")\n")
                continue
            end

            local item = lia.item.new(uniqueID, itemID)
            item.invID = self.id

            if result._data then
                item.data = table.Merge(item.data, util.JSONToTable(result._data) or {})
            end

            item.data.x = tonumber(result._x)
            item.data.y = tonumber(result._y)
            item.quantity = tonumber(result._quantity)
            items[itemID] = item
            item:onRestored(self)
        end

        self.items = items
        self:onItemsLoaded(items)

        return items
    end)
end

function Inventory:onItemsLoaded(items)
end

function Inventory:instance(initialData)
    return lia.inventory.instance(self.typeID, initialData)
end

function Inventory:syncData(key, recipients)
    if self.config.data[key] and self.config.data[key].noReplication then return end
    net.Start("liaInventoryData")
    -- ID is not always a number.
    net.WriteType(self.id)
    net.WriteString(key)
    net.WriteType(self.data[key])
    net.Send(recipients or self:getRecipients())
end

function Inventory:sync(recipients)
    net.Start("liaInventoryInit")
    -- ID is not always a number.
    net.WriteType(self.id)
    net.WriteString(self.typeID)
    net.WriteTable(self.data)
    local items = {}

    local function writeItem(item)
        items[#items + 1] = {
            i = item:getID(),
            u = item.uniqueID,
            d = item.data,
            q = item:getQuantity()
        }
    end

    for _, item in pairs(self.items) do
        writeItem(item)
    end

    local compressedTable = util.Compress(util.TableToJSON(items))
    net.WriteUInt(#compressedTable, 32)
    net.WriteData(compressedTable, #compressedTable)
    --local currentBytes, currentBits = net.BytesWritten()
    --print("Current net message size: " .. currentBytes .. " bytes (" .. currentBits .. " bits)")
    local res = net.Send(recipients or self:getRecipients())

    for _, item in pairs(self.items) do
        item:onSync(recipients)
    end
end

function Inventory:delete()
    lia.inventory.deleteByID(self.id)
end

function Inventory:destroy()
    for _, item in pairs(self:getItems()) do
        item:destroy()
    end

    lia.inventory.instances[self:getID()] = nil
    net.Start("liaInventoryDelete")
    net.WriteType(id)
    net.Broadcast()
end

-- Given an item type string, creates an instance of that item type
-- and adds it to this inventory. A promise is returned containing
-- the newly created item after it has been added to the inventory.
function Inventory:AddItem(item)
    self.items[item:getID()] = item
    item.invID = self:getID()
    local id = self.id

    if not isnumber(id) then
        id = NULL
    end

    lia.db.updateTable({
        _invID = id
    }, nil, "items", "_itemID = " .. item:getID())

    -- Replicate adding the item to this inventory client-side
    self:syncItemAdded(item)

    return self
end

-- Sample implementation of Inventory:add - delegates to addItem
function Inventory:Add(item)
    return self:addItem(item)
end

function Inventory:SyncItemAdded(item)
    assert(istable(item) and item.getID, "cannot sync non-item")
    assert(self.items[item:getID()], "Item " .. item:getID() .. " does not belong to " .. self.id)
    local recipients = self:getRecipients()
    item:sync(recipients)
    net.Start("liaInventoryAdd")
    net.WriteUInt(item:getID(), 32)
    net.WriteType(self.id)
    net.Send(recipients)
end

-- Called to handle the logic for creating the data storage for this.
-- Returns a promise that is resolved after the storing is done.
function Inventory:InitializeStorage(initialData)
    local d = deferred.new()
    local charID = initialData.char

    lia.db.insertTable({
        _invType = self.typeID,
        _charID = charID
    }, function(results, lastID)
        local count = 0
        local expected = table.Count(initialData)

        -- Ignore the char data since it is stored in the old charID column.
        if initialData.char then
            expected = expected - 1
        end

        if expected == 0 then return d:resolve(lastID) end

        for key, value in pairs(initialData) do
            if key == "char" then continue end

            lia.db.insertTable({
                _invID = lastID,
                _key = key,
                _value = {value}
            }, function()
                count = count + 1

                if count == expected then
                    d:resolve(lastID)
                end
            end, INV_DATA_TABLE_NAME)
        end
    end, INV_TABLE_NAME)

    return d
end

-- Called when some inventory with a certain ID needs to be loaded.
-- If this type is responsible for loading that inventory ID in particular,
-- then a promise that resolves to an inventory should be returned.
-- This allows for custom data storage of inventories.
function Inventory:RestoreFromStorage(id)
end

-- Removes an item corresponding to the given item ID if it is in this
-- inventory. If the item belongs to this inventory, it is then deleted.
-- A promise is returned which is resolved after removal from this.
function Inventory:RemoveItem(itemID, preserveItem)
    assert(isnumber(itemID), "itemID must be a number for remove")
    local d = deferred.new()
    local instance = self.items[itemID]

    if instance then
        instance.invID = 0
        self.items[itemID] = nil
        net.Start("liaInventoryRemove")
        net.WriteUInt(itemID, 32)
        net.WriteType(self:getID())
        net.Send(self:getRecipients())

        if not preserveItem then
            d:resolve(instance:delete())
        else
            lia.db.updateTable({
                _invID = NULL
            }, function()
                d:resolve()
            end, "items", "_itemID = " .. itemID)
        end
    else
        d:resolve()
    end

    return d
end

-- Sample implementation of Inventory:remove() - delegate to removeItem
function Inventory:Remove(itemID)
    return self:removeItem(itemID)
end

-- Stores arbitrary data that can later be looked up using the given key.
function Inventory:SetData(key, value)
    local oldValue = self.data[key]
    self.data[key] = value
    local keyData = self.config.data[key]

    if key == "char" then
        -- Compatibility with NS1.1 inventory
        lia.db.updateTable({
            _charID = value
        }, nil, INV_TABLE_NAME, "_invID = " .. self:getID())
    elseif not keyData or not keyData.notPersistent then
        if value == nil then
            lia.db.delete(INV_DATA_TABLE_NAME, "_invID = " .. self.id .. " AND _key = '" .. lia.db.escape(key) .. "'")
        else
            lia.db.upsert({
                _invID = self.id,
                _key = key,
                _value = {value}
            }, INV_DATA_TABLE_NAME)
        end
    end

    self:syncData(key)
    self:onDataChanged(key, oldValue, value)

    return self
end

-- Whether or not a client can interact with this inventory.
function Inventory:CanAccess(action, context)
    context = context or {}
    local result

    for _, rule in ipairs(self.config.accessRules) do
        result, reason = rule(self, action, context)
        if result ~= nil then return result, reason end
    end
end

-- Changes the canAccess method to also return the result of the rule
-- where the rule of a function of (inventory, player, action) -> boolean.
function Inventory:AddAccessRule(rule, priority)
    if isnumber(priority) then
        table.insert(self.config.accessRules, priority, rule)
    else
        self.config.accessRules[#self.config.accessRules + 1] = rule
    end

    return self
end

-- Removes the first instance of a specific access rule from the inventory.
function Inventory:RemoveAccessRule(rule)
    table.RemoveByValue(self.config.accessRules, rule)

    return self
end

-- Returns a list of players who can interact with this inventory.
function Inventory:GetRecipients()
    local recipients = {}

    for _, client in ipairs(player.GetAll()) do
        if self:canAccess(INV_REPLICATE, {
            client = client
        }) then
            recipients[#recipients + 1] = client
        end
    end

    return recipients
end

-- Called after this inventory has first been created and loaded.
function Inventory:OnInstanced()
end

-- Called after this inventory has first been loaded, not including right
-- after it has been created.
function Inventory:OnLoaded()
end

-- Loads the items contained in this inventory.
function Inventory:LoadItems()
    local ITEM_TABLE = "items"

    local ITEM_FIELDS = {"_itemID", "_uniqueID", "_data", "_x", "_y", "_quantity"}
    -- Legacy support for x, y data

    return lia.db.select(ITEM_FIELDS, ITEM_TABLE, "_invID = " .. self.id):next(function(res)
        local items = {}

        for _, result in ipairs(res.results or {}) do
            local itemID = tonumber(result._itemID)
            local uniqueID = result._uniqueID
            local itemTable = lia.item.list[uniqueID]

            if not itemTable then
                ErrorNoHalt("Inventory " .. self.id .. " contains invalid item " .. uniqueID .. " (" .. itemID .. ")\n")
                continue
            end

            local item = lia.item.new(uniqueID, itemID)
            item.invID = self.id

            if result._data then
                item.data = table.Merge(item.data, util.JSONToTable(result._data) or {})
            end

            item.data.x = tonumber(result._x)
            item.data.y = tonumber(result._y)
            item.quantity = tonumber(result._quantity)
            items[itemID] = item
            item:onRestored(self)
        end

        self.items = items
        self:onItemsLoaded(items)

        return items
    end)
end

function Inventory:OnItemsLoaded(items)
end

function Inventory:Instance(initialData)
    return lia.inventory.instance(self.typeID, initialData)
end

function Inventory:SyncData(key, recipients)
    if self.config.data[key] and self.config.data[key].noReplication then return end
    net.Start("liaInventoryData")
    -- ID is not always a number.
    net.WriteType(self.id)
    net.WriteString(key)
    net.WriteType(self.data[key])
    net.Send(recipients or self:getRecipients())
end

function Inventory:Sync(recipients)
    net.Start("liaInventoryInit")
    -- ID is not always a number.
    net.WriteType(self.id)
    net.WriteString(self.typeID)
    net.WriteTable(self.data)
    local items = {}

    local function writeItem(item)
        items[#items + 1] = {
            i = item:getID(),
            u = item.uniqueID,
            d = item.data,
            q = item:getQuantity()
        }
    end

    for _, item in pairs(self.items) do
        writeItem(item)
    end

    local compressedTable = util.Compress(util.TableToJSON(items))
    net.WriteUInt(#compressedTable, 32)
    net.WriteData(compressedTable, #compressedTable)
    --local currentBytes, currentBits = net.BytesWritten()
    --print("Current net message size: " .. currentBytes .. " bytes (" .. currentBits .. " bits)")
    local res = net.Send(recipients or self:getRecipients())

    for _, item in pairs(self.items) do
        item:onSync(recipients)
    end
end

function Inventory:Delete()
    lia.inventory.deleteByID(self.id)
end

function Inventory:Destroy()
    for _, item in pairs(self:getItems()) do
        item:destroy()
    end

    lia.inventory.instances[self:getID()] = nil
    net.Start("liaInventoryDelete")
    net.WriteType(id)
    net.Broadcast()
end