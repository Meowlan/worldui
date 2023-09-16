dofile "$CONTENT_DATA/Scripts/font.lua"

-- TODO: fix the classes

---@class Worldui
Worldui = class()

Worldui.Font = Font:init()

---@class Plane
---@field position Vec3
---@field up Vec3
---@field right Vec3
---@field normal Vec3
Worldui.Plane = class()
---@param position Vec3
---@param up Vec3
---@param right Vec3
---@return Plane
function Worldui.Plane:new(position, up, right)
	self.position = position
	self.up = up
	self.right = right
	self.normal = right:cross(up)

	return self
end

---@param ray Ray
---@param plane Plane
---@return boolean, RaycastResult
function Worldui.Plane:planeIntersection(ray, plane)
	local dotProduct = ray.direction:dot(plane.normal)

	-- Check if the ray and plane are not parallel
	if math.abs(dotProduct) > 1e-6 then
		local t = (plane.position - ray.position):dot(plane.normal) / dotProduct
		local pointWorld = ray.position + ray.direction * t -- position of where the ray intersected the plane

		local localOffset = pointWorld - plane.position

		local x = localOffset:dot(plane.up)
		local y = localOffset:dot(plane.right)
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

---@class Ray
---@field position Vec3
---@field direction Vec3
Worldui.Ray = class()
---@param position Vec3
---@param direction Vec3
---@return Ray
function Worldui.Ray:new(position, direction)
    local ray = {}
	ray.position = position
	ray.direction = direction

	return ray
end

---@class Panel
---@field position Vec3
---@field size Vec3
---@field rotation Quat
---@field color Color
---@field shapeUuid Uuid
---@field host Interactable
---@field effects table
Worldui.Panel = class()

function Worldui.Panel:new()
	self.position = sm.vec3.zero()
	self.size = sm.vec3.new(1, 1, 0.00001)
	self.rotation = sm.quat.identity()
	self.color = sm.color.new(0xffffffff)
	self.shapeUuid = sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f")
	self.visualziation = false
	self.host = nil
    self.effect = nil
    self.type = "panel"

	return self
end

function Worldui.Panel:createEffect()
	local effect = sm.effect.createEffect("ShapeRenderable", self.host)

	if sm.exists(self.host) then
		effect:setOffsetPosition(self.position)
		effect:setOffsetRotation(self.rotation)
	else
		effect:setPosition(self.position)
		effect:setRotation(self.rotation)
	end

	effect:setScale(self.size)
	effect:setParameter("color", self.color)
	effect:setParameter("uuid", self.shapeUuid)
	effect:setParameter("visualization", self.visualziation)
	effect:setScale(self.size)

	effect:start()
    self.effect = effect
    return self
end

function Worldui.Panel:panelUpdateEffect()

	if sm.exists(self.host) then
		self.effect:setOffsetPosition(self.position)
		self.effect:setOffsetRotation(self.rotation)
	else
		self.effect:setPosition(self.position)
		self.effect:setRotation(self.rotation)
	end

	self.effect:setScale(self.size)
	self.effect:setParameter("color", self.color)
	self.effect:setParameter("uuid", self.shapeUuid)
	self.effect:setParameter("visualization", self.visualziation)
	self.effect:setScale(self.size)
end

function Worldui.Panel:panelGetWorlPos()
    return sm.exists(self.host) and self.host.shape:transformLocalPoint(self.position) or self.position
end

function Worldui.Panel:panelGetWorlRot()
	return sm.exists(self.host) and self.rotation * self.host.shape.worldRotation or self.rotation
end

function Worldui.Panel:destroy()
    if sm.exists(self.effect) then
        self.effect:destroy()
    end

    self.effect = nil
end

---@param origin Vec3
---@param direction Vec3
---@return boolean, RaycastResult
function Worldui.Panel:panelIntersection(origin, direction, range)
	range = range or 7.5
	local Ray = Worldui.Ray:new(origin, direction)
	local rot = self:panelGetWorlRot()
	local Plane = Worldui.Plane:new(self:panelGetWorlPos(), sm.quat.getRight(rot), sm.quat.getUp(rot))

	local success, result = Worldui.Plane:planeIntersection(Ray, Plane)
	if not success then return false, nil end
	if result.distance > range then return false, nil end
	if result.pointLocal.x > self.size.x / 2 or result.pointLocal.x < -self.size.x / 2 then return false, nil end
	if result.pointLocal.y > self.size.y / 2 or result.pointLocal.y < -self.size.y / 2 then return false, nil end

	local succesR, resultR = sm.localPlayer.getRaycast(result.distance)
	if succesR then return false, nil end

	return success, result
