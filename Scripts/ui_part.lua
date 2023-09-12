UiPart = class()

---@class Plane
Plane = class()

function Plane:new(position, normal)
    self.position = position
    self.normal = normal

    return self
end

---@class Ray
Ray = class()

function Ray:new(position, direction)
    self.position = position
    self.direction = direction

    return self
end

---@param ray Ray
---@param plane Plane
---@return boolean, RaycastResult
function UiPart:planeIntersection(ray, plane)
    local dotProduct = ray.direction:dot(plane.normal)

    -- Check if the ray and plane are not parallel
    if math.abs(dotProduct) > 1e-6 then
        local t = (plane.position - ray.position):dot(plane.normal) / dotProduct
        local pointWorld = ray.position + ray.direction * t
        sm.particle.createParticle("paint_smoke", plane.position + plane.normal, nil, sm.color.new(0xff0000ff))

        local localOffset = pointWorld - plane.position

        local x = localOffset:dot(sm.vec3.new(1, 0, 0))
        local y = localOffset:dot(sm.vec3.new(0, 0, 1))
        local pointLocal = sm.vec3.new(x, y, 0)

        -- Ensure the intersection is in front of the ray's origin
        if t >= 0 then
            ---@class RaycastResult
            local RaycastResult = {
                pointWorld = pointWorld,
                pointLocal = pointLocal,
                pointOrigin = ray.position,
                distance = t
            }

            return true, RaycastResult
        end
    end

    return false, nil -- No intersection
end

function UiPart:plane(offset)
    local effect = sm.effect.createEffect("ShapeRenderable", self.interactable)

    effect:setParameter("color",sm.color.new(0xffffffff))
    effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
    effect:setParameter("visualization", true)
    effect:setScale(sm.vec3.new(1, 1, 0.00001))

    if offset then effect:setOffsetPosition(offset) end
    
    effect:start()

    return effect
end

local function keys(table)
    local keyset={}
    local n=0

    for k,v in pairs(table) do
        keyset[v]=k
    end

    return keyset
end

function UiPart:client_onCreate()
    sm.gui.chatMessage("hello world!")

    self.maxDistance = 7.5
    self.actionsKeys = keys(sm.interactable.actions)
    self.effects = {}
    self.effects.frame = self:plane(sm.vec3.new(0, 1, 0))
end

function UiPart:server_onCreate()
    for _, player in ipairs(sm.player.getAllPlayers()) do
        player.character:setLockingInteractable( self.interactable )
    end
end

function UiPart:server_onDestroy()
    for _, player in ipairs(sm.player.getAllPlayers()) do
        player.character:setLockingInteractable( nil )
    end
end

function UiPart:client_onAction( action, state )
    print(string.format("%s%s", self.actionsKeys[action], state and "_on" or "_off"))
    return false
end

function UiPart:client_onFixedUpdate()
    local Ray = Ray:new(sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection())
    local Plane = Plane:new(self.shape:transformLocalPoint(sm.vec3.new(0, 1, 0)), self.shape:getUp())

    local succes, result = self:planeIntersection(Ray, Plane)
    if not succes then return end
    if result.distance > self.maxDistance then return end
    -- if result.pointLocal.x > 0.5 or result.pointLocal.x < -0.5 then return end
    -- if result.pointLocal.y > 0.5 or result.pointLocal.y < -0.5 then return end

    local succesR, resultR = sm.localPlayer.getRaycast(result.distance)
    if succesR then return end

    sm.particle.createParticle("paint_smoke", result.pointWorld)
end