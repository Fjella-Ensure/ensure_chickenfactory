# QBX Attack & Defense Mission – Paleto Chicken Factory

## What this is  
This is a **three-phase Attack & Defense mission** designed around the chicken factory in Paleto.  
It was built as a showcase resource for QBX/QBCore servers, focusing on mission flow, synchronized NPC guards, and configurable scenarios using `ox_lib`.

The mission is modular — you can adjust guard setups, entry methods, loot points, and difficulty without touching the core logic.  

I made a small ymap for this, just to have doors to play with, it looks horrible, fix it if you want.

## Support me on Ko-Fi
https://ko-fi.com/fjellaa
---

## Why I made it  
When I first built this mission, my main goal was to practice creating synced missions for QBX.  
After receiving feedback, I realized two big priorities:  

1. **Performance** – missions should never melt client CPUs or spam threads unnecessarily.  
2. **Security** – server events and rewards must not be easy targets for injectors or button spam.  

This update is essentially a full remake of the system to achieve those goals.  

---

## Why it’s safe (security)  
- **Server owns all valuables** – guards, weapons, payouts, and doors are controlled only by the server.  
- **Event hardening** – sensitive actions (doors, crates, payouts) are server-gated with state checks, proximity checks, and rate limits.  
- **Anti-abuse** – button spam and spoofed events are blocked by ratelimits and statebag validation.  
- **Ownership handling** – if a guard’s net owner changes, the server reassigns setup cleanly.  

---

## Why it’s performant  
- **No idle loops** – replaced busy 0ms loops with pooled AI and event-driven logic.  
- **Guard AI pooling** – instead of one thread per guard, clients only run a single “brain” loop if they own guards.  
- **Lightweight checks** – squared distances, ~700ms ticks, and only when guards exist.  
- **Smarter bootstrapping** – retries are bounded and fast, avoiding wasted CPU during restarts.  

---

## Looking for feedback  
This is a big step forward for me in both performance and security, but I know there’s more room for improvement.  
If you test this mission and have ideas on how to make it even safer or lighter on performance, I’d love to hear them.  

---
