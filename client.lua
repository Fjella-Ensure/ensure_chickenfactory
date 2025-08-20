-- Mission ped (start)
CreateThread(function()
  local p = Config.MissionPed
  if not p then
    print('MissionPed: config missing skipping the start ped.')
    return
  end

  print(('MissionPed: requesting model %s …'):format(p.model))
  lib.requestModel(p.model, 1500)
  if not HasModelLoaded(p.model) then
    print(('MissionPed: model %s did not load in time — bailing.'):format(p.model))
    return
  end

  print(('MissionPed: spawning at (%.2f, %.2f, %.2f), heading %.1f'):format(p.coords.x, p.coords.y, p.coords.z, p.heading or 0.0))
  local ped = CreatePed(4, p.model, p.coords.x, p.coords.y, p.coords.z - 1.0, p.heading or 0.0, false, true)
  if not ped or ped == 0 then
    print('MissionPed: CreatePed returned nil/0 — something went sideways.')
    return
  end

  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  print('MissionPed: ped frozen, invincible, and chill (blocking temp events).')

  local label = p.label or 'Start mission'
  exports.ox_target:addLocalEntity(ped, {{
    icon = 'fas fa-chicken',
    label = label,
    onSelect = function()
      print('MissionPed: player clicked "'..label..'". starting the mission (sending event to server).')
      TriggerServerEvent('fjella:mission:start')
    end
  }})
  print('MissionPed: target registered. ready when you are.')
end)

-- Snitch (optional) 
CreateThread(function()
  local s = Config.Snitch
  if not (s and s.enabled) then
    print('Snitch: disabled in config skipping the gossip guy.')
    return
  end

  print(('Snitch: requesting model %s …'):format(s.model))
  lib.requestModel(s.model, 1500)
  if not HasModelLoaded(s.model) then
    print(('Snitch: model %s did not load skipping.'):format(s.model))
    return
  end

  print(('Snitch: spawning at (%.2f, %.2f, %.2f), heading %.1f'):format(s.coords.x, s.coords.y, s.coords.z, s.heading or 0.0))
  local ped = CreatePed(4, s.model, s.coords.x, s.coords.y, s.coords.z - 1.0, s.heading or 0.0, false, true)
  if not ped or ped == 0 then
    print('Snitch: CreatePed failed no snitch today.')
    return
  end

  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  print('Snitch: ped locked down (frozen/invincible/blocked). pulling out the binoculars…')

  TaskStartScenarioAtPosition(ped, "WORLD_HUMAN_BINOCULARS", s.coords.x, s.coords.y, s.coords.z, s.heading or 0.0, 0, true, false)
  print('Snitch: happily peeping with binoculars.')

  local price = s.price or 100
  local label = s.label or ('Get info $'..price)
  exports.ox_target:addLocalEntity(ped, {{
    icon = 'fa-solid fa-eye',
    label = label,
    onSelect = function()
      print(('Snitch: player wants the tea for $%d. buying info (sending event to server).'):format(price))
      TriggerServerEvent('fjella:snitch:buy')
    end
  }})
  print('Snitch: target registered. ready to spill.')
end)


-- PD alert blip (silent route for 30s)
RegisterNetEvent('fjella:pd:alert', function(coords)
  if not coords then
    print('PD Alert: got no coords nothing to ping')
    return
  end

  local name = Config.PDName or 'Mission'
  print(('PD Alert dropping a ping at (%.2f, %.2f, %.2f) labeled "%s"')
    :format(coords.x or 0.0, coords.y or 0.0, coords.z or 0.0, name))

  local blip = AddBlipForCoord((coords.x or 0.0) + 0.0, (coords.y or 0.0) + 0.0, (coords.z or 0.0) + 0.0)
  if not blip or blip == 0 then
    print('PD Alert: AddBlipForCoord returned 0 — blip refused to exist aborting')
    return
  end

  SetBlipSprite(blip, 161)
  SetBlipScale(blip, 1.2)
  SetBlipColour(blip, 1)
  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(name)
  EndTextCommandSetBlipName(blip)

  SetBlipRoute(blip, true)
  print('PD Alert: blip styled (sprite 161, scale 1.2, color 1) routing for 30 secons')
  Wait(30000)

  RemoveBlip(blip)
  print('PD Alert: timer’s up blip removed hope they got the memo.')
end)


