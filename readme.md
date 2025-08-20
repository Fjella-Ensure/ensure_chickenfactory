## Updated after feedback  
what changed, and why

You pointed out a few very important pain points that i too be honest had not delved very deep into before, but ever since i got the feedback its been the only thing ive been doing when i havent played RP xD: guards waking up too soon (or not at all), noisy CPU from busy loops, and server events that were a bit too easy to abuse with injectors. I took a machete to the structure and tightened both perf and trust boundaries, this is more or less a remake of the entire system.

**TL;DR;**  
- Split the code cleanly into `server.lua`, `client.lua`, `utils.lua`, and `bootstrap.lua`.  
- Server is the single source of truth for anything valuable or stateful.  
- Client is visuals, local AI driving for *owned* entities, and UI only.  
- Killed 0ms loops, pooled the remaining logic, added rate-limiting + statebag gates to stop injectors and button spam.  
- Guard AI now runs in a pooled “brain” per owner, which drops client CPU a ton while keeping reaction time good.

---

## File layout

### 1) `server.lua`
- Spawns guards and hands them weapons (server side, so they *always* have them).
- Owns mission sessions per player: `phase`, `hasBox`, `buyerActive`, `buyerEndsAt`.
- Controls doors via `ox_doorlock`, crate searches, the buyer window, payouts, cooldowns.
- Sends tiny “do this” messages to the right client(s) instead of trying to render stuff itself.

### 2) `client.lua`
- Spawns cosmetic peds (mission giver, snitch, buyer), plays anims/FX, sets up `ox_target`.
- Drives guard AI **only** for guards this client owns. Ownership can move and this can now handle that.
- Shows PD alert blips and notifications.
- Mirrors carry state locally so it feels smooth.

### 3) `utils.lua`
- Bridges for QBX/QBCore (jobs + money).
- Inventory ops via `ox_inventory`.
- Distance checks and safe statebag setters (carry box etc).

### 4) `bootstrap.lua`
- Startup safety:  
  - Server: locks doors early with a short retry (waits for `ox_doorlock` to be ready instead of sleeping forever).  
  - Client: syncs carry state when the player is actually loaded (hooks several framework events + a small fallback).

---

## Performance changes

**Pooled guard AI (client-side)**  
- No more thread-per-guard. Theres one pooled loop per client that currently owns ≥1 guard.  
- Each tick we snapshot eligible players once, use squared distances (cheap), and a ~700ms tick by default. It’s responsive enough and light.  
- If a guards net owner changes, the server re-pushes setup; the pooled brain keeps running only while there are guards to drive.

**Event-driven everywhere else**  
- Doors, crate, buyer… all event based. No idle loops. Stuff runs when players actually do things.

**Smarter net checks**  
- Before touching network entities on the client we wait for them to exist (`NetworkDoesEntityExistWithNetworkId` -> `NetToPed`), which nukes those “no object by ID” warnings and avoids hot spins.

**Bootstrap with bounded retries**  
- Server locks doors after `ox_doorlock` is up, using short 100ms steps. Robust on restarts without wasting a whole second.

---

## Anti-cheat / injector hardening

**Server-side gating with statebags**  
- When a player starts the mission server sets `Player(src).state.fj_mission = true`.  
- Sensitive events (`door:use`, `crate:search`, `buyer:sell`) validate that state **on the server**. If you didnt start legit, you dont pass.  
- Cleared on completion and on player drop.

**Hard proximity checks**  
- Start near the mission ped, be near the correct door to breach, near the crate to search, near the buyer to sell — all checked serverside with `U.within`. Spoofed client events won’t help.

**Rate limiter per action**  
- `ratelimit(src, key, windowMs, strikes)` wraps the hot handlers:  
  - door: `1200ms`, 6 strikes  
  - crate: `800ms`, 8 strikes  
  - buyer: `800ms`, 8 strikes  
- Spammers get short-circuited, with a server print flagging “kick candidates” for admins, can also add auto drop. 

**Server owns all valuables**  
- Guards spawn + get weapons on the server.  
- Money/items are granted/removed server-side only.  
- Doors open/lock server-side only.  
- Client just asks politely and shows pretty stuff.

**Ownership watcher**  
- If a guards net owner migrates (it happens), server pushes setup to the new owner (and can use `SetNetworkIdSyncToPlayer` when available). Stops weird behavior if a client drops ownership.

---

## Networking notes

