-- Modular Kart Class 2 CSP Physics Script - Clutch Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local config = require('script_config')
local state = require('script_state')
local helpers = require('script_helpers')
local physics = require('script_physics')


local clutch = {}


local clutchShoe = physics(1, 0, 0, 10, 0.5, 0.001, 5.5, 10)


function clutch.update(dt)
    local clutchShoePos = clutchShoe:step(game.car_cphys.rpm * -0.01, dt)

    ac.debug("clutchShoePos", clutchShoePos)

    game.car_cphys.clutch = clutchShoePos ^ 4
end


return clutch