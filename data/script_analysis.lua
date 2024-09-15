-- Modular Kart Class 2 CSP Physics Script - Analysis Module
-- Authored by ohyeah2389


local game = require('script_acConnection')
local helpers = require('script_helpers')


local analysis = {}

analysis.data = {}

function analysis.prepare()
    analysis.data.weightDist = 0.43 -- percent front
    analysis.data.cgHeight = (ac.INIConfig.load("suspensions.ini"):get("FRONT", "BASEY", 1) + ac.INIConfig.load("suspensions.ini"):get("REAR", "BASEY", 1)) / 2 -- m
    analysis.data.tireRadius = (ac.INIConfig.load("tyres.ini"):get("FRONT", "RADIUS", 1) + ac.INIConfig.load("tyres.ini"):get("REAR", "RADIUS", 1)) / 2 -- m
    analysis.data.wheelbase = ac.INIConfig.load("suspensions.ini"):get("BASIC", "WHEELBASE", 1) -- m
    analysis.data.trackWidth = {}
    analysis.data.trackWidth.front = ac.INIConfig.load("suspensions.ini"):get("FRONT", "TRACK", 1) -- m
    analysis.data.trackWidth.rear = ac.INIConfig.load("suspensions.ini"):get("REAR", "TRACK", 1) -- m
    analysis.data.mass = ac.INIConfig.load("car.ini"):get("BASIC", "TOTALMASS", 1) -- kg
end


function analysis.update(dt)
    local longLoadTransfer = (analysis.data.mass * game.car_cphys.gForces.z * analysis.data.cgHeight) / analysis.data.wheelbase
    local latLoadTransfer_front = (analysis.data.mass * game.car_cphys.gForces.x * analysis.data.cgHeight * analysis.data.weightDist) / analysis.data.trackWidth.front
    local latLoadTransfer_rear = (analysis.data.mass * game.car_cphys.gForces.x * analysis.data.cgHeight * (1 - analysis.data.weightDist)) / analysis.data.trackWidth.rear

    local frontLeftStatic = analysis.data.mass * analysis.data.weightDist * 0.5
    local rearLeftStatic = analysis.data.mass * (1 - analysis.data.weightDist) * 0.5

    local frontLeftDynamic = frontLeftStatic - latLoadTransfer_front
    local rearLeftDynamic = rearLeftStatic - latLoadTransfer_rear

    local leftSideLoad = frontLeftDynamic + rearLeftDynamic
    local totalLoad = game.car_cphys.wheels[0].load + game.car_cphys.wheels[1].load + game.car_cphys.wheels[2].load + game.car_cphys.wheels[3].load

    local percentLeftLoad = (leftSideLoad / totalLoad) * 100

    ac.debug("longLoadTransfer", longLoadTransfer)
    ac.debug("latLoadTransfer_front", latLoadTransfer_front)
    ac.debug("latLoadTransfer_rear", latLoadTransfer_rear)
    ac.debug("leftSideLoad", leftSideLoad)
    ac.debug("totalLoad", totalLoad)
    ac.debug("percentLeftLoad", percentLeftLoad)
end


return analysis