--  Phase 1 show door interaction zones 
RegisterNetEvent('fjella:phase1:targets', function()
  local big = Config.Doors.Big
  local small = Config.Doors.Small

  print('phase one target setup begin')

  if not big or not big.target or not small or not small.target then
    print('door config missing cannot create targets')
    return
  end

  local function r(v) return math.floor((v or 0) + 0.5) end

  local bigZoneId = exports.ox_target:addBoxZone({
    coords = big.target, size = vec3(1.2, 1.2, 1.2), rotation = 0, debug = false,
    options = {{
      icon = 'fas fa-bomb', label = 'Place C4',
      onSelect = function()
        print('player selected place c4 on big door')
        TriggerServerEvent('fjella:door:use', 'Big')
      end
    }}
  })
  print(('big door target ready at x %s y %s z %s size 1 2 zone %s')
    :format(r(big.target.x), r(big.target.y), r(big.target.z), tostring(bigZoneId)))

  local smallZoneId = exports.ox_target:addBoxZone({
    coords = small.target, size = vec3(1.2, 1.2, 1.2), rotation = 0, debug = false,
    options = {{
      icon = 'fas fa-burn', label = 'Use Thermite',
      onSelect = function()
        print('player selected use thermite on small door')
        TriggerServerEvent('fjella:door:use', 'Small')
      end
    }}
  })
  print(('small door target ready at x %s y %s z %s size 1 2 zone %s')
    :format(r(small.target.x), r(small.target.y), r(small.target.z), tostring(smallZoneId)))

  print('phase one target setup done')
end)


-- Door FX / thermite FX 
RegisterNetEvent('fjella:doorFx', function(doorKey, ms)
  local cfg = Config.Doors[doorKey]; if not cfg then return end
  local ped = PlayerPedId()
  SetEntityHeading(ped, (cfg.anim and cfg.anim.heading) or 0.0)

  lib.requestModel(`hei_p_m_bag_var22_arm_s`, 1500)
  lib.requestModel(`hei_prop_heist_thermite`, 1500)
  lib.requestAnimDict("anim@heists@ornate_bank@thermal_charge", 1500)

  local coords = cfg.anim.pos

  -- non-networked props + collision off
  local bag    = CreateObjectNoOffset(`hei_p_m_bag_var22_arm_s`, coords.x, coords.y, coords.z, false, false, true)
  SetEntityCollision(bag, false, true)

  local charge = CreateObjectNoOffset(`hei_prop_heist_thermite`, coords.x, coords.y, coords.z + 0.2, false, false, true)
  SetEntityCollision(charge, false, true)
  AttachEntityToEntity(charge, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)

  local rot = GetEntityRotation(ped) -- vector3, no table.unpack
  local scene = NetworkCreateSynchronisedScene(coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, 2, false, false, 1065353216, 0, 1.3)
  NetworkAddPedToSynchronisedScene(ped, scene, "anim@heists@ornate_bank@thermal_charge", "thermal_charge", 1.5, -4.0, 1, 16, 1148846080, 0)
  NetworkAddEntityToSynchronisedScene(bag, scene, "anim@heists@ornate_bank@thermal_charge", "bag_thermal_charge", 4.0, -8.0, 1)
  NetworkStartSynchronisedScene(scene)

  lib.progressBar({ duration = ms or 5000, label = 'Planting...', canCancel=false, disable={move=true,combat=true,car=true} })

  Wait(250)
  DetachEntity(charge, true, true)
  FreezeEntityPosition(charge, true)       -- keep it still
  -- keep charge collision disabled while it sits on the door
  DeleteObject(bag)
  NetworkStopSynchronisedScene(scene)

  SetTimeout(8000, function()
    if DoesEntityExist(charge) then DeleteEntity(charge) end
  end)
end)


