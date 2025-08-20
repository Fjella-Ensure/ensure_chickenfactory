fx_version 'cerulean'
game 'gta5'

author 'Fjella'
description 'Chicken Heist Mission'
version '1.0.0'

lua54 'yes'

shared_scripts { 
    '@ox_lib/init.lua', 
    'config.lua', 
    'utils.lua' 
}

client_scripts { 
'bootstrap.lua', 
'client.lua' 
}
server_scripts { 
    '@oxmysql/lib/MySQL.lua', 
    'bootstrap.lua', 
    'server.lua' 
}




dependencies {
    'ox_inventory',
    'ox_target',
    'ox_doorlock',
    'ps-dispatch'
}

escrow_ignore {
    'client.lua',
    'server.lua',
    'config.lua',
    'utils.lua',
    'bootstrap.lua'
}
