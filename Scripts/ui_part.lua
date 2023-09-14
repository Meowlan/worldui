dofile "$CONTENT_DATA/Scripts/font.lua"

---@class UiPart
---@field interactable Interactable The [Interactable] game object belonging to this class instance. (The same as shape.interactable)
---@field shape Shape The [Shape] game object that the [Interactable] is attached to. (The same as interactable.shape)
---@field network Network A [Network] object that can be used to send messages between client and server.
---@field storage Storage (Server side only.) A [Storage] object that can be used to store data for the next time loading this object after being unloaded.
---@field data any Data from the "data" json element.
---@field params any Parameter set with [Interactable.setParams] when created from a script.
UiPart = class()

---@class Plane
UiPart.Plane = class()
function UiPart.Plane:new(position, up, right)
	self.position = position
	self.up = up
	self.right = right
	self.normal = right:cross(up)

	return self
end

---@param ray Ray
---@param plane Plane
---@return boolean, RaycastResult
function UiPart.Plane:planeIntersection(ray, plane)
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
UiPart.Ray = class()
function UiPart.Ray:new(position, direction)
	self.position = position
	self.direction = direction

	return self
end

---@class Panel
UiPart.Panel = class()
function UiPart.Panel:newUiPanel()
	local newUiPanel = {}
	newUiPanel.position = sm.vec3.zero()
	newUiPanel.size = sm.vec3.new(1, 1, 0.00001)
	newUiPanel.rotation = sm.quat.identity()
	newUiPanel.color = sm.color.new(0x00000000)
	newUiPanel.shapeUuid = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")
	newUiPanel.visualziation = true
	newUiPanel.localTo = nil
	return newUiPanel
end

function UiPart.Panel:panelCreateEffect(uipanel)
	local effect = sm.effect.createEffect("ShapeRenderable", uipanel.localTo)

	if sm.exists(uipanel.localTo) then
		effect:setOffsetPosition(uipanel.position)
		effect:setOffsetRotation(uipanel.rotation)
	else
		effect:setPosition(uipanel.position)
		effect:setRotation(uipanel.rotation)
	end

	effect:setScale(uipanel.size)
	effect:setParameter("color", uipanel.color)
	effect:setParameter("uuid", uipanel.shapeUuid)
	effect:setParameter("visualization", uipanel.visualziation)
	effect:setScale(uipanel.size)

	effect:start()
	uipanel.effect = effect
	return effect
end

function UiPart.Panel:panelUpdateEffect(uipanel)

	if sm.exists(uipanel.localTo) then
		uipanel.effect:setOffsetPosition(uipanel.position)
		uipanel.effect:setOffsetRotation(uipanel.rotation)
	else
		uipanel.effect:setPosition(uipanel.position)
		uipanel.effect:setRotation(uipanel.rotation)
	end

	uipanel.effect:setScale(uipanel.size)
	uipanel.effect:setParameter("color", uipanel.color)
	uipanel.effect:setParameter("uuid", uipanel.shapeUuid)
	uipanel.effect:setParameter("visualization", uipanel.visualziation)
	uipanel.effect:setScale(uipanel.size)
end

function UiPart.Panel:panelGetWorlPos(panel)
	if sm.exists(panel.localTo) then
		return panel.localTo.shape:transformLocalPoint(panel.position)
	else
		return panel.position
	end
end

function UiPart.Panel:panelGetWorlRot(panel)
	if sm.exists(panel.localTo) then
		return panel.rotation * panel.localTo.shape.worldRotation
	else
		return panel.rotation
	end
end

---@param origin Vec3
---@param direction Vec3
---@param panel Panel
---@return boolean, RaycastResult
function UiPart.Panel:panelIntersection(panel, origin, direction, range)
	range = range or 7.5
	local Ray = UiPart.Ray:new(origin, direction)
	local rot = UiPart.Panel:panelGetWorlRot(panel)
	local Plane = UiPart.Plane:new(UiPart.Panel:panelGetWorlPos(panel), sm.quat.getUp(rot), sm.quat.getRight(rot))

	local success, result = UiPart.Plane:planeIntersection(Ray, Plane)
	if not success then return false, nil end
	if result.distance > range then return false, nil end
	if result.pointLocal.x > 0.5 or result.pointLocal.x < -0.5 then return false, nil end
	if result.pointLocal.y > 0.5 or result.pointLocal.y < -0.5 then return false, nil end

	local succesR, resultR = sm.localPlayer.getRaycast(result.distance)
	if succesR then return false, nil end

	return success, result