end

---@class Text
Worldui.Text = class()
function Worldui.Text:new()
    self.text = ""
    self.textSize = 0.2
    self.layer = 0.005
    self.position = sm.vec3.zero()
    self.size = sm.vec3.one()
    self.rotation = sm.quat.identity()
    self.host = nil
    self.wrap = true
    self.color = sm.color.new(0xffffffff)
    self.effects = {}
    self.type = "text"

	return self
end

function Worldui.Text:createEffects()
    -- TODO: a full rewrite of this function, espacially the text parsing could be made a lot faster and cleaner

	local ratio = 0.5352112676056338 -- the ratio between width and height, devide the height by this to get the offset
	local charx = self.textSize
	local chary = self.textSize / ratio

    local color = self.color

	local maxperline = (self.size.x * 4) / self.textSize
	local maxperliney = (self.size.y * 4) / (self.textSize / ratio) - 1
	local cursor = 0
	local charIndex = 0
	local line = 0

	local skip = 0
	local text_iter = string.gmatch(self.text, "([%z\1-\127\194-\244][\128-\191]*)")
	local text_split = {}
	for uchar in text_iter do
		table.insert(text_split, uchar)
	end

	text_iter = string.gmatch(self.text, "([%z\1-\127\194-\244][\128-\191]*)")
	for uchar in text_iter do
		charIndex = charIndex + 1
		if skip > 0 then
			skip = skip - 1
			goto continue
		end

		local uuid = Worldui.Font.Char2uuid[uchar]
		if uchar == " " then
			cursor = cursor + 1
			goto continue
		elseif uchar == "\n" then
			line = line + 1
			cursor = 0
			goto continue
		elseif uchar == "\t" then
			cursor = cursor + 4
			goto continue
		elseif uchar == "#" then
			local hex = ""
			if charIndex + 6 > #text_split then goto checksDone end
			for i=1, 6 do
				local hexchar = text_split[charIndex + i]
				local isHexDigit = string.match(hexchar, "[0-9a-fA-F]")
        		if not isHexDigit then goto checksDone end
				hex = hex .. hexchar
			end

			hex = hex.."ff"
			color = sm.color.new(hex)

			skip = 6
			goto continue
		elseif not uuid then 
			print(string.format("FUCK␇ character \"%s\" not available", uchar))
			goto continue
		end
		::checksDone::

		if cursor >= maxperline then
            if not self.wrap then goto continue end
                
            cursor = cursor % maxperline
            line = line + 1
		end

		if line > maxperliney then
			break
		end

		local x = (cursor * self.textSize + charx / 2) - self.size.x * 2
		local y = (-line * self.textSize / ratio - chary / 2) + self.size.y * 2

		local charPos = self.position + (self.rotation * sm.vec3.new(x, y, self.layer)) * 0.25
		local charSize = sm.vec3.one() * self.textSize

		local effect = self:newChar(uuid, charPos, charSize * 0.25, self.rotation, self.host, color)
		table.insert(self.effects, effect)
		cursor = cursor + 1
		::continue::
	end
end

function Worldui.Text:newChar(uuid, position, size, rotation, host, color)
	local effect = sm.effect.createEffect("ShapeRenderable", host)
	
	if host then
		effect:setOffsetPosition(position)
		effect:setOffsetRotation(rotation)
	else
		effect:setPosition(position)
		effect:setRotation(rotation)
	end

	effect:setScale(size)
	effect:setParameter("uuid", sm.uuid.new(uuid))
	effect:setParameter("color", color or sm.color.new(0xffffffff))
	effect:start()

	return effect
end

--TODO: Make a proper effect managar, and make an text update function that only deletes/recreates effects that have been changed 
function Worldui.Text:setText(text)
    self.text = text
    self:destroy()
    self:createEffects()
end

function Worldui.Text:destroy()
    for _, effect in ipairs(self.effects) do
        if sm.exists(effect) then
            effect:destroy()
        end
    end

    self.effects = {}
end