local Physics = class("Physics")

function Physics:initialize(params)
    self.posMax = params.posMax
    self.posMin = params.posMin
    self.center = params.center
    self.position = params.center
    self.speed = 0
    self.force = 0
    self.accel = 0
    self.frictionCoef = params.frictionCoef or 0.1
    self.friction = self.speed * self.frictionCoef
    self.mass = params.mass
    self.springCoef = params.springCoef
    self.forceMax = params.forceMax
    self.constantForce = params.constantForce or 0
    self.endstopRate = params.endstopRate or 1  -- Default value if not provided
end


function Physics:step(force, dt)
    local distanceFromCenter = self.position - self.center
    self.force = math.clamp(-force * self.mass, -self.forceMax, self.forceMax) + (distanceFromCenter * -self.springCoef) + self.constantForce
    self.position = self.position + (self.speed * dt)
    
    if self.position > self.posMax then
        local overshoot = self.position - self.posMax
        local endstopForce = overshoot * self.endstopRate
        self.force = math.clamp(self.force - endstopForce, -self.forceMax, self.forceMax)
    elseif self.position < self.posMin then
        local overshoot = self.posMin - self.position
        local endstopForce = overshoot * self.endstopRate
        self.force = math.clamp(self.force + endstopForce, -self.forceMax, self.forceMax)
    end
    
    self.accel = self.force / self.mass
    self.speed = self.speed + self.accel
    self.friction = self.speed * self.frictionCoef
    self.speed = self.speed - self.friction

    if math.isnan(self.position) or math.isnan(self.speed) or math.isnan(self.force) or math.isnan(self.accel) then
        self.position = self.center
        self.speed = 0
        self.force = 0
        self.accel = 0
        self.friction = 0
    end

    return self.position
end

return Physics