end

---@class Text
UiPart.Text = class()
function UiPart.Text:newText(text, font_size, layer, position, size, rotation, host, wrap, color, padding)
	self.Font = Font:init()
	local ratio = 0.5352112676056338 -- the ratio between width and height, devide the height by this to get the offset
	local charx = font_size
	local chary = font_size / ratio

	local maxperline = ((size.x - padding / 2) * 4) / font_size
	local maxperliney = ((size.y - padding / 2) * 4) / (font_size / ratio) - 1
	local cursor = 0
	local charIndex = 0
	local line = 0

	local effects = {}
	local skip = 0
	local text_iter = string.gmatch(text, "([%z\1-\127\194-\244][\128-\191]*)")
	local text_split = {}
	for uchar in text_iter do
		table.insert(text_split, uchar)
	end

	text_iter = string.gmatch(text, "([%z\1-\127\194-\244][\128-\191]*)")
	for uchar in text_iter do
		charIndex = charIndex + 1
		if skip > 0 then
			skip = skip - 1
			goto continue
		end

		local uuid = self.Font.Char2uuid[uchar]
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
			print(string.format("FUCK␇ character %s not available", uchar))
			goto continue
		end
		::checksDone::

		if cursor >= maxperline then
			cursor = math.floor(cursor % maxperline) - 1
			line = line + 1
		end

		if line > maxperliney then
			break
		end

		local x = cursor * font_size + charx / 2
		local y = -line * font_size / ratio - chary / 2

		local charPos = position + (rotation * sm.vec3.new(x + padding, y - padding, layer)) * 0.25
		local charSize = sm.vec3.one() * font_size

		local effect = self:newChar(uuid, charPos, charSize * 0.25, rotation, host, color)
		table.insert(effects, effect)
		cursor = cursor + 1
		::continue::
	end

	return effects
end

function UiPart.Text:newChar(uuid, position, size, rotation, host, color)
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

local function keys(table)
	local keyset={}
	local n=0

	for k,v in pairs(table) do
		keyset[v]=k
	end

	return keyset
end

function UiPart:client_onCreate()
	self.maxDistance = 7.5
	self.actionsKeys = keys(sm.interactable.actions)

	for _, effect in ipairs(self.effects or {}) do
		effect:destroy()
	end

	self.effects = {}
	self.panels = {}
	self.panels.frame = UiPart.Panel:newUiPanel()
	self.panels.frame.localTo = self.interactable
	self.panels.frame.size = sm.vec3.new(2, 2, 0.00001)
	self.panels.frame.position = sm.vec3.new(0, 1, 0)
	UiPart.Panel:panelCreateEffect(self.panels.frame)

	local text = [[
hello world,
this is an epic newline test!

oh and this line has an indent wrapped    over

eh whaterver who cares anyways
#0000fftime to parse some #00ff00color
#ffffffEpic progress bar: 25%
#ff00ff█████#aa00ff▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
]]

	self.panels.text1 = {}
	self.panels.text1.effects = self.Text:newText(text, 0.2, 0.005, sm.vec3.new(-1, 2, 0), sm.vec3.one()*2, sm.quat.identity(), self.interactable, true, sm.color.new(0xffffffff), 0.25)
	for _, effect in ipairs(self.panels.text1.effects) do
		table.insert(self.effects, effect)
	end
end

function UiPart:client_onDestroy()
	for _, panel in pairs(self.panels) do
		if sm.exists(panel.effect) then
			panel.effect:destroy()
		end
	end
end

function UiPart:client_onRefresh()
	self:client_onDestroy()
	self:client_onCreate()
end

function UiPart:client_onFixedUpdate()
	local success, result = UiPart.Panel:panelIntersection(self.panels.frame, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection(), self.maxDistance)
	if not success then return end
	--sm.particle.createParticle("paint_smoke", result.pointWorld, nil, sm.color.new(0xff00ffff))
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