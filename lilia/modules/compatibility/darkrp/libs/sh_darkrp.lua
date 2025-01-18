﻿DarkRP = DarkRP or {}
RPExtraTeams = RPExtraTeams or {}
lia.darkrp = lia.darkrp or {}
if SERVER then
  function lia.darkrp.isEmpty(position, entitiesToIgnore)
    entitiesToIgnore = entitiesToIgnore or {}
    local contents = util.PointContents(position)
    local isClear = contents ~= CONTENTS_SOLID and contents ~= CONTENTS_MOVEABLE and contents ~= CONTENTS_LADDER and contents ~= CONTENTS_PLAYERCLIP and contents ~= CONTENTS_MONSTERCLIP
    if not isClear then return false end
    local isEmpty = true
    for _, entity in ipairs(ents.FindInSphere(position, 35)) do
      if (entity:IsNPC() or entity:IsPlayer() or entity:isProp() or entity.NotEmptyPos) and not table.HasValue(entitiesToIgnore, entity) then
        isEmpty = false
        break
      end
    end
    return isClear and isEmpty
  end

  function lia.darkrp.findEmptyPos(startPos, entitiesToIgnore, maxDistance, searchStep, checkArea)
    if lia.darkrp.isEmpty(startPos, entitiesToIgnore) and lia.darkrp.isEmpty(startPos + checkArea, entitiesToIgnore) then return startPos end
    for distance = searchStep, maxDistance, searchStep do
      for direction = -1, 1, 2 do
        local offset = distance * direction
        if lia.darkrp.isEmpty(startPos + Vector(offset, 0, 0), entitiesToIgnore) and lia.darkrp.isEmpty(startPos + Vector(offset, 0, 0) + checkArea, entitiesToIgnore) then return startPos + Vector(offset, 0, 0) end
        if lia.darkrp.isEmpty(startPos + Vector(0, offset, 0), entitiesToIgnore) and lia.darkrp.isEmpty(startPos + Vector(0, offset, 0) + checkArea, entitiesToIgnore) then return startPos + Vector(0, offset, 0) end
        if lia.darkrp.isEmpty(startPos + Vector(0, 0, offset), entitiesToIgnore) and lia.darkrp.isEmpty(startPos + Vector(0, 0, offset) + checkArea, entitiesToIgnore) then return startPos + Vector(0, 0, offset) end
      end
    end
    return startPos
  end

  function lia.darkrp.notify(client, _, _, message)
    client:notify(message)
  end
else
  function lia.darkrp.textWrap(text, fontName, maxLineWidth)
    local function wrapCharacters(text, remainingWidth, maxWidth)
      local accumulatedWidth = 0
      text = text:gsub(".", function(char)
        accumulatedWidth = accumulatedWidth + surface.GetTextSize(char)
        if accumulatedWidth >= remainingWidth then
          accumulatedWidth = surface.GetTextSize(char)
          remainingWidth = maxWidth
          return "\n" .. char
        end
        return char
      end)
      return text, accumulatedWidth
    end

    local accumulatedWidth = 0
    surface.SetFont(fontName)
    local spaceWidth = surface.GetTextSize(' ')
    text = text:gsub("(%s?[%S]+)", function(word)
      local firstChar = string.sub(word, 1, 1)
      if firstChar == "\n" or firstChar == "\t" then accumulatedWidth = 0 end
      local wordWidth = surface.GetTextSize(word)
      accumulatedWidth = accumulatedWidth + wordWidth
      if wordWidth >= maxLineWidth then
        local wrappedWord, finalWidth = wrapCharacters(word, maxLineWidth - (accumulatedWidth - wordWidth), maxLineWidth)
        accumulatedWidth = finalWidth
        return wrappedWord
      elseif accumulatedWidth < maxLineWidth then
        return word
      end

      if firstChar == ' ' then
        accumulatedWidth = wordWidth - spaceWidth
        return '\n' .. string.sub(word, 2)
      end

      accumulatedWidth = wordWidth
      return '\n' .. word
    end)
    return text
  end
end

for index, faction in ipairs(lia.faction.indices) do
  RPExtraTeams[index] = faction
  RPExtraTeams[index].team = index
end

function lia.darkrp.formatMoney(amount)
  return lia.currency.get(amount)
end

DarkRP.formatMoney = lia.darkrp.formatMoney
DarkRP.isEmpty = lia.darkrp.isEmpty
DarkRP.findEmptyPos = lia.darkrp.findEmptyPos
DarkRP.notify = lia.darkrp.notify
DarkRP.textWrap = lia.darkrp.textWrap
