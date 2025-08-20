-- Minimal boot tasks shared by both sides.

if IsDuplicityVersion() then
  -- lock doors as soon as ox_doorlock is ready, with a short retry window
  local function lockDoors()
    local d = Config.Doors
    if not d then return end
    local ok1, err1 = pcall(function()
      if d.Big and d.Big.doorId then
        exports.ox_doorlock:setDoorState(d.Big.doorId, true)
      end
      if d.Small and d.Small.doorId then
        exports.ox_doorlock:setDoorState(d.Small.doorId, true)
      end
    end)
    if ok1 then
      print("server booted and i just locked the factory doors so we start clean")
    else
      print(("i tried to lock the doors on boot but that blew up because %s"):format(err1 or "unknown"))
    end
  end

  if GetResourceState and GetResourceState("ox_doorlock") == "started" then
    print("ox_doorlock is already up so i am locking the doors right now")
    lockDoors()
  else
    CreateThread(function()
      local tries = 0
      while (not GetResourceState or GetResourceState("ox_doorlock") ~= "started") and tries < 50 do
        Wait(100) 
        tries = tries + 1
      end
      if GetResourceState and GetResourceState("ox_doorlock") == "started" then
        print(("ox_doorlock woke up after %d tries so i am locking the doors now"):format(tries))
      else
        print("i waited a bit for ox_doorlock but i am done waiting i will still try to lock the doors")
      end
      lockDoors()
    end)
  end

  -- also react on resource restart to keep doors sane
  AddEventHandler("onResourceStart", function(res)
    if res == GetCurrentResourceName() then
      print("this resource restarted so i am locking the doors again just to be safe")
      lockDoors()
    end
  end)
else
  -- CLIENT: sync carry state once the player is ready, with event hooks and a small fallback
  local function sync()
    print("player looks ready so i am asking the server to sync my carry state")
    TriggerServerEvent("fjella:carry:sync")
  end

  AddEventHandler("QBCore:Client:OnPlayerLoaded", sync)
  AddEventHandler("Characters:Client:Spawn", sync)

  -- fallback: if none of the framework events fire, try once after session starts
  CreateThread(function()
    local tries = 0
    while not NetworkIsSessionStarted() and tries < 100 do
      Wait(100)
      tries = tries + 1
    end
    -- tiny grace period so ped and state are actually available
    Wait(200)
    sync()
  end)
end
