-- Modular Kart Class 2 CSP Physics Script - Shared Data Module
-- Authored by ohyeah2389


local game = require('script_acConnection')


local sharedData = {}


game.sharedData = ac.connect({
    ac.StructItem.key('modkart_c2_shared_' .. car.index),
    setupWheel = ac.StructItem.int8(),
}, true, ac.SharedNamespace.CarDisplay)


function sharedData.update()
    sharedData.setupWheel = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_2').value

    ac.debug("sharedData.setupWheel", sharedData.setupWheel)

    ac.store('modkart_c2_shared_' .. car.index .. '.wheel', sharedData.setupWheel)
end


return sharedData