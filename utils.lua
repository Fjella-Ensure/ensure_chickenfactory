local U = {}

local inv = exports.ox_inventory

-- distance helper
function U.within(src, pos, max)
  local ped = GetPlayerPed(src)
  if not ped or ped == 0 then
    print(("i could not find a ped for %s so i am saying they are not here"):format(GetPlayerName(src) or tostring(src)))
    return false
  end
  local p = GetEntityCoords(ped)
  local dist = #(p - pos)
  local need = (max or 3.0)
  if dist > need then
    print(("%s is %.2f away and that is too far i need them within %.2f"):format(GetPlayerName(src) or tostring(src), dist, need))
    return false
  end

  return true
end

-- inventory helpers
function U.hasItem(src, name, count)
  local have = inv:Search(src, 'count', name) or 0
  local need = (count or 1)
  local who = GetPlayerName(src) or tostring(src)
  if have >= need then
    print(("%s has %d of %s which is enough i asked for %d"):format(who, have, tostring(name), need))
    return true
  else
    print(("%s only has %d of %s i wanted %d"):format(who, have, tostring(name), need))
    return false
  end
end

function U.takeItem(src, name, count)
  local ok = inv:RemoveItem(src, name, count or 1)
  local who = GetPlayerName(src) or tostring(src)
  if ok then
    print(("%s handed over %d of %s and i took it"):format(who, count or 1, tostring(name)))
  else
    print(("%s tried to give me %d of %s but it failed"):format(who, count or 1, tostring(name)))
  end
  return ok
end

function U.giveItem(src, name, count, meta)
  local ok = inv:AddItem(src, name, count or 1, meta or {})
  local who = GetPlayerName(src) or tostring(src)
  if ok then
    print(("%s received %d of %s from me"):format(who, count or 1, tostring(name)))
  else
    print(("%s was supposed to get %d of %s but that add failed"):format(who, count or 1, tostring(name)))
  end
  return ok
end

-- money helpers
local function _qb() return exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil end

function U.addCash(src, amount, reason)
  local who = GetPlayerName(src) or tostring(src)
  if exports['qbx_core'] then
    local p = exports['qbx_core']:GetPlayer(src)
    if p then
      local ok = p.Functions.AddMoney('cash', amount, reason or 'mission')
      if ok then
        print(("%s just got %d cash reason %s"):format(who, amount, tostring(reason or 'mission')))
      else
        print(("%s did not get the %d cash something went wrong"):format(who, amount))
      end
      return ok
    end
  end
  local QBCore = _qb()
  if QBCore then
    local p = QBCore.Functions.GetPlayer(src)
    if p then
      local ok = p.Functions.AddMoney('cash', amount, reason or 'mission')
      if ok then
        print(("%s just got %d cash reason %s"):format(who, amount, tostring(reason or 'mission')))
      else
        print(("%s did not get the %d cash something went wrong"):format(who, amount))
      end
      return ok
    end
  end
  print(("%s could not receive %d cash because i could not reach a framework"):format(who, amount))
  return false
end

function U.removeCash(src, amount, reason)
  local who = GetPlayerName(src) or tostring(src)
  if exports['qbx_core'] then
    local p = exports['qbx_core']:GetPlayer(src)
    if p then
      local ok = p.Functions.RemoveMoney('cash', amount, reason or 'mission')
      if ok then
        print(("%s paid %d cash reason %s"):format(who, amount, tostring(reason or 'mission')))
      else
        print(("%s tried to pay %d cash but that removal failed"):format(who, amount))
      end
      return ok
    end
  end
  local QBCore = _qb()
  if QBCore then
    local p = QBCore.Functions.GetPlayer(src)
    if p then
      local ok = p.Functions.RemoveMoney('cash', amount, reason or 'mission')
      if ok then
        print(("%s paid %d cash reason %s"):format(who, amount, tostring(reason or 'mission')))
      else
        print(("%s tried to pay %d cash but that removal failed"):format(who, amount))
      end
      return ok
    end
  end
  print(("%s could not pay %d cash because i could not reach a framework"):format(who, amount))
  return false
end

function U.getJob(src)
  local who = GetPlayerName(src) or tostring(src)
  if exports['qbx_core'] then
    local p = exports['qbx_core']:GetPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name or nil
    print(("%s is on job %s"):format(who, tostring(job or 'unknown')))
    return job
  end
  local QBCore = _qb()
  if QBCore then
    local p = QBCore.Functions.GetPlayer(src)
    local job = p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name or nil
    print(("%s is on job %s"):format(who, tostring(job or 'unknown')))
    return job
  end
  print(("%s asked for job but i do not see a framework"):format(who))
  return nil
end

-- safe statebag set
function U.setCarryState(src, carrying)
  local who = GetPlayerName(src) or tostring(src)
  local ok, err = pcall(function()
    Player(src).state:set('carryBox', carrying and true or false, true)
  end)
  if ok then
    print(("%s carry state is now %s"):format(who, carrying and "true" or "false"))
  else
    print(("%s carry state update failed because %s"):format(who, err or "unknown error"))
  end
end

return U
