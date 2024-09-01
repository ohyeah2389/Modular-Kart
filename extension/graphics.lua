-- Modular Kart Class 2 CSP Graphics Script
-- Authored by ohyeah2389


local physObj = class("PhysObj")


function physObj:initialize(posMax, posMin, center, weight, frictionCoef, restCoef, springCoef, forceMax)
    self.posMax = posMax
    self.posMin = posMin
    self.center = center
    self.position = center
    self.speed = 0
    self.force = 0
    self.accel = 0
    self.restCoef = restCoef
    self.frictionCoef = frictionCoef
    self.friction = self.speed * self.frictionCoef
    self.mass = weight
    self.springCoef = springCoef
    self.forceMax = forceMax
end


function physObj:step(force, dt)
    local distanceFromCenter = self.position - self.center
    self.force = math.clamp(-force * self.mass, -self.forceMax, self.forceMax) + (distanceFromCenter * -self.springCoef)
    self.position = self.position + (self.speed * dt)
    if self.position > self.posMax then
        self.position = self.posMax
        self.speed = -self.speed * self.restCoef
    elseif self.position < self.posMin then
        self.position = self.posMin
        self.speed = -self.speed * self.restCoef
    end
    self.accel = self.force / self.mass
    self.speed = self.speed + self.accel
    self.friction = self.speed * self.frictionCoef
    self.speed = self.speed - self.friction

    return self.position
end


local driverBodyPhys_lat = physObj(1, 0, 0.5, 4, 0.3, 0.2, 20, 20)
local driverBodyPhys_vert = physObj(1, 0, 0.5, 5, 0.25, 0.8, 20, 10)


---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
    ac.boostFrameRate()

    local debugAddition = (math.sin(os.clock() * 2.0) + 0.5) * 0.1

    ac.updateDriverModel()
    --ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/carb.ksanim", animTest) -- needs proper easing instead of snapping to value
    --if animTest == 0 then ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/steer.ksanim", (car.steer / -720) + 0.5) end
    ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/brake.ksanim", 1 - car.brake)
    ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/throttle.ksanim", 1 - car.gas)
    ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/latG.ksanim", driverBodyPhys_lat:step(car.acceleration.x, dt))
    ac.findNodes("DRIVER:DRIVER"):setAnimation("../animations/vertG.ksanim", driverBodyPhys_vert:step(-car.acceleration.y + debugAddition, dt))

    --local test = ac.findNodes("Steering_Shaft"):setOrientation(vec3(0, 0, 1)):getPosition()
    --local test2 = test + ac.findNodes("Circle"):getPosition()

    --ac.debug("location test", test)
    --ac.debug("location test2", test2)
end