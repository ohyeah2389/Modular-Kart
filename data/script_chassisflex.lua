-- Modular Kart Class 2 CSP Physics Script - Chassis Flex Controller
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')


local chassisFlex = {}


local blendTime = 5
local blendDelay = 1
local blendStartStiffness = 5


function chassisFlex.update(dt)
    local chassisTwistStiffnessSetupValue = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_0').value
    local chassisBendStiffnessSetupValue = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_1').value

    local startBlend = helpers.mapRange(game.sim.timeToSessionStart / -1000, blendDelay, blendTime, 0, 1)

    chassisFlex.chassisTwistStiffness = chassisTwistStiffnessSetupValue + ((chassisBendStiffnessSetupValue - 1300) * 0.2)
    chassisFlex.chassisBendStiffness = chassisBendStiffnessSetupValue + ((chassisTwistStiffnessSetupValue - 3600) * 0.1)

    ac.debug('chassisTwistStiffnessSetupValue', chassisTwistStiffnessSetupValue)
    ac.debug('chassisBendStiffnessSetupValue', chassisBendStiffnessSetupValue)
    ac.debug('chassisTwistStiffness', chassisFlex.chassisTwistStiffness)
    ac.debug('chassisBendStiffness', chassisFlex.chassisBendStiffness)
    ac.debug('startBlend', startBlend)

    game.car_cphys.controllerInputs[0] = helpers.mapRange(startBlend, 0, 1, blendStartStiffness, chassisFlex.chassisTwistStiffness)
    game.car_cphys.controllerInputs[1] = helpers.mapRange(startBlend, 0, 1, blendStartStiffness, chassisFlex.chassisBendStiffness)
end


return chassisFlex