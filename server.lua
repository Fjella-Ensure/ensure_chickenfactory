local U = require 'utils'

-- sessions keyed by src
local sessions = {}  
local cooldownUntil = 0

-- guard tracking
local guardNets  = {}        
local guardOwner = {}        
local ownerWatchStarted = false

-- anti-spam for doors (per src)
local doorCooldown = {} 

local function now() return GetGameTimer() end

-- jobs guards should never attack
local EXEMPT_JOBS = { police=true, bcso=true, leo=true, ambulance=true }

-- helperz 

local function setMissionState(src, val)
  local ok, err = pcall(function()
    Player(src).state:set('fj_mission', val and true or false, true)
  end)
  if ok then
    print(('mission flag for player %s is now %s'):format(src, tostring(val)))
  else
    print(('tried to update mission flag for player %s and it failed because %s'):format(src, err or 'unknown reason'))
  end
end

local rl = {}  
local function setMissionState(src, val)
  local ok, err = pcall(function()
    Player(src).state:set('fj_mission', val and true or false, true)
  end)
  if ok then
    print(('mission flag for player %s is now %s'):format(src, tostring(val)))
  else
    print(('tried to update mission flag for player %s and it failed because %s'):format(src, err or 'unknown reason'))
  end
end

local rl = {}  
local function ratelimit(src, key, ms, maxStrikes)
  rl[src] = rl[src] or {}
  if not rl[src][key] then
    rl[src][key] = { last = 0, strikes = 0 }
    print(('starting a fresh rate limit bucket for player %s and key %s'):format(src, tostring(key)))
  end

  local r = rl[src][key]
  local t = GetGameTimer()
  local window = ms or 1000
  local ceil = maxStrikes or 5

  if t - r.last < window then
    r.strikes = r.strikes + 1
    print(('easy there player %s you are spamming %s too fast strike %s of %s'):format(src, tostring(key), r.strikes, ceil))
    if r.strikes >= ceil then
      print(('this is getting silly player %s on %s consider kicking or flagging after this'):format(src, tostring(key)))
    end
    rl[src][key] = r
    return false
  end

  r.last = t
  rl[src][key] = r
  return true
end




local function canStart()
  local players = GetPlayers()
  local total = #players
  local minimum = Config.MinPlayers or 1
  print(('doing a quick headcount. i see %s online. minimum needed is %s'):format(total, minimum))
  if total < minimum then
    print('not enough people around to kick this off')
    return false, 'Not enough players online.'
  end

  local requiredCops = Config.RequirePolice or 0
  if requiredCops > 0 then
    local cops = 0
    for _, id in ipairs(players) do
      if U.getJob(tonumber(id)) == 'police' then cops = cops + 1 end
    end
    print(('police on duty right now is %s and we need %s'):format(cops, requiredCops))
    if cops < requiredCops then
      print('yeah that is not enough police for this mission')
      return false, 'Not enough police on duty.'
    end
  else
    print('no police requirement set for this mission')
  end

  if now() < cooldownUntil then
    local left = math.floor((cooldownUntil - now()) / 1000)
    print(('mission is cooling down. about %s seconds left'):format(left))
    return false, ('Mission on cooldown (%ss left).'):format(left)
  end

  print('all green. mission can start')
  return true
end


local function setPhase(src, p)
  if not sessions[src] then
    print(('tried to set phase for %s but there is no active session'):format(src))
    return
  end
  local before = sessions[src].phase or 0
  sessions[src].phase = p
  print(('player %s phase changed from %s to %s'):format(src, before, p))
end

local function setBox(src, has)
  if not sessions[src] then
    print(('tried to set box state for %s but there is no active session'):format(src))
    return
  end
  local before = sessions[src].hasBox and 'yes' or 'no'
  sessions[src].hasBox = has and true or false
  local after = sessions[src].hasBox and 'yes' or 'no'
  print(('player %s box possession changed from %s to %s'):format(src, before, after))
end

local function setBuyer(src, active, untilTs)
  if not sessions[src] then
    print(('tried to set buyer state for %s but there is no active session'):format(src))
    return
  end
  sessions[src].buyerActive = active and true or false
  sessions[src].buyerEndsAt = untilTs or 0

  if sessions[src].buyerActive then
    local secs = math.max(0, math.floor((sessions[src].buyerEndsAt - now()) / 1000))
    print(('buyer window opened for %s about %s seconds to use it'):format(src, secs))
  else
    print(('buyer window closed for %s'):format(src))
  end
