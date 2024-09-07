-- Modular Kart Class 2 CSP Physics Script - FFB Adjustment Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')


local ffb = {}

-- it might be better to also add a gamma effect here to keep the small forces at these speeds but to still clamp or smoothly reduce the max forces to cut back on the oscillation
function ffb.update(dt)
    if game.car_cphys.speedKmh > 10 and game.car_cphys.speedKmh < 20 then
        local t = math.max(0, math.min(1, (game.car_cphys.speedKmh - config.misc.ffbCorrection.minSpeed) / (config.misc.ffbCorrection.maxSpeed - config.misc.ffbCorrection.minSpeed)))
        local ffbMultiplier = math.max(config.misc.ffbCorrection.minMultiplier, math.min(1, config.misc.ffbCorrection.minMultiplier + (1 - config.misc.ffbCorrection.minMultiplier) * t))
        ac.setSteeringFFB(game.car_cphys.ffb * ffbMultiplier)
    end
end


return ffb
