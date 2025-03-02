local helpers = require("helpers")
local Physics = require("physics_classes")
local NodeAnimator = require("node_animator")

local KartAnimator = class("KartAnimator")

function KartAnimator:initialize()
    -- Physics configuration
    self.physics = {
        brakeDisc = Physics{
            posMax = 1,
            posMin = -1,
            center = 0,
            mass = 0.5,
            frictionCoef = 0.3,
            staticFrictionCoef = 0,
            springCoef = 0,
            forceMax = 30,
            constantForce = 0,
            endstopRate = 50
        },
        sidepodRight = NodeAnimator{
            nodeName = "SidepodBouncerRight",
            posMax = 0.008,
            posMin = -0.008,
            center = 0,
            mass = 1,
            frictionCoef = 0.25,
            staticFrictionCoef = 0,
            springCoef = 0,
            forceMax = 50,
            constantForce = -0.2,
            endstopRate = 30,
            flipped = false
        },
        sidepodLeft = NodeAnimator{
            nodeName = "SidepodBouncerLeft",
            posMax = 0.008,
            posMin = -0.008,
            center = 0,
            mass = 1,
            frictionCoef = 0.25,
            staticFrictionCoef = 0,
            springCoef = 0,
            forceMax = 50,
            constantForce = -0.2,
            endstopRate = 30,
            flipped = true
        },
        bumperRear = NodeAnimator{
            nodeName = "RearBumperPlastic",
            posMax = 0.05,
            posMin = -0.05,
            center = 0,
            mass = 1,
            frictionCoef = 0.2,
            staticFrictionCoef = 0,
            springCoef = 0,
            forceMax = 50,
            constantForce = -0.5,
            endstopRate = 50,
            flipped = false
        },
        bumperRearVertical = NodeAnimator{
            nodeName = "RearBumperBracket",
            posMax = 0.02,
            posMin = -0.01,
            center = 0,
            mass = 0.5,
            frictionCoef = 0.4,
            staticFrictionCoef = 0,
            springCoef = 0,
            forceMax = 100,
            constantForce = -0.1,
            endstopRate = 100,
            flipped = false
        },
        bumperRearAxial = NodeAnimator{
            nodeName = "RearBumperBracketRotator",
            posMax = 0.0,
            posMin = -0.0,
            center = 0,
            mass = 0.5,
            frictionCoef = 0.6,
            staticFrictionCoef = 0,
            springCoef = 0.2,
            forceMax = 100,
            constantForce = 0,
            endstopRate = 50,
            flipped = false
        },
        nassau = NodeAnimator{
            nodeName = "Nassau Bouncer",
            posMax = 0.0,
            posMin = -0.0,
            center = 0,
            mass = 1.5,
            frictionCoef = 0.2,
            staticFrictionCoef = 0,
            springCoef = 0.0,
            forceMax = 100,
            constantForce = 0,
            endstopRate = 70
        },
        nosecone = NodeAnimator{
            nodeName = "NoseconeBouncer",
            posMax = 0.0,
            posMin = -0.0,
            center = 0,
            mass = 3,
            frictionCoef = 0.3,
            staticFrictionCoef = 0,
            springCoef = 0.0,
            forceMax = 100,
            constantForce = 0,
            endstopRate = 120
        }
    }


    -- Node configuration
    self.nodes = {
        pedals = {
            gas = { node = "PedalGas" },
            brake = { node = "PedalBrake" }
        },
        brakeSystem = {
            lever = { node = "BrakeLever" },
            disc = { node = "BrakeDiscTabs" },
            pad1 = { node = "BrakePad.001" },
            pad2 = { node = "BrakePad.002" }
        },
        steering = {
            carNode = { node = "BODYTR" },
            tierodLTarget = { node = "DIR2_anim_tierodLF" },
            tierodRTarget = { node = "DIR2_anim_tierodRF" },
            tierodLControl = { node = "DIR_anim_tierodLF" },
            tierodRControl = { node = "DIR_anim_tierodRF" }
        }
    }

    -- Initialize pedal nodes
    for _, pedal in pairs(self.nodes.pedals) do
        pedal.node = ac.findNodes(pedal.node)
        pedal.node:storeCurrentTransformation()
        pedal.forward = pedal.node:getLook()
        pedal.up = pedal.node:getUp()
    end

    -- Initialize brake system nodes
    for _, part in pairs(self.nodes.brakeSystem) do
        part.node = ac.findNodes(part.node)
        part.node:storeCurrentTransformation()
        if part.node:getLook() then
            part.forward = part.node:getLook()
            part.up = part.node:getUp()
        end
        part.position = part.node:getPosition()
    end

    -- Initialize steering nodes
    for _, part in pairs(self.nodes.steering) do
        part.node = ac.findNodes(part.node)
    end