RegisterNetEvent('fjella:thermiteFx', function(pos)
  local function r(v) return math.floor((v or 0) + 0.5) end
  print(('thermite fx start at x %s y %s z %s'):format(r(pos.x), r(pos.y), r(pos.z)))

  RequestNamedPtfxAsset("scr_ornate_heist")
  while not HasNamedPtfxAssetLoaded("scr_ornate_heist") do
    Wait(25)
  end
  print('particle asset ready')

  UseParticleFxAssetNextCall("scr_ornate_heist")
  local fx = StartParticleFxLoopedAtCoord("scr_heist_ornate_thermal_burn", pos.x, pos.y, pos.z, 0.0,0.0,0.0, 1.0, false,false,false)
  SetParticleFxLoopedAlpha(fx, 0.7)
  print('thermite burn effect started')
  Wait(10000)
  StopParticleFxLooped(fx, 0)
  print('thermite burn effect stopped')
end)

RegisterNetEvent('fjella:bigdoor:boom', function(pos)
  if not pos then
    print('big door boom aborted missing position')
    return
  end
  local function r(v) return math.floor((v or 0) + 0.5) end
  print(('big door boom at x %s y %s z %s'):format(r(pos.x), r(pos.y), r(pos.z)))

  AddExplosion(pos.x, pos.y, pos.z, 2, 1.0, true, false, 1.0)
  ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.25)
  print('explosion fired and camera shake applied')
end)


-- Phase 2 crate zone (client target only; server validates)
local GuardPeds = {}     
local BrainRunning = false
local ExemptSet = {}
local _guardRel

local function ensureGuardGroup()
  if _guardRel then
    print('guard relationship group already present')
    return _guardRel
  end
  _guardRel = GetHashKey('MISSION_GUARDS')
  AddRelationshipGroup('MISSION_GUARDS')
  SetRelationshipBetweenGroups(5, _guardRel, GetHashKey('PLAYER'))
  SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), _guardRel)
  print('guard relationship group created and hostility set up')
  return _guardRel
end