end


local function completeAndCooldown(src)
  local who = GetPlayerName(src) or tostring(src)
  local cdMs = Config.CooldownMs or (60 * 60 * 1000)

  sessions[src] = nil
  print(("mission wrapped up for %s cleaning their session"):format(who))

  cooldownUntil = now() + cdMs
  print(("cooldown started for about %s seconds"):format(math.floor(cdMs / 1000)))

  if Config.Doors.Big and Config.Doors.Big.doorId then
    exports.ox_doorlock:setDoorState(Config.Doors.Big.doorId, true)
    print(("big door relocked id %s"):format(Config.Doors.Big.doorId))
  else
    print("big door was not configured with a valid id")
  end

  if Config.Doors.Small and Config.Doors.Small.doorId then
    exports.ox_doorlock:setDoorState(Config.Doors.Small.doorId, true)
    print(("small door relocked id %s"):format(Config.Doors.Small.doorId))
  else
    print("small door was not configured with a valid id")
  end
end

local function getExemptServerIds()
  local ids = {}
  local found = 0
  for _, id in ipairs(GetPlayers()) do
    local sid = tonumber(id)
    local job = U.getJob(sid)
    if job and EXEMPT_JOBS[string.lower(job)] then
      ids[#ids + 1] = sid
      found = found + 1
      print(("marked %s as exempt job %s"):format(GetPlayerName(sid) or sid, job))
    end
  end
  if found == 0 then
    print("no exempt players found right now")
  else
    print(("exempt list built with %s players"):format(found))
  end
  return ids
end


-- Mission start 
RegisterNetEvent('ensure_chickenfactory:mission:start', function()
  local src = source
  local name = GetPlayerName(src) or ("id " .. tostring(src))
  print(("player %s asked to start the mission"):format(name))

  -- Anti-inject: must be near the mission giver to start
  local mp = Config.MissionPed and Config.MissionPed.coords
  if not (mp and U.within(src, mp, 3.0)) then
    print(("blocking start for %s not at the mission giver"):format(name))
    TriggerClientEvent('ox_lib:notify', src, { description = 'Get to the mission giver to start.', type = 'error' })
    return
  end

  -- Prevent duplicate session for this player
  if sessions[src] then
    print(("player %s tried to start but already has a session"):format(name))
    TriggerClientEvent('ox_lib:notify', src, { description = 'You are already on this mission.', type = 'error' })
    return
  end

  local ok, reason = canStart()
  if not ok then
    print(("mission start denied for %s reason %s"):format(name, reason or "unknown"))
    TriggerClientEvent('ox_lib:notify', src, { description = reason, type = 'error' })
    return
  end

  -- Create session and gate subsequent actions via statebag
  sessions[src] = { phase = 1, hasBox = false, buyerActive = false, buyerEndsAt = 0 }
  setMissionState(src, true)
  print(("session created for %s phase one set"):format(name))

  TriggerClientEvent('ox_lib:notify', src, { description = 'Infiltrate the factory!', type = 'inform' })
  TriggerClientEvent('ensure_chickenfactory:phase1:targets', src)
  print(("sent phase one targets to %s"):format(name))

  -- Silent route: alert exempt services (police BCSO LEO ambulance)
  local sent = 0
  for _, id in ipairs(GetPlayers()) do
    local sid = tonumber(id)
    local job = U.getJob(sid)
    if job and EXEMPT_JOBS[string.lower(job)] then
      TriggerClientEvent('ensure_chickenfactory:pd:alert', sid, Config.Doors.Big.target)
      sent = sent + 1
    end
  end
  print(("silent alert sent to %d responders"):format(sent))

  -- Notify any players who prepaid the snitch
  TriggerEvent('ensure_chickenfactory:mission:notifySnitches')
  print("snitches have been pinged")
end)



-- Doors (server authoritative) 
RegisterNetEvent('ensure_chickenfactory:door:use', function(doorKey)
  local src = source
  local name = GetPlayerName(src) or ("id " .. tostring(src))
  print(("player %s is trying to use the %s door"):format(name, tostring(doorKey)))

  if not ratelimit(src, 'door', 1200, 6) then
    print(("chill %s you are spamming the %s door"):format(name, tostring(doorKey)))
    return
  end

  local sess = sessions[src]
  if not (sess and sess.phase == 1) then
    print(("blocking %s because there is no active phase one session"):format(name))
    return
  end

  -- extra cool down guard
  local last = doorCooldown[src] or 0
  if now() - last < 1500 then
    print(("blocking %s because door use is on cooldown"):format(name))
    return
  end
  doorCooldown[src] = now()

  local cfg = Config.Doors[doorKey]
  if not (cfg and cfg.anim and cfg.anim.pos) then
    print(("bad config for door %s cannot continue"):format(tostring(doorKey)))
    return
  end

  if not U.hasItem(src, cfg.item, 1) then
    print(("player %s is missing item %s for the %s door"):format(name, tostring(cfg.item), tostring(doorKey)))
    TriggerClientEvent('ox_lib:notify', src, { description = ('You need %s.'):format(cfg.item), type='error' })
    return
  end

  if not U.within(src, cfg.anim.pos, 2.5) then
    print(("player %s is too far from the %s door"):format(name, tostring(doorKey)))
    return
  end

  if not U.takeItem(src, cfg.item, 1) then
    print(("inventory remove failed for %s item %s"):format(name, tostring(cfg.item)))
    return
  end

  print(("player %s started planting on the %s door"):format(name, tostring(doorKey)))
  TriggerClientEvent('ensure_chickenfactory:doorFx', src, doorKey, cfg.progressMs or 5000)

  if doorKey == 'Big' and (cfg.pdDispatchDelayMs or 0) > 0 then
    print(("pd ping for big door will go out in %d ms"):format(cfg.pdDispatchDelayMs))
    SetTimeout(cfg.pdDispatchDelayMs, function()
      TriggerEvent('ps-dispatch:server:explosion', {
        coords = cfg.explosion,
        description = 'Explosion reported at the chicken factory!',
        radius = 50.0,
        job = 'police'
      })
      print("pd ping sent for the big door")
    end)
  end

  SetTimeout(cfg.progressMs or 5000, function()
    if doorKey == 'Big' then
      print("planting finished on the big door waiting five seconds before boom")
      SetTimeout(5000, function()
        print("boom time for the big door")
        TriggerClientEvent('ensure_chickenfactory:bigdoor:boom', -1, cfg.explosion)
        SetTimeout(500, function()
          exports.ox_doorlock:setDoorState(cfg.doorId, false)
          setPhase(src, 2)
          print(("big door unlocked phase two started for %s"):format(name))
          TriggerClientEvent('ox_lib:notify', src, { description = 'Breach successful. Find the crate!', type='inform' })
          TriggerEvent('ensure_chickenfactory:phase2:start')
        end)
      end)
    else
      if cfg.burnFx then
        print(("thermite visuals started for the small door by %s"):format(name))
        TriggerClientEvent('ensure_chickenfactory:thermiteFx', -1, cfg.burnFx)
      end
      exports.ox_doorlock:setDoorState(cfg.doorId, false)
      setPhase(src, 2)
      print(("small door unlocked phase two started for %s"):format(name))
      TriggerClientEvent('ox_lib:notify', src, { description = 'Breach successful. Find the crate!', type='inform' })
      TriggerEvent('ensure_chickenfactory:phase2:start')
    end
  end)
end)



-- Guards (server spawns; owner client configures AI)
local function despawnGuards()
  local total = #guardNets
  print(("starting guard cleanup, i see %d guards queued to yeet"):format(total))

  local removed = 0
  for _, netId in ipairs(guardNets) do
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and DoesEntityExist(ent) then
      local owner = NetworkGetEntityOwner(ent)
      local ownerName = owner and owner ~= 0 and (GetPlayerName(owner) or ("id " .. tostring(owner))) or "no owner"
      print(("nuking guard %s (owner %s)"):format(tostring(netId), ownerName))

      DeleteEntity(ent)

      if not DoesEntityExist(ent) then
        removed = removed + 1
        print(("guard %s is gone, nice"):format(tostring(netId)))
      else
        print(("huh guard %s still exists after delete, leaving it for next pass"):format(tostring(netId)))
      end
    else
      print(("skipping %s, entity already missing or invalid"):format(tostring(netId)))
    end
  end

  guardNets = {}
  guardOwner = {}
  print(("guard cleanup done, removed %d out of %d"):format(removed, total))
end


local function spawnGuard(g)
  local pos = g.pos
  local heading = pos.w or 0.0
  print(("ok lets try to spawn a guard %s at %.2f %.2f %.2f h=%.1f"):format(tostring(g.model), pos.x, pos.y, pos.z, heading))

  -- spawn as networked so ownership can move around cleanly
  local ped = CreatePed(4, g.model, pos.x, pos.y, pos.z - 1.0, heading, true, true)
  if not ped or ped == 0 or not DoesEntityExist(ped) then
    print("nah that spawn flopped the ped never showed up")
    return nil
  end

  -- give them something spicy
  local weapon = g.weapon or `WEAPON_SMG`
  GiveWeaponToPed(ped, weapon, 250, false, true)
  print(("armed new guard with %s and a pocket full of bullets"):format(tostring(weapon)))

  -- network hygiene
  local netId = NetworkGetNetworkIdFromEntity(ped)
  if SetNetworkIdExistsOnAllMachines then SetNetworkIdExistsOnAllMachines(netId, true) end
  if SetNetworkIdCanMigrate then SetNetworkIdCanMigrate(netId, true) end

  -- who owns it right now (purely for logs)
  local owner = NetworkGetEntityOwner(ped)
  local ownerName = owner and owner ~= 0 and (GetPlayerName(owner) or ("id " .. tostring(owner))) or "nobody yet"
  print(("guard is up netId=%s currentOwner=%s"):format(tostring(netId), ownerName))

  return netId
end


local function pushGuardSetupToOwner(netId, ai, weapon, exemptIds)
  local netStr = tostring(netId)
  print(("ok, prepping guard %s handoff"):format(netStr))

  local ent = NetworkGetEntityFromNetworkId(netId)
  if not ent or not DoesEntityExist(ent) then
    print(("guard %s has no entity yet, chillin, will try later"):format(netStr))
    return
  end
  if not IsEntityAPed(ent) then
    print(("guard %s points at a non-ped entity somehow, skipping"):format(netStr))
    return
  end

  -- make sure this net id is nice and loud on all clients
  if SetNetworkIdExistsOnAllMachines then
    SetNetworkIdExistsOnAllMachines(netId, true)
  end
  if SetNetworkIdCanMigrate then
    SetNetworkIdCanMigrate(netId, true) -- we still want ownership to be able to move
  end

  local owner = NetworkGetEntityOwner(ent)
  if owner and owner ~= 0 then
    guardOwner[netId] = owner
    local ownerName = GetPlayerName(owner) or ("id " .. tostring(owner))
    print(("handing guard %s to %s, they own it now"):format(netStr, ownerName))

    if SetNetworkIdSyncToPlayer then
      SetNetworkIdSyncToPlayer(netId, owner, true)
      print(("locked net %s sync to %s so it behaves"):format(netStr, ownerName))
    else
      print("net sync lock native not available on this build, rolling without it")
    end

    TriggerClientEvent('ensure_chickenfactory:guard:setup', owner, netId, ai or {}, weapon or 0, exemptIds or {})
    print(("pinged %s to set up their guard %s client-side"):format(ownerName, netStr))
    return
  end

  -- no owner yet, pick the closest player to drive it as a fallback
  local epos = GetEntityCoords(ent)
  local winner, bestDist = nil, 1e9
  for _, id in ipairs(GetPlayers()) do
    id = tonumber(id)
    local pped = GetPlayerPed(id)
    if pped and pped ~= 0 and DoesEntityExist(pped) then
      local d = #(GetEntityCoords(pped) - epos)
      if d < bestDist then
        bestDist = d
        winner = id
      end
    end
  end

  if winner then
    guardOwner[netId] = winner
    local winnerName = GetPlayerName(winner) or ("id " .. tostring(winner))
    if SetNetworkIdSyncToPlayer then
      SetNetworkIdSyncToPlayer(netId, winner, true)
    end
    TriggerClientEvent('ensure_chickenfactory:guard:setup', winner, netId, ai or {}, weapon or 0, exemptIds or {})
    print(("no native owner for guard %s, so i gave it to %s at ~%.1fm away"):format(netStr, winnerName, bestDist))
  else
    print(("no owner for guard %s and nobody around to claim it yet, leaving it for the watcher to retry"):format(netStr))
  end
end





-- spawn wave + hand off per-guard setup to owners
AddEventHandler('ensure_chickenfactory:phase2:start', function()
  print("phase two is starting i am cleaning up any leftover guards")
  despawnGuards()

  local ai = (Config.Guards and Config.Guards.ai) or {}
  local exemptIds = getExemptServerIds()

  local planned = ((Config.Guards and Config.Guards.list) and #Config.Guards.list) or 0
  print(("%d guards are planned for this wave"):format(planned))

  local spawned = 0
  for _, g in ipairs((Config.Guards and Config.Guards.list) or {}) do
    local id = spawnGuard(g)
    if id then
      guardNets[#guardNets+1] = id
      pushGuardSetupToOwner(id, ai, g.weapon, exemptIds)
      spawned = spawned + 1
    else
      print("one guard failed to spawn i am moving on")
    end
  end

  print(("finished spawning i see %d active guards"):format(spawned))

  TriggerClientEvent('ensure_chickenfactory:phase2:crateZone', -1, Config.Crate.coords, Config.Crate.radius, Config.Crate.searchMs)
  print(("told players to show the crate search area at %.2f %.2f %.2f"):format(
    Config.Crate.coords.x, Config.Crate.coords.y, Config.Crate.coords.z))

  SetTimeout(Config.Phase2Timeout or (20 * 60 * 1000), function()
    print("the phase two timer ran out i am calling cleanup now")
    TriggerEvent('ensure_chickenfactory:phase2:cleanup')
  end)

  if not ownerWatchStarted then
    ownerWatchStarted = true
    print("starting the ownership watcher so guards keep their brains when they migrate")
    CreateThread(function()
      while true do
        if #guardNets == 0 then
          Wait(1000)
        else
          local ai2 = (Config.Guards and Config.Guards.ai) or {}
          local exempt2 = getExemptServerIds()
          for i = #guardNets, 1, -1 do
            local netId = guardNets[i]
            local ent   = NetworkGetEntityFromNetworkId(netId)
            if not ent or not DoesEntityExist(ent) then
              print(("i lost the guard with net id %s removing it from the list"):format(tostring(netId)))
              table.remove(guardNets, i)
              guardOwner[netId] = nil
            else
              local owner = NetworkGetEntityOwner(ent)
              if owner and owner ~= 0 and owner ~= guardOwner[netId] then
                local name = GetPlayerName(owner) or ("id " .. tostring(owner))
                print(("guard %s switched owner handing setup to %s"):format(tostring(netId), name))
                guardOwner[netId] = owner
                TriggerClientEvent('ensure_chickenfactory:guard:setup', owner, netId, ai2, 0, exempt2)
              end
            end
          end
          Wait(1000)
        end
      end
    end)
  else
    print("ownership watcher was already running")
  end
end)

AddEventHandler('ensure_chickenfactory:phase2:cleanup', function()
  print("phase two cleanup requested i am removing guards and hiding the crate zone")
  despawnGuards()
  TriggerClientEvent('ensure_chickenfactory:phase2:removeCrateZone', -1)
end)

RegisterNetEvent('ensure_chickenfactory:crate:search', function()
  local src = source
  if not ratelimit(src, 'crate', 800, 8) then
    print(("crate search was spammed by %s i am ignoring this one"):format(GetPlayerName(src) or tostring(src)))
    return
  end

  local name = GetPlayerName(src) or tostring(src)
  print(("%s is trying to search the crate"):format(name))

  local sess = sessions[src]; if not sess or sess.phase ~= 2 then
    print(("%s tried to search the crate but is not in phase two"):format(name))
    return
  end
  if sess.hasBox then
    print(("%s already has the box i am not giving another one"):format(name))
    return
  end
  if not U.within(src, Config.Crate.coords, 2.5) then
    print(("%s is too far from the crate i am not doing anything"):format(name))
    return
  end

  if U.giveItem(src, Config.Crate.item, 1) then
    print(("%s found the box and i gave it to them"):format(name))
    setBox(src, true)
    U.setCarryState(src, true)
    TriggerClientEvent('ox_lib:notify', src, { description = 'You found a box.', type='success' })
    TriggerEvent('ensure_chickenfactory:buyer:start', src)
  else
    print(("%s tried to get the box but the inventory call failed"):format(name))
  end
end)

RegisterNetEvent('ensure_chickenfactory:buyer:start', function(targetSrc)
  local src = targetSrc or source
  local name = GetPlayerName(src) or tostring(src)
  local buyerSessions = {}

  local sess = sessions[src]; if not sess or not sess.hasBox then
    print(("%s tried to open the buyer without a box so i said no"):format(name))
    return
  end
  if sess.buyerActive then
    print(("%s already has a buyer window open"):format(name))
    return
  end

  local ends = now() + (Config.Buyer.windowMs or 300000)
  setBuyer(src, true, ends)
  buyerSessions[src] = true

  print(("%s got a buyer window i will keep it open for a short while"):format(name))
  TriggerClientEvent('ensure_chickenfactory:buyer:spawn', src, Config.Buyer.coords, ends)

  SetTimeout((Config.Buyer.windowMs or 300000) + 150, function()
    local s = sessions[src]
    if s and s.buyerActive then
      print(("%s missed the buyer window so i closed it"):format(name))
      s.buyerActive = false; buyerSessions[src] = nil
      TriggerClientEvent('ensure_chickenfactory:buyer:expire', src)
    end
  end)
end)

RegisterNetEvent('ensure_chickenfactory:buyer:sell', function()
  local src = source
  local name = GetPlayerName(src) or tostring(src)

  if not ratelimit(src, 'buyer', 800, 8) then
    print(("%s is spamming the buyer sell i am ignoring this one"):format(name))
    return
  end

  print(("%s is trying to sell the box"):format(name))

  local sess = sessions[src]; if not (sess and sess.hasBox and sess.buyerActive) then
    print(("%s is not eligible to sell right now so i am stopping here"):format(name))
    return
  end
  if not U.within(src, Config.Buyer.coords, 3.0) then
    print(("%s is not close enough to the buyer"):format(name))
    return
  end
  if not U.takeItem(src, Config.Crate.item, 1) then
    print(("%s tried to sell but the box was not removed from the inventory"):format(name))
    return
  end

  local payout = math.random(Config.Buyer.cashMin or 2500, Config.Buyer.cashMax or 3500)
  U.addCash(src, payout, 'mission-buyer')
  print(("%s sold the box and walked away with %d cash"):format(name, payout))

  setBuyer(src, false, 0)
  setBox(src, false)
  U.setCarryState(src, false)
  buyerSessions[src] = nil

  TriggerClientEvent('ox_lib:notify', src, { description = ('Box sold (+$%d). Move out!'):format(payout), type='success' })

  completeAndCooldown(src)
  print(("%s completed the mission i set the cooldown and started cleanup"):format(name))
  TriggerEvent('ensure_chickenfactory:phase2:cleanup')
end)

RegisterNetEvent('ensure_chickenfactory:snitch:buy', function()
  if not (Config.Snitch and Config.Snitch.enabled) then return end
  local src = source
  local name = GetPlayerName(src) or tostring(src)

  if snitchPaid[src] then
    print(("%s tried to pay the snitch again but they already did"):format(name))
    TriggerClientEvent('ensure_chickenfactory:snitch:status', src, true, 'You already paid the snitch for this mission.')
    return
  end
  local price = Config.Snitch.price or 100
  if not U.removeCash(src, price, 'snitch-info') then
    print(("%s did not have the cash for the snitch"):format(name))
    TriggerClientEvent('ox_lib:notify', src, { description = ('Need $%d.'):format(price), type='error' })
    return
  end
  snitchPaid[src] = true
  print(("%s paid the snitch and will get a heads up when things move"):format(name))
  TriggerClientEvent('ensure_chickenfactory:snitch:status', src, true, 'The snitch will text you if something happens.')
end)

AddEventHandler('ensure_chickenfactory:mission:notifySnitches', function()
  if not (Config.Snitch and Config.Snitch.enabled) then return end
  local count = 0
  for _ in pairs(snitchPaid) do count = count + 1 end
  print(("%d players paid the snitch i am sending out the warning"):format(count))
  for src, _ in pairs(snitchPaid) do
    TriggerClientEvent('ensure_chickenfactory:snitch:notify', src, Config.Snitch.smsText or 'Movement at the factory!')
  end
end)

RegisterNetEvent('ensure_chickenfactory:carry:sync', function()
  local src = source
  local name = GetPlayerName(src) or tostring(src)
  local has = U.hasItem(src, Config.Crate.item, 1)
  print(("%s loaded in i am syncing carry state which is %s"):format(name, has and "true" or "false"))
  if sessions[src] then setBox(src, has) end
  U.setCarryState(src, has)
  if has then
    print(("%s still has the box so i am reopening the buyer window"):format(name))
    TriggerEvent('ensure_chickenfactory:buyer:start', src)
  end
end)

AddEventHandler('playerDropped', function(src)
  local name = GetPlayerName(src) or tostring(src)
  print(("%s left the city i am cleaning up their mission state"):format(name))
  sessions[src] = nil
  buyerSessions[src] = nil
  snitchPaid[src] = nil
end)
