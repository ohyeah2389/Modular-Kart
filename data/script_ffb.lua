-- Modular Kart Class 2 CSP Physics Script - FFB Adjustment Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')


local ffb = {}

-- it might be better to also add a gamma effect here to keep the small forces at these speeds but to still clamp or smoothly reduce the max forces to cut back on the oscillation
function ffb.update(dt)
    local ffbMultiplier = 1
    if game.car_cphys.speedKmh > config.misc.ffbCorrection.minSpeed and game.car_cphys.speedKmh < config.misc.ffbCorrection.maxSpeed then
        local slowFadeout = helpers.mapRange(game.car_cphys.speedKmh, config.misc.ffbCorrection.minSpeed, config.misc.ffbCorrection.minSpeed + config.misc.ffbCorrection.fadeoutSpeed, 1, config.misc.ffbCorrection.minMultiplier, true)
        local fastFadeout = helpers.mapRange(game.car_cphys.speedKmh, config.misc.ffbCorrection.maxSpeed - config.misc.ffbCorrection.fadeoutSpeed, config.misc.ffbCorrection.maxSpeed, config.misc.ffbCorrection.minMultiplier, 1, true)
        ffbMultiplier = math.max(slowFadeout, fastFadeout)
    end
    ac.setSteeringFFB(game.car_cphys.ffb * ffbMultiplier)
    ac.debug('ffbMultiplier', ffbMultiplier)
end


return ffb
