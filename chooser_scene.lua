module(..., package.seeall)

local colors = require("colors");

--local Component = require "hp/gui/Component"

local backAnim
local titleText
local values
local entries
local newValue

function backHandler()
	SceneManager:closeScene({animation = "popOut"})
end

function onCreate(params)
	backAnim = params.backAnimation
	titleText = params.titleText
	values = params.values
	entries = params.entries
	newValue = params.newValue

	scene.backHandler = backHandler
	scene.menuHandler = backHandler

	if not values then
		values = {}
		for i,e in ipairs(entries) do
			values[i] = entries[i].value
		end
	end

	local width = Application.viewWidth
	if Application.viewWidth > Application.viewHeight then --	landscape, shrink the width
		width = width * 0.75
	end
	local left = (Application.viewWidth-width)/2

    guiView = View {
		left = left,
		width = width,
        scene = scene,
    }
    
    scroller = Scroller {
        parent = guiView,
        --hBounceEnabled = false,
		HScrollEnabled = false,
        layout = VBoxLayout {
            align = {"center", "center"},
			padding = {0,0,0,0},
			--gap = {0,0},
            --padding = {10, 10, 10, 10},
            --gap = {4, 4},
            gap = {1, 1},
        },
    }

	local titleGroup = Group {}

	local titleBackground = Graphics {width = width, height = 40*config.Screen.scale, left = 0, top = 0}
    titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
	titleGroup:addChild(titleBackground)

    titleLabel = TextLabel {
        text = titleText,
		textSize=28*config.Screen.scale,
        size = {guiView:getWidth(), 40*config.Screen.scale},
        color = {1, 1, 1},
        parent = titleGroup,
        align = {"center", "center"},
    }
	titleLabel:fitSize()
	titleLabel:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	titleLabel:setLoc(width/2, 20*config.Screen.scale)

	if Application:isDesktop() then
		local button = Button {
			text = "Back", textSize=20, --13*config.Screen.scale,
			alpha = 0.8,
			--size = {100*config.Screen.scale, 40*config.Screen.scale},
			size = {100, 40},
			parent = titleGroup,
			onClick = function() backHandler() end,
		}
		button:setScl(config.Screen.scale,config.Screen.scale,1)
		button:setRight(width)
	end
	
	titleGroup:resizeForChildren()
	titleGroup:setParent(scroller)

	local colorRow =  { default = { 192/255, 192/255, 192/255 },
							over = { 30/255, 144/255, 255/255 }, }
	local colorLine = { 220/255, 220/255, 220/255 }
	local heightValue = 60*config.Screen.scale
	local pad = 5*config.Screen.scale
	
	for i, v in ipairs(values) do
        local button
		button = Group {}

		local titleBackground = Graphics {width = width, height = heightValue, left = 0, top = 0}
		titleBackground:setPenColor(unpack(colorRow.default)):fillRect()
		button:addChild(titleBackground)

		local text = (entries and entries[i] and entries[i].label) or tostring(v)
		local textcolor = {0,0,0}
		if entries and entries[i] and entries[i].labelcolor then
			if type(entries[i].labelcolor) == 'table' then
				textcolor = entries[i].labelcolor
			else textcolor = colors:getColorArray(tostring(entries[i].labelcolor))
			end
			if not textcolor or type(textcolor) ~= 'table' or #textcolor ~= 3 then
				textcolor = {0,0,0}
			else
				textcolor = {textcolor[1]/255,textcolor[2]/255,textcolor[3]/255}
			end
		end
		
		if entries and entries[i] and entries[i].image then
			local icon = Sprite { texture=entries[i].image, parent=button, align = {"left","center"} }
			local x, y = icon:getSize()
			if x > 0 and y > 0 then
				local scale = math.min(width/x,heightValue/y)
				icon:setScl(scale, scale, 1)
				icon:setPos(-(x-x*scale)/2, -(y-y*scale)/2)
			end
			--icon:setPos(0,0)
			--icon:setPos(pad, pad)
			--icon:setLeft(1) icon:setTop(1)
		end                                           
		
		if entries and entries[i] and entries[i].detail then
			local detailcolor = {0,0,0}
			if entries[i].detailcolor then
				if type(entries[i].detailcolor) == 'table' then
					detailcolor = entries[i].detailcolor
				else detailcolor = colors:getColorArray(tostring(entries[i].detailcolor))
				end
				if not detailcolor or type(detailcolor) ~= 'table' or #detailcolor ~= 3 then
					detailcolor = {0,0,0}
				else
					detailcolor = {detailcolor[1]/255,detailcolor[2]/255,detailcolor[3]/255}
				end
			end
			local rowText  = TextLabel{
									text=entries[i].detail,
									textSize = 20*config.Screen.scale,
									size = {guiView:getWidth(), heightValue},
									color = detailcolor,
									parent=button,
									align = {"center", "bottom"},
								}
			rowText:fitSize()
			rowText:setLeft(guiView:getWidth()/2-rowText:getWidth()/2) rowText:setBottom(heightValue)
		end

		local rowValue = TextLabel{
			text=text,
			textSize = 36*config.Screen.scale,
			size = {guiView:getWidth()/2, heightValue},
			color = textcolor,
			parent=button,
			align = {"center", "top"},
			wordBreak = MOAITextBox.WORD_BREAK_CHAR,
		}
		if #text > 0 then
			rowValue:fitSize()
			
			local useWidth = guiView:getWidth()-pad*2
			local xs, ys = rowValue:getSize()
			if xs > useWidth then
				print(text..' is '..tostring(xs)..'x'..tostring(ys)..' vs '..useWidth..'x'..heightValue)
				local scale = useWidth/xs*0.95
				rowValue:dispose()
				rowValue = TextLabel{
					text=text,
					textSize = 36*config.Screen.scale*scale,
					size = {guiView:getWidth()/2, heightValue},
					color = {0,0,0},
					parent=button,
					align = {"center", "center"},
					wordBreak = MOAITextBox.WORD_BREAK_CHAR,
				}
				rowValue:fitSize()
			end
			rowValue:setWidth(useWidth)
		end
		rowValue:setRight(guiView:getWidth()-pad)
		rowValue:setTop(-2)
		button:resizeForChildren()
		button:setParent(scroller)

		rowValue:addEventListener("touchUp",
				function(e)
					if e.isTap then
						print(tostring(v)..' tapped!')
						newValue(v, entries and entries[i] or nil)
						backHandler()
					end
				end)
	end
	performWithDelay(20,function() scroller:setPos(0,1) end)
end

--[[
self.unconfigure = function (self)
	if childScene then
		print('removing childScene:'..tostring(childScene)..' with '..(actions and #actions or 0)..' pending actions')
		SceneManager:closeScene({animation = "popOut"})
		childScene = nil
		return true
	end
	return false
end
]]

--[[
self.configure = function (self, removeIt, yOffset)	-- true will only remove if visible
	if not self.unconfigure(self) and not removeIt then
		childScene = SceneManager:openScene("config_scene", {config=self, animation = "popIn", backAnimation = "popOut", })
	end
end
]]

function onStop()
    print("chooser_scene:onStop()")
end

function onKeyDown(event)
	local key = event.key
	if key == 13 or key == 269 then	-- <CR>
		print('chooser_scene:<CR>')
		backHandler()
	elseif key == 27 or key == 283 then	-- <ESC>
		print('chooser_scene:<ESC>')
		backHandler()
	end
end

