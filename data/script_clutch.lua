-- Modular Kart Class 2 CSP Physics Script - Clutch Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')
local physics = require('script_physics')


local clutch = {}


local clutchShoe = physics(1, 0, -5, 5, 0.7, 0.001, 50, 1000)


function clutch.update(dt)
    local clutchShoePos = clutchShoe:step((game.car_cphys.rpm / 60)^2 * clutchShoe.mass * -0.05, dt)

    ac.debug("clutchShoePos", clutchShoePos)
    ac.debug("clutchShoe.force", clutchShoe.force)

    game.car_cphys.clutch = clutchShoe.force / 100
end


return clutch