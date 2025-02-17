-- Modular Kart Class 2 CSP Audio Script
-- Authored by ohyeah2389


local helpers = require("helpers")

local carName = ac.getCarID(0)


-- Create audio events for all 4 tires
local audioEvent_skidLF = ac.AudioEvent("/cars/" .. carName .. "/skid_custom", true, true)
local audioEvent_skidRF = ac.AudioEvent("/cars/" .. carName .. "/skid_custom", true, true)
local audioEvent_skidLR = ac.AudioEvent("/cars/" .. carName .. "/skid_custom", true, true)
local audioEvent_skidRR = ac.AudioEvent("/cars/" .. carName .. "/skid_custom", true, true)

-- Set positions for each tire's audio (adjusted for kart dimensions)
audioEvent_skidLF:setPosition(vec3(0.5, 0.087, 0.466), vec3(0, 1, 0), vec3(1, 0, 0))
audioEvent_skidRF:setPosition(vec3(-0.5, 0.087, 0.466), vec3(0, 1, 0), vec3(1, 0, 0))
audioEvent_skidLR:setPosition(vec3(0.6085, 0.087, -0.584), vec3(0, 1, 0), vec3(1, 0, 0))
audioEvent_skidRR:setPosition(vec3(-0.6085, 0.087, -0.584), vec3(0, 1, 0), vec3(1, 0, 0))

-- Start all audio events
audioEvent_skidLF:start()
audioEvent_skidRF:start()
audioEvent_skidLR:start()
audioEvent_skidRR:start()


---@diagnostic disable-next-line: duplicate-set-field
function script.update()
    ac.boostFrameRate()

    -- Restart any stopped audio events
    if not audioEvent_skidLF:isPlaying() then audioEvent_skidLF:start() end
    if not audioEvent_skidRF:isPlaying() then audioEvent_skidRF:start() end
    if not audioEvent_skidLR:isPlaying() then audioEvent_skidLR:start() end
    if not audioEvent_skidRR:isPlaying() then audioEvent_skidRR:start() end

    -- Update positions (in case the positions need to be dynamic)
    audioEvent_skidLF:setPosition(vec3(0.5, 0.087, 0.466), vec3(0, 1, 0), vec3(1, 0, 0))
    audioEvent_skidRF:setPosition(vec3(-0.5, 0.087, 0.466), vec3(0, 1, 0), vec3(1, 0, 0))
    audioEvent_skidLR:setPosition(vec3(0.5, 0.087, -0.466), vec3(0, 1, 0), vec3(1, 0, 0))
    audioEvent_skidRR:setPosition(vec3(-0.5, 0.087, -0.466), vec3(0, 1, 0), vec3(1, 0, 0))

    -- Set parameters for all tire sounds
    for tireIndex, event in ipairs({audioEvent_skidLF, audioEvent_skidRF, audioEvent_skidLR, audioEvent_skidRR}) do
        local notOnHardSurface = car.wheels[tireIndex - 1].isSpecialSurface or (car.wheels[tireIndex - 1].surfaceType ~= ac.SurfaceType.Default)
        local pitchNoiseSubtractor = 0 --math.abs(math.perlin((sim.time * 0.01) + (tireIndex * 2000), 3)) ^ 0.5
        local relvelPitchNoiseMultiplier = helpers.mapRange(car.wheels[tireIndex - 1].speedDifference, 0, 10, 0, 0.4, true)

        local basePitch = tireIndex < 3 and helpers.mapRange(car.wheels[tireIndex - 1].ndSlip, 0, 4, 0.4, 0.1, true) or helpers.mapRange(car.wheels[tireIndex - 1].ndSlip, 0, 4, 0.3, 0.1, true)
        local baseVolume = helpers.mapRange(car.wheels[tireIndex - 1].ndSlip, 0.01, 1.6, 0, 0.8, true)

        local loadedPitchSubtractor = helpers.mapRange(car.wheels[tireIndex - 1].load, 0, 2000, 0, 0.3, true)
        local loadedVolumeMultiplier = helpers.mapRange(car.wheels[tireIndex - 1].load, 0, 500, 0, 1, true) ^ 0.5
        local loadedDistort = helpers.mapRange(car.wheels[tireIndex - 1].load, 1000, 3000, 0, 1, true)

        local relvelPitchSubtractor = helpers.mapRange(car.wheels[tireIndex - 1].speedDifference, 0, 40, 0, 0.5, true)
        local relvelVolumeMultiplier = helpers.mapRange(car.wheels[tireIndex - 1].speedDifference, 0.1, 0.2, 0.5, 1, true)
        local relvelFocusing = helpers.mapRange(car.wheels[tireIndex - 1].speedDifference, 0, 20, 0, 1, true)
        local relvelDistortAdder = helpers.mapRange(car.wheels[tireIndex - 1].speedDifference, 0, 50, 0, 0.5, true)


        ac.debug(string.format("%d%s noise", 16 + tireIndex, tireIndex == 1 and "LF" or tireIndex == 2 and "RF" or tireIndex == 3 and "LR" or "RR"), pitchNoiseSubtractor)

        event:setParam("pitch", basePitch - loadedPitchSubtractor - relvelPitchSubtractor - (pitchNoiseSubtractor * relvelPitchNoiseMultiplier))
        event:setParam("volume", baseVolume * loadedVolumeMultiplier * relvelVolumeMultiplier * (notOnHardSurface and 0 or 1))
        event:setParam("distort", math.clamp(loadedDistort + relvelDistortAdder, 0, 1))
        event:setParam("focused", relvelFocusing)
    end

    -- Debug output for all tires
    ac.debug("1LF skid playing", audioEvent_skidLF:isPlaying())
    ac.debug("2RF skid playing", audioEvent_skidRF:isPlaying())
    ac.debug("3LR skid playing", audioEvent_skidLR:isPlaying())
    ac.debug("4RR skid playing", audioEvent_skidRR:isPlaying())

    ac.debug("5LF ndSlip", car.wheels[0].ndSlip)
    ac.debug("6RF ndSlip", car.wheels[1].ndSlip)
    ac.debug("7LR ndSlip", car.wheels[2].ndSlip)
    ac.debug("8RR ndSlip", car.wheels[3].ndSlip)

    ac.debug("9LF load", car.wheels[0].load)
    ac.debug("10RF load", car.wheels[1].load)
    ac.debug("11LR load", car.wheels[2].load)
    ac.debug("12RR load", car.wheels[3].load)

    ac.debug("13LF speedDifference", car.wheels[0].speedDifference)
    ac.debug("14RF speedDifference", car.wheels[1].speedDifference)
    ac.debug("15LR speedDifference", car.wheels[2].speedDifference)
    ac.debug("16RR speedDifference", car.wheels[3].speedDifference)
end
