-- Modular Kart Class 2 CSP Physics Script - Physics Object Class Definition
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
    self.force = math.clamp(-force / self.mass, -self.forceMax, self.forceMax) + (distanceFromCenter * -self.springCoef)
    self.position = self.position + (self.speed * dt)
    if self.position > self.posMax then
        self.position = self.posMax
        self.speed = -self.speed * self.restCoef
    elseif self.position < self.posMin then
        self.position = self.posMin
        self.speed = -self.speed * self.restCoef
    end
    self.accel = self.force * self.mass
    self.speed = self.speed + self.accel
    self.friction = self.speed * self.frictionCoef
    self.speed = self.speed - self.friction

    return self.position
end


return physObj