end


function KartAnimator:update(dt, angularAcceleration)
    local forceSidepodRight = (car.acceleration.y * 0.1 * self.physics.sidepodRight.physics.mass) + (angularAcceleration.z * 0.01 * self.physics.sidepodRight.physics.mass)
    local forceSidepodLeft = (car.acceleration.y * 0.1 * self.physics.sidepodLeft.physics.mass) + (angularAcceleration.z * -0.01 * self.physics.sidepodLeft.physics.mass)
    local forceBumperRear = (car.acceleration.y * 0.2 * self.physics.bumperRear.physics.mass)
    local forceBumperRearAxial = (angularAcceleration.z * 0.03 * self.physics.bumperRearAxial.physics.mass)
    local forceBumperRearVertical = (car.acceleration.y * 0.1 * self.physics.bumperRearVertical.physics.mass)
    local forceNassau = (car.acceleration.x * 0.6)
    local forceNosecone = (car.acceleration.y * -0.2)

    self.physics.sidepodRight:update(forceSidepodRight, vec3(1, 0, 0), vec3(0, 0, 0), dt)
    self.physics.sidepodLeft:update(forceSidepodLeft, vec3(1, 0, 0), vec3(0, 0, 0), dt)
    self.physics.bumperRear:update(forceBumperRear, vec3(0, 1, 0), vec3(0, 0, 0), dt)
    self.physics.bumperRearAxial:update(forceBumperRearAxial, vec3(1, 0, 0), vec3(0, 0, 0), dt)
    self.physics.bumperRearVertical:update(forceBumperRearVertical, vec3(0, 0, 0), vec3(0, 0, 1), dt)
    self.physics.nassau:update(forceNassau, vec3(1, 0, 0), vec3(0, 0, 0), dt)
    self.physics.nosecone:update(forceNosecone, vec3(0, 0, 1), vec3(0, 0, 0), dt)

    self.physics.brakeDisc.posMax = helpers.mapRange(car.brake, 0, 0.2, 1, 0.1, true)
    self.physics.brakeDisc.posMin = helpers.mapRange(car.brake, 0, 0.2, -1, -0.1, true)
    local brakeDiscAnimPos = self.physics.brakeDisc:step(car.acceleration.x * 100, dt)

    self.nodes.brakeSystem.disc.node:setPosition(
        self.nodes.brakeSystem.disc.position +
        vec3(0, 0, brakeDiscAnimPos * helpers.mapRange(car.brake, 0, 0.2, 1, 0, true) * 0.0005)
    )
    self.nodes.brakeSystem.pad1.node:setPosition(
        self.nodes.brakeSystem.pad1.position +
        vec3(helpers.mapRange(car.brake, 0, 0.2, 0, -0.001, true), 0, 0)
    )
    self.nodes.brakeSystem.pad2.node:setPosition(
        self.nodes.brakeSystem.pad2.position +
        vec3(helpers.mapRange(car.brake, 0, 0.2, 0, 0.001, true), 0, 0)
    )

    -- Update brake lever
    self.nodes.brakeSystem.lever.node:setOrientation(
        self.nodes.brakeSystem.lever.forward, 
        self.nodes.brakeSystem.lever.up + vec3(0, car.brake * 0.47, 0)
    )

    -- Update steering tierods
    self.nodes.steering.tierodLControl.node:setPosition(
        helpers.getPositionInCarFrame(self.nodes.steering.tierodLTarget.node, self.nodes.steering.carNode.node)
    )
    self.nodes.steering.tierodRControl.node:setPosition(
        helpers.getPositionInCarFrame(self.nodes.steering.tierodRTarget.node, self.nodes.steering.carNode.node)
    )

    -- Update pedals with converted forces
    self.nodes.pedals.brake.node:setOrientation(
        self.nodes.pedals.brake.forward + vec3(0, 0, car.brake * 0.2),
        self.nodes.pedals.brake.up
    )
    self.nodes.pedals.gas.node:setOrientation(
        self.nodes.pedals.gas.forward + vec3(0, 0, car.gas * 0.4),
        self.nodes.pedals.gas.up
    )
end

return KartAnimator 