-- Modular Kart Class 2 CSP Audio Script
-- Authored by ohyeah2389

local audioEvent_engine = ac.AudioEvent("/cars/ohyeah2389_modkart_class2/engine_custom", true, true)
audioEvent_engine:setPosition(vec3(-0.213, 0.24, -0.588), vec3(0, 0, -1), vec3(0, 1, 0))

audioEvent_engine:start()

---@diagnostic disable-next-line: duplicate-set-field
function script.update()
    ac.debug("engine playing", audioEvent_engine:isPlaying())
    if not audioEvent_engine:isPlaying() then
        audioEvent_engine:start()
    end
    audioEvent_engine:setPosition(vec3(-0.213, 0.24, -0.588), vec3(0, 0, -1), vec3(0, 1, 0))
    audioEvent_engine:setParam("rpms", car.rpm)
    audioEvent_engine:setParam("throttle", car.gas)    
end
