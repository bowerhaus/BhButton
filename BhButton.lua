--[[
BhButton.lua
A generic button class originally by Gideros Moboile extended by Andy Bower, Bowerhaus LLP

MIT License
(C) 2010 - 2011 Gideros Mobile 
Copyright (C) 2012. Andy Bower, Bowerhaus LLP (http://www.bowerhaus.biz)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

This code is MIT licensed, see http://www.opensource.org/licenses/mit-license.php
]]

BhButton = Core.class(Sprite)

function BhButton:init(upState, downState, optionalTexturePack)
	if optionalTexturePack then
		local upStateTexture=optionalTexturePack:getTextureRegion(upState..".png")
		self.upState = Bitmap.new(upStateTexture)
		if downState then
			local downStateTexture=optionalTexturePack:getTextureRegion(downState..".png")
			self.downState = Bitmap.new(downStateTexture)
		end
	else
		if type(upState)=="string" then
			-- Texture name supplied
			self.upState = Bitmap.bhLoad(upState)
		elseif upState.isVisible then
			-- Actual sprite supplied
			self.upState = upState
		else
			-- Assume texture supplied
			self.upState = Bitmap.new(upState)
		end
		if downState then
			if type(downState)=="string" then
				-- Texture name supplied
				self.downState = Bitmap.bhLoad(downState)
		elseif downState.isVisible then
			-- Actual sprite supplied
			self.downState = downState
		else
			-- Assume texture supplied
			self.downState = Bitmap.new(downState)
		end
		end
	end
	
	self.upScale=1
	self.upRotation=0
	self.downScale=1
	self.downRotation=0
	self.disabledAlpha=0.5
	self.autoRelease=true
	
	if self.downState==nil then
		-- If we haven't been given an explicit down state image then we use the 
		-- up state but modify it slightly (scaling)
		self.downState=self.upState
		self.downScale=0.8
	end
	
	if self.upState.setAnchorPoint then
		self.upState:setAnchorPoint(0.5, 0.5)
	end
	if self.downState.setAnchorPoint then
		self.downState:setAnchorPoint(0.5, 0.5)	
	end

	-- set the visual state as "up" and "enabled"	
	self.isEnabled = true
	self.isDown=false		
	self:updateVisualState()

	self:addEventListener(Event.TOUCHES_BEGIN, self.onTouchesBegin, self)
	self:addEventListener(Event.TOUCHES_MOVE, self.onTouchesMove, self)
	self:addEventListener(Event.TOUCHES_END, self.onTouchesEnd, self)
	self:addEventListener(Event.TOUCHES_CANCEL, self.onTouchesCancel, self)
	
	self:addEventListener(Event.ADDED_TO_STAGE, self.onAddedToStage, self)
	self:addEventListener(Event.REMOVED_FROM_STAGE, self.onRemovedFromStage, self)
end

function BhButton:registerCommand(target, commandName, optQueryName)
	if target[commandName] then
		self:addEventListener("click", target[commandName], target)		
		-- If an additional query handler has been provided then register this
		if optQueryName and target[optQueryName] then
			self:addEventListener("query", target[optQueryName], target)
		end
		
		-- If a command query function exists then register this as well.
		-- This should be registered AFTER the generic optional query handler
		-- to allow more the specific method a chance of override the generic
		local queryName=commandName.."Query"
		if target[queryName] then
			self:addEventListener("query", target[queryName], target)
		end
	end
end

function BhButton:queryCommands()
	-- Fire off a query event so that our listeners get a chance to enable/disable
	local query=Event.new("query")
	if self:hasEventListener("query") then
		query.target=self
		query.isEnabled=true
		self:dispatchEvent(query)
		self:beLatched(query.isLatched)
		self:beEnabled(query.isEnabled)
	end
end

function BhButton:beEnabled(tf)
	if tf~=self.isEnabled then
		self.isEnabled=tf
		self:updateVisualState()
	end
end

function BhButton:onAddedToStage()
self:addEventListener(Event.ENTER_FRAME, self.onEnterFrame, self)
end
 
function BhButton:onRemovedFromStage()
	self:removeEventListener(Event.ENTER_FRAME, self.onEnterFrame, self)
end 

function BhButton: onEnterFrame()
	self:queryCommands()
	if self.body then
		self:setPosition(self.body:getPosition())
		self:setRotation(self.body:getAngle() * 180 / math.pi)
	end
end

function BhButton:onTouchesBegin(event)
	if self.touchId==nil and  self.isEnabled and self:isVisibleDeeply() and self:hitTestPoint(event.touch.x, event.touch.y) then
		self.touchId=event.touch.id
		self.isDown = true
		self:updateVisualState()		
		event:stopPropagation()
	end
end

function BhButton:onTouchesMove(event)
	if self.touchId==event.touch.id then
		if not self:hitTestPoint(event.touch.x, event.touch.y) and self.autoRelease then	
			self.touchId=nil
			self.isDown = false
			self:updateVisualState()
		end
		-- Originally, we used to stop the event propagation here but sometimes it can be useful for,
		-- say, a parent to receive move events to track the movement of the button (e.g. BhJoyButton).
		-- Since most multi-touch handlers have to check the touch id first, I think it is safe to allow
		-- such propagation - unless a touch begin has been handled the subsequent touch events should
		-- be ignored.
		-- event:stopPropagation()
	end
end

function BhButton:onTouchesEnd(event)
	if self.touchId==event.touch.id then
		if self.isToggle then
			self.isLatched=not(self.isLatched)
		end
		self.touchId=nil
		self.isDown = false
		self:updateVisualState()
		
		event=Event.new("click")
		event.target=self
		self:dispatchEvent(event)
		
		-- See comment in onTouchesMove() above
		-- event:stopPropagation()
	end
end

-- if touches are cancelled, reset the state of the button
function BhButton:onTouchesCancel(event)
	-- We assume all touches are cancelled.
	-- Don't check the touch id as this will break BhItemSlider :cancelTouchesFor()
	--
	self.touchId=nil
	self.isDown = false
	self:updateVisualState()
	
	-- See comment in onTouchesMove() above
	-- event:stopPropagation()
end

function BhButton:setLabel(labelSprite)
	self.label=labelSprite
	self:addChild(labelSprite)
end

function BhButton:setLabelState(scale, rot)
	if self.label then
		self.label:setScale(scale)
		self.label:setRotation(rot)
	end
end

function BhButton:beLatched(tf)
	self.isLatched=tf
	self:updateVisualState()
end

-- if state is true show downState else show upState
function BhButton:updateVisualState()	
	if self.isDown or self.isLatched then
		if self:contains(self.upState) then
			self:removeChild(self.upState)
		end
		
		if not self:contains(self.downState) then
			self.downState:setScale(self.downScale)
			self.downState:setRotation(self.downRotation)
			self:setLabelState(self.downScale, self.downRotation)
			self:addChildAt(self.downState, 1)
		end
	else
		if self:contains(self.downState) then
			self:removeChild(self.downState)
		end
		
		if not self:contains(self.upState) then
			self.upState:setScale(self.upScale)
			self.upState:setRotation(self.upRotation)
			self:setLabelState(self.upScale, self.upRotation)
			self:addChildAt(self.upState, 1)
		end
	end
	if self.isEnabled then
		self.upState:setAlpha(1)
		self.downState:setAlpha(1)
	else
		self.upState:setAlpha(self.disabledAlpha)
		self.downState:setAlpha(self.disabledAlpha)
	end
end
