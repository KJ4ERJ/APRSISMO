--------------------------------------------------------------------------------
-- This is a class to draw the text with a background color
-- See MOAITextBox.<br>
-- Base Classes => TextLabel
--------------------------------------------------------------------------------

-- import
local table                     = require("hp/lang/table")
local class                     = require("hp/lang/class")
local TextLabel		            = require("hp/display/TextLabel")

-- class
local super						= TextLabel
local M                         = class(super)

--------------------------------------------------------------------------------
-- The constructor.
-- @param params (option)Parameter is set to Object.<br>
--------------------------------------------------------------------------------
function M:init(params)
    super.init(self)

    params = params or {}
    params = type(params) == "string" and {text = params} or params

    self:copyParams(params)
	
	self.orgSetLoc = self.setLoc
	self.setLoc = self.setLocBack

	self.orgSetSize = self.setSize
	self.setSize = self.setSizeBack
	
	self.orgSetString = self.setString
	self.setString = self.setStringBack
	
	self:setBackgroundRGBA(0.75, 0.75, 0.75, 0.75)
end

function M:setBackgroundRGBA(r, g, b, a)
	if not self._background then
		local width, height = self:getWidth(), self:getHeight()
		local left, top = self:getPos()
		self._background = Graphics {layer=self:getLayer(), width = width, height = height, left = left, top = top}
	else self._background:clear()
	end
	self._background:setPenColor(r, g, b, a):fillRect()
end

function M:setLocBack(left, top)
	self.orgSetLoc(self,left,top)
	if self._background then
		self._background:setLoc(left, top)
	end
end

--------------------------------------------------------------------------------
-- Set the text size.
-- @param width
-- @param height
--------------------------------------------------------------------------------
function M:setSizeBack(width, height)
	self.orgSetSize(self, width, height)
	if self._background then
		self._background:setSize(width, height)
	end
end

function M:setStringBack(text)
	self.orgSetString(self,text)
	if text == "" then
		self._background:setSize(1,1)
	else
		local x,y = self:getLoc()
		--self.orgSetString ( self, text );
		self:fitSize()
		self:setLoc(x,y)
	end
end

return M