- Anywhere a race could happen (guard setup), we explicitly wait for the net entity before configuring.  
- Removed duplicate handlers / double combat calls that caused wake-ups too early or “runaway” aggro.  
- Added prints through startup, spawns, setup, and cleanup so you can follow what’s going on..

---

## What moved where (and why)

- **Guard combat config:** done on the client that owns the ped (becus some of those natives are client-only and you want the lowest latency). The **server** still spawns, arms, and decides who should configure.  
- **Event validation:** critical checks live server-side now. Client still plays FX and says “hey I wanna do X”, but the server decides.  
- **Carry state:** stored server-side in a statebag and mirrored down. Client only binds/unbinds the anim.  
- **Door lock on boot:** sits in `bootstrap.lua` with retries and prints, so restarts don’t leave doors wide open.

---

## Config bits

- All the original config still works.  
- Tweak guard entries, locations, weapons, HP, accuracy, alert range… without having to cavedive through code.  
- PD alerts now go to all “exempt” services (police/BCSO/LEO/ambulance) based on job names from `utils`.

---

## Heads-up for me

- If we crank guard counts way up, consider bumping the pooled brain tick to ~900–1200ms to keep client time low. It will still feel fine in gameplay.

---

## Quick diff of the big wins

- Threads: from “one per guard” to “one pooled brain per owner”.  
- Authority: client is non-authoritative; server owns the important stuff.  
- Races: net entity existence checks before we touch them.  
- Abuse: statebag gate + proximity + ratelimit on all sensitive server events.  
- Startup: short retry bootstrap for door locks; client carry-sync fallback.  
- Debug: human-readable prints everywhere, so we can actually figure out what the heck happened at 3am.

Kinda pro tip to wrap it up: keep an eye on ownership churn (lots of players around, high load). The watcher handles it, but if you see guards go sleepy or over-hyped, bump the watcher interval a hair or log the ownership hops for a sec.

## Old readme
This is a **three-phase Attack & Defense mission** built around the chicken factory in Paleto.  
It was created for a development test to showcase mission flow, server/client synchronization, defender mechanics, and configurability using ox_lib.

The mission is intentionally kept modular and tweakable so new mission locations, guard setups, and entry methods can be added without rewriting core logic.

## Mission Structure
The mission is split into 2 main phases, each with variation options to keep runs fresh:

1. **Infiltration**
   - Choose the front entrance (Thermite) or the back entrance (C4).
   - Animations & effects are server synced for all players.
   
2. **Objective**
   - Once a door is breached, NPC guards spawn inside (server-synced peds).
   - Guard NPC stats (HP, armour, accuracy, weapons, perception range) are tweakable via config.
   - A search zone is created around the loot location – only one player can search it once per mission.

3. **Delivery / Escape**
   - Attacker must carry the loot box out.
   - Movement speed will be reduced to walking so defenders have a fair chance to intercept.
   - Defenders win if time runs out or the loot is recovered.

## Defender Mechanics
Defenders can be:
- Real players: receive a GPS ping when a break-in starts.
- Networked peds: guards or response NPCs spawned by the server.

Defenders can enter from:
- The front entrance
- The back entrance 
- Or same route as the attackers

## Phase Variations
Each run can feel different thanks to:
- Multiple entry methods
- Configurable NPC setups
- Adjustable loot/search location
- Multiple infiltration/objective/delivery point sets with fallback logic

## Technology Stack
- ox_lib – Menus, notifications, progress bars, input, and utility functions.
- ox_doorlock – Breachable doors with synced states.
- QBX / QBCore – Player data, jobs, and money handling, i used qbcore API, instead of QBX since i dont know how you will be testing, and if you will be testing on QBX, it has bridges that help that.
- Server-synced AI peds – Combat settings, armour, health, perception.

## Configuration Highlights
- Guard NPC tuning – HP, armour, accuracy, weapons, patrol behavior.
- Mission points – Infiltration, objective, and delivery points can be set via config (with fallback locations).
- Entry methods – Breach via C4, or thermite
- Search zone control – Radius and one-time-only search rules.
- Mission cooldowns – Prevent spam with adjustable timeout.

## Why No DUI (Yet)?
While a DUI countdown overlay would look amazingly cool:

I delayed implementing it for two reasons:
1. Performance concerns – Early testing showed DUI can cause huge resmon spikes if not optimized correctly, and i dont want to send in a uncompleted DUI.
2. Skill readiness – I want more hands-on practice with DUI rendering before using it in a formal test submission, to ensure it’s done properly.

For now, the breach phases rely on ox_lib progress bars, which are lightweight and resmon-friendly.  
