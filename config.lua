Config = {}

-- Mission start NPC
Config.MissionPed = {
  model   = `a_m_m_farmer_01`,
  coords  = vec3(-133.65, 6150.21, 31.56),
  heading = 0.0,
  label   = 'Start mission',
}

-- Doors & breach specifics
Config.Doors = {
  Big = {
    doorId     = 1227, 
    target     = vec3(-138.64, 6147.55, 32.78),
    anim       = { pos = vec3(-138.60, 6147.36, 32.44), heading = 44.22 },
    explosion  = vec3(-139.11, 6146.30, 32.44),
    item       = 'c4',
    progressMs = 5000,
    pdDispatchDelayMs = 4500, -- extra explosion alert to PD
  },
  Small = {
    doorId     = 1228 ,
    target     = vec3(-68.86, 6267.75, 31.12),
    anim       = { pos = vec3(-68.86, 6267.75, 31.12), heading = 212.09 },
    burnFx     = vec3(-69.13, 6267.91, 31.14),
    item       = 'thermite',
    progressMs = 5000,
  }
}

-- Crate search 
Config.Crate = {
  coords       = vec3(-86.57, 6212.91, 30.18),
  radius       = 1.2,
  item         = 'box',
  searchMs     = 3000,
}

-- Buyer
Config.Buyer = {
  coords   = vec3(1515.91, 6333.32, 24.11),
  ped      = `cs_martinmadrazo`,
  label    = 'Sell the box',
  cashMin  = 2500,
  cashMax  = 3500,
  windowMs = 5 * 60 * 1000,
  exitPos  = vec4(1606.92, 6483.73, 21.44, 7.49), 
}

-- Snitch (optional alerts)
Config.Snitch = {
  enabled = true,
  model   = `csb_reporter`,
  coords  = vec3(-82.39, 6315.54, 31.30),
  heading = 201.68,
  price   = 100, 
  smsFrom = 'Snitch',
  smsText = 'Yo! There is some crazy movement over at the chicken factory right now!',
  label   = 'Get info $100',
}

-- Server-spawned guard AI (OneSync streams by proximity)
Config.Guards = {
  ai = { accuracy = 55, armour = 50, health = 200, alertRange = 60.0 },
  list = {
 { model = `s_m_m_security_01`, pos = vec4(-140.83, 6156.47, 31.21, 50.86), weapon = `WEAPON_CARBINERIFLE` },
    { model = `s_m_m_security_01`, pos = vec4(-146.13, 6163.55, 31.21, 140.05), weapon = `WEAPON_PUMPSHOTGUN` },
    { model = `s_m_m_armoured_02`, pos = vec4(-168.21, 6172.76, 31.21, 187.46),  weapon = `WEAPON_SMG` },
    { model = `s_m_y_marine_01`,   pos = vec4(-73.82, 6254.07, 31.07, 343.66), weapon = `WEAPON_CARBINERIFLE` },
    { model = `s_m_m_armoured_02`, pos = vec4(-73.93, 6240.08, 31.08, 289.65),  weapon = `WEAPON_SMG` },
    { model = `s_m_m_armoured_02`, pos = vec4(-73.59, 6237.96, 31.08, 259.52),  weapon = `WEAPON_SMG` },
    { model = `s_m_m_armoured_02`, pos = vec4(-64.9, 6236.13, 31.09, 7.94),  weapon = `WEAPON_HEAVYPISTOL` },
    { model = `s_m_m_armoured_02`, pos = vec4(-75.53, 6226.1, 31.09, 125.91),  weapon = `WEAPON_SMG` },
    { model = `s_m_m_armoured_02`, pos = vec4(-85.08, 6214.01, 31.09, 331.35),  weapon = `WEAPON_SMG` },
    { model = `s_m_m_armoured_02`, pos = vec4(-89.83, 6211.76, 31.06, 53.51),  weapon = `WEAPON_SMG` },
    { model = `s_m_m_armoured_02`, pos = vec4(-96.86, 6210.37, 31.03, 136.71),  weapon = `WEAPON_PISTOL` },
    { model = `s_m_m_armoured_02`, pos = vec4(-101.11, 6216.03, 31.02, 158.21),  weapon = `WEAPON_PUMPSHOTGUN` },
    { model = `s_m_m_armoured_02`, pos = vec4(-108.62, 6197.63, 31.03, 305.69),  weapon = `WEAPON_PISTOL` },
    { model = `s_m_m_armoured_02`, pos = vec4(-112.22, 6200.43, 31.03, 248.39),  weapon = `WEAPON_SMG` },
    { model = `s_m_m_armoured_02`, pos = vec4(-102.2, 6195.0, 31.03, 134.87),  weapon = `WEAPON_SMG` },
    { model = `s_m_m_armoured_02`, pos = vec4(-110.98, 6181.29, 31.02, 124.59),  weapon = `WEAPON_PISTOL` },
    { model = `s_m_m_armoured_02`, pos = vec4(-120.69, 6176.45, 31.02, 143.52),  weapon = `WEAPON_CARBINERIFLE` },
    { model = `s_m_m_armoured_02`, pos = vec4(-128.94, 6162.49, 31.02, 120.19),  weapon = `WEAPON_SMG` },
  }
}

-- Global rules
Config.CooldownMs     = 60 * 60 * 1000  -- 60 minutes mission cooldown per-start
Config.Phase2Timeout  = 20 * 60 * 1000  -- auto-clean guards/search after 20 minutes
Config.MinPlayers     = 1               -- minimum players required
Config.RequirePolice  = 0               -- minimum police required to start

-- PD alert label
Config.PDName = 'Chicken factory'
