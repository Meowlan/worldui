dofile "$CONTENT_DATA/Scripts/worldui.lua"

---@class UiPart
---@field interactable Interactable The [Interactable] game object belonging to this class instance. (The same as shape.interactable)
---@field shape Shape The [Shape] game object that the [Interactable] is attached to. (The same as interactable.shape)
---@field network Network A [Network] object that can be used to send messages between client and server.
---@field storage Storage (Server side only.) A [Storage] object that can be used to store data for the next time loading this object after being unloaded.
---@field data any Data from the "data" json element.
---@field params any Parameter set with [Interactable.setParams] when created from a script.
UiPart = class()

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

	self.panels = {}

	--TODO: add a way to change if the panels should start at the top left corner or in the center, currently it always starts in the center

	self.panels.frame = Worldui.Panel.new()
	self.panels.frame.host = self.interactable
	self.panels.frame.size = sm.vec3.new(2, 2, 0.00001)
	self.panels.frame.position = sm.vec3.new(0, 1 + 0.125, 0)
	self.panels.frame:draw()

	self.panels.button = Worldui.Panel.new()
	self.panels.button.host = self.interactable
	self.panels.button.size = sm.vec3.new(0.5, 0.5, 0.00001)
	self.panels.button.position = sm.vec3.new(0, 0.5 + 0.125, 0.005)
	self.panels.button.color = sm.color.new(0x00afffff)
	self.panels.button.shapeUuid = sm.uuid.new("0cf010e1-50c5-4c98-b56b-e3c6e8c9d3b9") -- uuid for rounded_rect
	self.panels.button:draw()

	self.text_frame = [[
hello world,
this is an epic newline test!

oh and this line has an indent wrapped    over

eh whaterver who cares anyways
#0000fftime to parse some #00ff00color

#ffffffEpic progress bar:
%s #ffffff[%0.2f%%]

#ff00ffxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
]]

	self.panels.text_frame = Worldui.Text.new()
	self.panels.text_frame.text = self.text_frame
	self.panels.text_frame.position = self.panels.frame.position
	self.panels.text_frame.size = self.panels.frame.size
	self.panels.text_frame.host = self.interactable
	self.panels.text_frame:draw()

	self.panels.text_button = Worldui.Text.new()
	self.panels.text_button.text = "im an epic button with text on it"
	self.panels.text_button.position = self.panels.button.position
	self.panels.text_button.size = self.panels.button.size
	self.panels.text_button.host = self.interactable
	self.panels.text_button:draw()

	self.time = 0
end

function UiPart:client_onDestroy()
	for _, panel in pairs(self.panels) do
		panel:destroy()
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

function UiPart:lock(player)
	player.character:setLockingInteractable(self.interactable)
end

function UiPart:unlock(player)
	player.character:setLockingInteractable( nil )
end

function UiPart:probLock()
	local success, _ = self.panels.frame:panelIntersection(sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection(), self.maxDistance)

	if success and not self.locked and not sm.localPlayer.getPlayer().character:getLockingInteractable() then
		sm.event.sendToInteractable(self.interactable, "lock", sm.localPlayer.getPlayer())
		self.locked = true
	elseif not success and self.locked then
		sm.event.sendToInteractable(self.interactable, "unlock", sm.localPlayer.getPlayer())
		self.locked = false
	end
end

function UiPart:client_onFixedUpdate(dt)
	self:probLock()
	
	local a = self.time % 10 -- time
	local p = a / 10 -- percentage
	p = sm.util.easing("easeInOutQuint", p)

	local width = 20 -- Width of the progress bar

	local progressBar = createProgressBar(p, width)
	local newtext = string.format(self.text_frame, progressBar, p*100)

	self.time = self.time + dt
	self.panels.text_frame:setText(newtext)
end

function UiPart:client_onAction( action, state )
	if action == sm.interactable.actions.create and state then
		-- TODO: a proper button manager. preferably using callbacks if possiblle.
		-- Add a new ui class for button, wich you can give a call back at creation
		-- and then the user just has to call a function inside their client_onAtion like self.Buttons:probe( action, state )
		local success, _ = self.panels.frame:panelIntersection(sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection(), self.maxDistance)
		if not success then return false end

		local buttonsuccess, buttonresult = self.panels.button:panelIntersection(sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection(), self.maxDistance)
		if buttonsuccess then
			print(sm.gui.chatMessage(string.format("bruh quit pressing on me!! (%0.2f, %0.2f)", buttonresult.pointLocal.x, buttonresult.pointLocal.y)))
		end

		return success
	end

	print(string.format("%s%s", self.actionsKeys[action], state and "_on" or "_off"))
	return false
end