local function setExempt(exemptIds)
  ExemptSet = {}
  if type(exemptIds) ~= 'table' then
    print('no exempt ids provided')
    return
  end
  for _, sid in ipairs(exemptIds) do ExemptSet[tonumber(sid)] = true end
  print(('exempt list updated with %s ids'):format(#exemptIds))
end

local function shouldAttackPlayer(serverId)
  if not serverId then return false end
  return not ExemptSet[serverId]
end

-- pooled brain
local function ensureBrain()
  if BrainRunning then return end
  BrainRunning = true
  CreateThread(function()
    while BrainRunning do
      if next(GuardPeds) == nil then
        Wait(1000)
      else
        -- snapshot candidates once
        local players = GetActivePlayers()
        local candidates = {}  -- { {ped=pped, pos=vec3, sid=number} }
        for _, pid in ipairs(players) do
          local sid = GetPlayerServerId(pid)
          if not ExemptSet[sid] then
            local pped = GetPlayerPed(pid)
            if pped and DoesEntityExist(pped) and not IsEntityDead(pped) then
              candidates[#candidates+1] = { ped = pped, pos = GetEntityCoords(pped), sid = sid }
            end
          end
        end

        -- tick all owned guards
        for ped, ai in pairs(GuardPeds) do
          if DoesEntityExist(ped) and not IsEntityDead(ped) then
            if not IsPedInCombat(ped, 0) then
              local alert   = (ai and ai.alertRange) or 60.0
              local myPos   = GetEntityCoords(ped)
              local best, bestDist = nil, alert + 0.001

              for i = 1, #candidates do
                local c    = candidates[i]
                local dist = #(c.pos - myPos)                 -- builtin vector math
                if dist <= alert and HasEntityClearLosToEntity(ped, c.ped, 17) then
                  if dist < bestDist then best, bestDist = c.ped, dist end
                end
              end

              if best then
                ClearPedTasksImmediately(ped)
                TaskCombatPed(ped, best, 0, 16)
                SetPedKeepTask(ped, true)
                TaskCombatHatedTargetsAroundPed(ped, alert, 0)
              else
                TaskGuardCurrentPosition(ped, 15.0, 10.0, true)
                SetPedKeepTask(ped, true)
              end
            end
          else
            GuardPeds[ped] = nil
          end
        end
        Wait(700)
      end
    end
  end)
end


-- Per-guard setup from server (sent only to the net owner)
RegisterNetEvent('fjella:guard:setup', function(netId, ai, weapon, exemptIds)
  print(('guard setup request for net id %s'):format(tostring(netId)))
  setExempt(exemptIds)
  local rel = ensureGuardGroup()
  ai = ai or {}

  CreateThread(function()
    local ped, tries = nil, 0
    while tries < 120 do
      if NetworkDoesEntityExistWithNetworkId(netId) then
        ped = NetToPed(netId)
        if ped ~= 0 and DoesEntityExist(ped) then break end
      end
      if tries == 0 then print('waiting for guard entity to exist on this client') end
      Wait(50); tries = tries + 1
    end
    if not ped or ped == 0 or not DoesEntityExist(ped) then
      print('guard setup failed the entity never showed up here')
      return
    end

    GuardPeds[ped] = ai
    print('guard entity resolved and added to local brain')

    SetPedRelationshipGroupHash(ped, rel)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedAsEnemy(ped, true)
    SetEntityInvincible(ped, false)
    SetPedCanRagdoll(ped, true)
    SetPedCanArmIk(ped, true)
    SetPedCanPlayAmbientAnims(ped, false)
    SetPedCanPlayAmbientBaseAnims(ped, false)

    SetPedArmour(ped, ai.armour or 50)
    SetEntityMaxHealth(ped, ai.health or 200); SetEntityHealth(ped, ai.health or 200)
    SetPedAccuracy(ped, math.max(0, math.min(100, ai.accuracy or 55)))
    SetPedAlertness(ped, 3)
    SetPedHearingRange(ped, ai.alertRange or 60.0)
    SetPedSeeingRange(ped, ai.alertRange or 60.0)

    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatAttributes(ped, 5,  true)
    SetPedCombatAttributes(ped, 20, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedDropsWeaponsWhenDead(ped, false)

    if weapon and weapon ~= 0 then
      GiveWeaponToPed(ped, weapon, 250, false, true)
      print('weapon applied on guard')
    else
      print('weapon was not provided from server skipping give weapon')
    end

    TaskGuardCurrentPosition(ped, 15.0, 10.0, true)
    SetPedKeepTask(ped, true)
    print('guard is holding position and ready')

    ensureBrain()
  end)
end)

-- Retaliate on damage
AddEventHandler('gameEventTriggered', function(name, args)
  if name ~= 'CEventNetworkEntityDamage' then return end
  local victim  = args[1]
  local attacker = args[2]
  if victim and GuardPeds[victim] and attacker and DoesEntityExist(attacker) then
    if IsPedAPlayer(attacker) then
      local idx = NetworkGetPlayerIndexFromPed(attacker)
      if idx ~= -1 then
        local sid = GetPlayerServerId(idx)
        if shouldAttackPlayer(sid) then
          print('guard took damage from a valid player and is fighting back')
          ClearPedTasksImmediately(victim)
          TaskCombatPed(victim, attacker, 0, 16)
          SetPedKeepTask(victim, true)
        else
          print('guard ignored damage because attacker is exempt')
        end
      end
    end
  end
end)

-- Clean up local table if a guard despawns
CreateThread(function()
  while true do
    local removed = 0
    for ped, _ in pairs(GuardPeds) do
      if not DoesEntityExist(ped) then
        GuardPeds[ped] = nil
        removed = removed + 1
      end
    end
    if removed > 0 then
      print(('cleaned up %s missing guards from tracking'):format(removed))
    end
    Wait(2000)
  end
end)

local crateZoneId = nil
RegisterNetEvent('fjella:phase2:crateZone', function(coords, radius, searchMs)
  if crateZoneId then
    exports.ox_target:removeZone(crateZoneId)
    crateZoneId = nil
    print('old crate zone removed so we can place a fresh one')
  end
  crateZoneId = exports.ox_target:addSphereZone({
    coords=coords, radius=radius or 1.2, debug=false,
    options={{ icon='fas fa-search', label='Search crate',
      onSelect=function()
        print('player started searching the crate')
        lib.progressBar({ duration = searchMs or 3000, label = 'Searching...', canCancel=false, disable={move=true,car=true,combat=true} })
        TriggerServerEvent('fjella:crate:search')
        print('crate search finished and server event sent')
      end
    }}
  })
  print('crate zone is now active')
end)

RegisterNetEvent('fjella:phase2:removeCrateZone', function()
  if crateZoneId then
    exports.ox_target:removeZone(crateZoneId)
    crateZoneId=nil
    print('crate zone removed')
  else
    print('crate zone removal requested but there was nothing to remove')
  end
end)

-- Buyer UI (cosmetic ped + target, server is authoritative) 
RegisterNetEvent('fjella:buyer:spawn', function(coords, endsAt)
  print('buyer spawned go sell the goods')
  lib.notify({ title='Buyer', description='Go to buyer, quickly!', type='inform' })
  SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)

  lib.requestModel(Config.Buyer.ped, 1500)
  local ped = CreatePed(4, Config.Buyer.ped, coords.x, coords.y, coords.z - 1.0, 0.0, false, true)
  FreezeEntityPosition(ped, true); SetEntityInvincible(ped, true); SetBlockingOfNonTemporaryEvents(ped, true)

  exports.ox_target:addLocalEntity(ped, {{
    icon='fas fa-dollar-sign', label=Config.Buyer.label or 'Sell',
    onSelect=function()
      print('player is selling the box now')
      lib.progressBar({ label='Selling...', duration=1500, canCancel=false, disable={move=true,car=true,combat=true} })
      TriggerServerEvent('fjella:buyer:sell')
      print('sell request was sent to the server')
    end
  }})

  CreateThread(function()
    while GetGameTimer() < (endsAt or 0) do Wait(250) end
    if DoesEntityExist(ped) then
      DeleteEntity(ped)
      print('buyer left the area')
    end
  end)
end)

RegisterNetEvent('fjella:buyer:expire', function()
  print('buyer window expired that was too slow')
  lib.notify({ title='Buyer', description='Too late. He left.', type='error' })
end)

-- Carry (statebag-driven)
local carrying = false
local boxObj = nil
local ANIM_DICT, ANIM_CLIP, ANIM_FLAG = 'anim@heists@box_carry@', 'idle', 51

local function startCarry()
  if carrying then return end
  carrying = true
  local ped = PlayerPedId()
  lib.requestModel(`hei_prop_heist_box`, 1500)
  lib.requestAnimDict(ANIM_DICT, 1500)

  local p = GetEntityCoords(ped)
  -- non-networked object, dynamic
  boxObj = CreateObjectNoOffset(`hei_prop_heist_box`, p.x, p.y, p.z + 0.2, false, false, true)
  SetEntityCollision(boxObj, false, true)  -- avoid bowling people over / vehicle entry chaos
  AttachEntityToEntity(boxObj, ped, GetPedBoneIndex(ped, 60309),
    0.025, 0.080, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)

  TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 2.0, 2.0, -1, ANIM_FLAG, 0.0, false, false, false)

  CreateThread(function()
    while carrying do
      DisableControlAction(0, 21, true)  -- sprint
      DisableControlAction(0, 36, true)  -- stealth
      Wait(0)
    end
  end)
end


local function stopCarry()
  if not carrying then return end
  carrying = false
  print('stopping carry and removing the box')
  if boxObj and DoesEntityExist(boxObj) then DeleteEntity(boxObj) end
  boxObj = nil
  ClearPedTasks(PlayerPedId())
end

AddStateBagChangeHandler('carryBox', nil, function(bagName, _key, value, _replicated, _rep)
  local ply = GetPlayerFromStateBagName(bagName)
  if ply == 0 or GetPlayerPed(ply) ~= PlayerPedId() then return end
  if value then
    print('state says you are carrying a box now')
    startCarry()
  else
    print('state says you are no longer carrying a box')
    stopCarry()
  end
end)

-- Snitch UI feedback 
RegisterNetEvent('fjella:snitch:status', function(_, message)
  print('snitch status update received')
  lib.notify({ title = Config.Snitch.smsFrom or 'Snitch', description = message or 'OK', type='inform' })
end)

RegisterNetEvent('fjella:snitch:notify', function(message)
  print('snitch sent a heads up')
  lib.notify({ title = Config.Snitch.smsFrom or 'Snitch', description = message or (Config.Snitch.smsText or 'Movement!'), type='warning', duration = 8000 })
end)
