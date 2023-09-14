dofile "$CONTENT_DATA/Scripts/font.lua"

-- TODO: actually make this stuff a library and move all the ui library stuff out into a seperate file

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
	newUiPanel.color = sm.color.new(0xffffffff)
	newUiPanel.shapeUuid = sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f")
	newUiPanel.visualziation = false
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
	local Plane = UiPart.Plane:new(UiPart.Panel:panelGetWorlPos(panel), sm.quat.getRight(rot), sm.quat.getUp(rot))

	local success, result = UiPart.Plane:planeIntersection(Ray, Plane)
	if not success then return false, nil end
	if result.distance > range then return false, nil end
	if result.pointLocal.x > panel.size.x / 2 or result.pointLocal.x < -panel.size.x / 2 then return false, nil end
	if result.pointLocal.y > panel.size.y / 2 or result.pointLocal.y < -panel.size.y / 2 then return false, nil end

	local succesR, resultR = sm.localPlayer.getRaycast(result.distance)
	if succesR then return false, nil end

	return success, result
end

---@class Text
UiPart.Text = class()
function UiPart.Text:newText(text, font_size, layer, position, size, rotation, host, wrap, color)

	-- TODO: a full rewrite of this function, espacially the text parsing could be made a lot faster and cleaner

	self.Font = Font:init()
	local ratio = 0.5352112676056338 -- the ratio between width and height, devide the height by this to get the offset
	local charx = font_size
	local chary = font_size / ratio

	local maxperline = (size.x * 4) / font_size
	local maxperliney = (size.y * 4) / (font_size / ratio) - 1
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
			cursor = cursor % maxperline
			line = line + 1
		end

		if line > maxperliney then
			break
		end

		local x = cursor * font_size + charx / 2
		local y = -line * font_size / ratio - chary / 2

		local charPos = position + (rotation * sm.vec3.new(x, y, layer)) * 0.25
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
	self.locked = false
	self.actionsKeys = keys(sm.interactable.actions)

	for _, effect in ipairs(self.effects or {}) do
		if sm.exists(effect) then
			effect:destroy()
		end
	end

	self.effects = {}
	self.panels = {}

	--TODO: i dont really like the way you position  and scale the panels at the moment, 
	-- the size isnt really related to the position, and the panels star from the center 
	-- while text starts from the top left corner

	self.panels.frame = UiPart.Panel:newUiPanel()
	self.panels.frame.localTo = self.interactable
	self.panels.frame.size = sm.vec3.new(2, 2, 0.00001)
	self.panels.frame.position = sm.vec3.new(0, 1 + 0.125, 0)
	UiPart.Panel:panelCreateEffect(self.panels.frame)

	self.panels.button = UiPart.Panel:newUiPanel()
	self.panels.button.localTo = self.interactable
	self.panels.button.size = sm.vec3.new(0.5, 0.5, 0.00001)
	self.panels.button.position = sm.vec3.new(0, 0.5 + 0.125, 0.005)
	self.panels.button.color = sm.color.new(0x00afffff)
	self.panels.button.shapeUuid = sm.uuid.new("0cf010e1-50c5-4c98-b56b-e3c6e8c9d3b9")
	UiPart.Panel:panelCreateEffect(self.panels.button)

	local text = "im an epic button with text on it"
	self.panels.text2 = {}

	-- TODO: rework the text constructor to make it simiar to the ui panel stuff, 
	-- First you initialize the data structure, do your modifications to it like 
	-- changing the size and position, And then you create the effects.
	-- then in order to modify the text you just call something like 
	-- self.Text:setText(self.panels.text1, "sex")

	self.panels.text2.effects = self.Text:newText(text, 0.2, 0.005, self.panels.button.position - sm.vec3.new(0.25, -0.25, 0), self.panels.button.size, sm.quat.identity(), self.interactable, true, sm.color.new(0xffffffff))
	for _, effect in ipairs(self.panels.text2.effects) do
		table.insert(self.effects, effect)
	end

	self.text = [[
hello world,
this is an epic newline test!

oh and this line has an indent wrapped    over

eh whaterver who cares anyways
#0000fftime to parse some #00ff00color

#ffffffEpic progress bar:
%s #ffffff[%0.2f%%]

#ff00ffxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
]]

	self.panels.text1 = {}
	self.panels.text1.effects = self.Text:newText(self.text, 0.2, 0.005, sm.vec3.new(-1, 2 + 0.125, 0), sm.vec3.one()*2, sm.quat.identity(), self.interactable, true, sm.color.new(0xffffffff))
	for _, effect in ipairs(self.panels.text1.effects) do
		table.insert(self.effects, effect)
	end
	self.time = 0
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

