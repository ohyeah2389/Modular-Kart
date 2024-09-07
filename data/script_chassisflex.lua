-- Modular Kart Class 2 CSP Physics Script - Chassis Flex Controller
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')


local chassisFlex = {}


function chassisFlex.update(dt)
    local chassisTwistStiffnessSetupValue = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_0').value
    local chassisBendStiffnessSetupValue = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_1').value
    
    chassisFlex.chassisTwistStiffness = chassisTwistStiffnessSetupValue + chassisBendStiffnessSetupValue * 0.15
    chassisFlex.chassisBendStiffness = chassisBendStiffnessSetupValue + chassisTwistStiffnessSetupValue * 0.8

    ac.debug('chassisTwistStiffnessSetupValue', chassisTwistStiffnessSetupValue)
    ac.debug('chassisBendStiffnessSetupValue', chassisBendStiffnessSetupValue)
    ac.debug('chassisTwistStiffness', chassisFlex.chassisTwistStiffness)
    ac.debug('chassisBendStiffness', chassisFlex.chassisBendStiffness)

    game.car_cphys.controllerInputs[0] = chassisFlex.chassisTwistStiffness
    game.car_cphys.controllerInputs[1] = chassisFlex.chassisBendStiffness
end


return chassisFlex