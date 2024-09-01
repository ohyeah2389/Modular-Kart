-- Modular Kart Class 2 CSP Physics Script - Drivetrain Lockout and Manual Pushing Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')
local physics = require('script_physics')


local drivetrain = {}


function drivetrain.update(dt)
    game.car_cphys.requestedGearIndex = 2

    if game.car_cphys.speedKmh < 10 then
        if game.car_cphys.gearUp then
            ac.addForce(vec3(0, 0.2, 0), true, vec3(0, 0, 700), true)
            ac.overrideBrakesTorque(2, math.nan, math.nan)
            ac.overrideBrakesTorque(3, math.nan, math.nan)
        elseif game.car_cphys.gearDown then
            ac.addForce(vec3(0, 0.2, 0), true, vec3(0, 0, -700), true)
            ac.overrideBrakesTorque(2, math.nan, math.nan)
            ac.overrideBrakesTorque(3, math.nan, math.nan)
        end
    end
end


return drivetrain