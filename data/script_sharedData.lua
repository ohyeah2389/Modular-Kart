-- Modular Kart Class 2 CSP Physics Script - Shared Data Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local state = require('script_state')


local sharedData = {}


game.sharedData = ac.connect({
    ac.StructItem.key('modkart_c2_shared_' .. car.index),
    cylinderHeadTemp = ac.StructItem.float(),
    exhaustGasTemp = ac.StructItem.float(),
}, true, ac.SharedNamespace.Shared)


function sharedData.update()
    sharedData.cylinderHeadTemp = state.thermal.components.cylinderHead.temp
    sharedData.exhaustGasTemp = math.lerp(state.thermal.components.combustionGas.temp, state.thermal.components.exhaust.temp, 0.5)
end


return sharedData