local function colorLerp(colora, colorb, t)
	return sm.color.new(
		sm.util.lerp( colora.r, colorb.r, t ),
		sm.util.lerp( colora.g, colorb.g, t ),
		sm.util.lerp( colora.b, colorb.b, t )
	)
end

local function getHexAtP(p)
	local color = colorLerp(sm.color.new(0xff0000ff), sm.color.new(0x0000ffff), p)
	return "#"..color:getHexStr():sub(1, -3)
end

local function createProgressBar(p, width)
	local color = getHexAtP(p)
    local progressBar = "["
    local characters = {" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"}
    local numCharacters = #characters
    local numBars = math.floor(p * width)
    local remainder = (p * width - numBars) * numCharacters

    for i = 1, numBars do
        progressBar = progressBar .. getHexAtP(i/width) .. "█"
    end

    if numBars < width then
        progressBar = progressBar .. color .. characters[math.floor(remainder) + 1]
    end

    for i = numBars + 1, width - 1 do
        progressBar = progressBar .. " "
    end

    return progressBar .. "#ffffff]"
end

function UiPart:lock(_, player)
	player.character:setLockingInteractable(self.interactable)
end

function UiPart:unlock(_, player)
	player.character:setLockingInteractable( nil )
end

function UiPart:client_onFixedUpdate(dt)
	local success, result = UiPart.Panel:panelIntersection(self.panels.frame, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection(), self.maxDistance)

	if success and not self.locked then
		self.network:sendToServer("lock")
		self.locked = true
	elseif not success and self.locked then
		self.network:sendToServer("unlock")
		self.locked = false
	end

	--if not success or true then return end

	local a = self.time % 10 -- time
	local p = a / 10 -- percentage
	p = sm.util.easing("easeInOutQuint", p)

	local width = 20 -- Width of the progress bar

	local progressBar = createProgressBar(p, width)
	local newtext = string.format(self.text, progressBar, p*100)

	self.time = self.time + dt
	if (self._text or "") ~= newtext then
		self._text = newtext

		--TODO: Make a proper effect managar, and make an text update function that only deletes/recreates effects that have been changed 

		for _, effect in ipairs(self.panels.text1.effects or {}) do
			if sm.exists(effect) then
				effect:destroy()
			end
		end

		self.panels.text1.effects = self.Text:newText(self._text, 0.2, 0.005, sm.vec3.new(-1, 2 + 0.125, 0), sm.vec3.one()*2, sm.quat.identity(), self.interactable, true, sm.color.new(0xffffffff))
	end

	--sm.particle.createParticle("paint_smoke", result.pointWorld, nil, sm.color.new(0xff00ffff))
end

function UiPart:client_onAction( action, state )
	if action == sm.interactable.actions.create and state then
		-- TODO: a proper button manager. preferably using callbacks if possiblle.
		-- Add a new ui class for button, wich you can give a call back at creation
		-- and then the user just has to call a function inside their client_onAtion like self.Buttons:probe( action, state )
		local success, result = UiPart.Panel:panelIntersection(self.panels.button, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection(), self.maxDistance)
		if success then
			print(sm.gui.chatMessage(string.format("bruh quit pressing on me!! (%0.2f, %0.2f)", result.pointLocal.x, result.pointLocal.y)))
		end
	end

	print(string.format("%s%s", self.actionsKeys[action], state and "_on" or "_off"))
	return false
end