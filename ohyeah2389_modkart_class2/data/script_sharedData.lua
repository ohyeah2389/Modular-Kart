-- Modular Kart Class 2 CSP Physics Script - Shared Data Module
-- Authored by ohyeah2389


local game = require('script_acConnection')


local sharedData = {}


game.sharedData = ac.connect({
    ac.StructItem.key('modkart_c2_shared_' .. car.index),
    setupWheel = ac.StructItem.int8(),
    setupNassau = ac.StructItem.int8(),
}, true, ac.SharedNamespace.CarDisplay)



function sharedData.update()
    sharedData.setupWheel = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_2').value
    sharedData.setupNassau = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_3').value
    sharedData.setupFrontBumper = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_4').value
    sharedData.setupSidepod = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_5').value
    sharedData.setupRearBumper = ac.getScriptSetupValue('CUSTOM_SCRIPT_ITEM_6').value

    ac.debug("sharedData.setupWheel", sharedData.setupWheel)
    ac.debug("sharedData.setupNassau", sharedData.setupNassau)
    ac.debug("sharedData.setupFrontBumper", sharedData.setupFrontBumper)
    ac.debug("sharedData.setupSidepod", sharedData.setupSidepod)
    ac.debug("sharedData.setupRearBumper", sharedData.setupRearBumper)

    ac.store('modkart_c2_shared_' .. car.index .. '.wheel', sharedData.setupWheel)
    ac.store('modkart_c2_shared_' .. car.index .. '.nassau', sharedData.setupNassau)
    ac.store('modkart_c2_shared_' .. car.index .. '.frontBumper', sharedData.setupFrontBumper)
    ac.store('modkart_c2_shared_' .. car.index .. '.sidepod', sharedData.setupSidepod)
    ac.store('modkart_c2_shared_' .. car.index .. '.rearBumper', sharedData.setupRearBumper)
end





return sharedData