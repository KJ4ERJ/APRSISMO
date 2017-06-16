module(..., package.seeall)

--local Component = require "hp/gui/Component"

local backAnim
local titleText
local values
local entries
local newValue
local default
local forces

local symbols = require("symbols")

function backHandler()
	SceneManager:closeScene({animation = "popOut"})
end

local function buildChooser(newValue)

	local groups = symbols:getSymbolGroups()
	local openGroups = {}

	local scroller, guiView
	local scrollY = -1

	local function buildScroller()

		local width = Application.viewWidth
		if Application.viewWidth > Application.viewHeight then --	landscape, shrink the width
			width = width * 0.75
		end
		local left = (Application.viewWidth-width)/2

		if scroller then
			scroller:removeChildren()
		end

		if not guiView then
			guiView = View {
				left = left,
				width = width,
				scene = scene,
			}
		end
		
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
		--titleBackground:setPenColor(0.707, 0.8125, 0.8125, 0.75):fillRect()	-- 181,208,208 from OSM zoom 0 map
		titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
		--titleBackground:setPriority(2000000000)
		titleGroup:addChild(titleBackground)

		titleLabel = TextLabel {
			text = titleText or "Symbol Chooser",
			textSize=28*config.Screen.scale,
			size = {guiView:getWidth(), 40*config.Screen.scale},
			color = {1, 1, 1},
			parent = titleGroup,
			align = {"center", "center"},
		}
		titleLabel:fitSize()
		titleLabel:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		titleLabel:setLoc(width/2, 20*config.Screen.scale)
		--local x,y = titleText:getSize()
		--titleText:setLoc(width/2, 25*config.Screen.scale)

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

		local colorCategory = { default = { 150/255, 160/255, 180/255 }, }
		local colorRow =  { default = { 192/255, 192/255, 192/255 },
								over = { 30/255, 144/255, 255/255 }, }
		local colorLine = { 220/255, 220/255, 220/255 }
		local heightCategory = 30*config.Screen.scale*2
		local heightValue = 60*config.Screen.scale
		local pad = 5*config.Screen.scale
		
		local openGroup = false
		
		local function addSymbol(s, d)
			button = Group {}

			local titleBackground = Graphics {width = width, height = heightValue, left = 0, top = 0}
			titleBackground:setPenColor(unpack(colorRow.default)):fillRect()
			--titleBackground:setPriority(2000000000)
			button:addChild(titleBackground)

			local rowTitle  = TextLabel{
				text=d,
				textSize = 29*config.Screen.scale,
				size = {guiView:getWidth(), heightValue},
				color = {0,0,0},
				parent=button,
				align = {"center", "top"},
			}
			rowTitle:fitSize()
			rowTitle:setLeft((guiView:getWidth()-rowTitle:getWidth())/2) rowTitle:setTop(0)

			local rowText  = TextLabel{
				text=s,
				textSize = 20*config.Screen.scale,
				size = {guiView:getWidth(), heightValue},
				color = {0,0,0},
				parent=button,
				align = {"center", "bottom"},
			--rowText.y = row.contentHeight - (row.contentHeight - rowTitle.contentHeight) * 0.5
			}
			rowText:fitSize()
			if rowText:getWidth() > guiView:getWidth()-pad*2 then
				rowText:setWidth(guiView:getWidth()-pad*2)
				rowText:setColor(1,0,0)
			end
			rowText:setLeft((guiView:getWidth()-rowText:getWidth())/2) rowText:setBottom(heightValue-2)

			local image = getSymbolImage(s, "NULL-IS")
			local height = image:getHeight()
			local scale = heightValue/height
			scale = image.scale
--			image:setScl(1,1,1)
--			image:setScl(scale, scale, 1)
--			image:setRight(math.min(rowTitle:getLeft(),rowText:getLeft())-2) image:setTop(0)
			image:setParent(button)
--			image:setPos(2+image.width/2*scale,0)
--			image:setPos(math.min(rowTitle:getLeft(),rowText:getLeft())-image.width*scale-2,0)
--			image:setRight(math.min(rowTitle:getLeft(),rowText:getLeft())-2)
--			image:setTop(0)
			image:setCenterPos(math.min(rowTitle:getLeft(),rowText:getLeft())-image:getWidth()*scale-2, heightValue/2)
			
			local image = getSymbolImage(s, "NULL-IS")
			local height = image:getHeight()
			local scale = heightValue/height
			scale = image.scale
--			image:setScl(1,1,1)
--			image:setScl(scale, scale, 1)
--			image:setLeft(math.max(rowTitle:getRight(),rowText:getRight())+2) image:setTop(0)
			image:setParent(button)
--			image:setPos(width-image.width*scale-2,0)
--			image:setPos(math.max(rowTitle:getRight(),rowText:getRight())+2,0)
--			image:setLeft(math.max(rowTitle:getRight(),rowText:getRight())+2)
--			image:setBottom(heightValue)
			image:setCenterPos(math.max(rowTitle:getRight(),rowText:getRight())+image:getWidth()*scale+2, heightValue/2)
			
			button:resizeForChildren()
			button:setParent(scroller)
			button:addEventListener("touchUp",
									function(e)
										if e.isTap then
											newValue(s)
											backHandler()
										end
									end)
			return button
		end

		if default then addSymbol(default, symbols:getSymbolName(default)) end
		if type(forces) == "string" then
			if forces ~= default then
				addSymbol(forces,symbols:getSymbolName(forces))
			end
		elseif type(forces) == "table" then
			for i, s in ipairs(forces) do
				if s ~= default then
					addSymbol(s,symbols:getSymbolName(s))
				end
			end
		end

		for g, t in pairsByKeys(groups) do
			local button
			button = Group {}
			local titleBackground = Graphics {width = guiView:getWidth(), height = heightCategory, left = 0, top = 0}
			titleBackground:setPenColor(unpack(colorCategory.default)):fillRect()
			--titleBackground:setPriority(2000000000)
			button:addChild(titleBackground)

			local rowTitle  = TextLabel{
				text=g.." Symbols",
				textSize = 29*config.Screen.scale,
				size = {guiView:getWidth(), heightValue},
				color = {0,0,0},
				parent=button,
				align = {"center", "top"},
			}
			rowTitle:fitSize()
			rowTitle:setLeft((guiView:getWidth()-rowTitle:getWidth())/2) rowTitle:setTop(0)

			do
				local tprime = {}
				for s,d in pairs(t) do
					tprime[d] = s
				end
				local diff = heightCategory-29*config.Screen.scale
				local xl, xr = rowTitle:getLeft(), rowTitle:getRight()
				local x = 2
				local y = 29*config.Screen.scale+diff/2
				for d,s in pairsByKeys(tprime) do
					local image = getSymbolImage(s,"NULL-IS")
					image:setScl(1,1,1)
					local height = image:getHeight()
					local scale = diff/height
					image:setScl(scale,scale,1)
					image:setParent(button)
					image:setCenterPos(x+image:getWidth()*scale/2, y)
					x = x + image:getWidth()*scale + 1
					if x+image:getWidth()*scale > guiView:getWidth() then
						if y == diff/2 then break end
						x, y = 2, diff/2
					elseif y == diff/2 and x+image:getWidth()*scale-2 >= xl and x+image:getWidth()*scale-2 <= xr then
						x = xr+2
					end
				end
			end

			button:resizeForChildren()
			button:setParent(scroller)
			button:addEventListener("touchUp",
									function(e)
										if e.isTap then
												local x,y = button:getPos()
												openGroups[g] = not openGroups[g]
												scrollY = y - button:getHeight()/2
												buildScroller()
										end
									end)
			openGroup = openGroups[g]
			if openGroup then
				local tprime = {}
				for s,d in pairs(t) do
					tprime[d] = s
				end
				for d,s in pairsByKeys(tprime) do
					local button = addSymbol(s, d)
				end
			end
		end
		scroller:updateLayout()
		local left, top = scroller:clipScrollPosition(0, -scrollY)
		if left == 0 and top == 0 then top = 1 end
		print(string.format("scroll to %d %d", left, top))
		performWithDelay(20,function() scroller:setPos(left, top) end)
	end
	buildScroller()
end

function onCreate(params)

	backAnim = params.backAnimation
	titleText = params.titleText
	newValue = params.newValue
	default = params.default
	forces = params.forces

	scene.backHandler = backHandler
	scene.menuHandler = backHandler

	buildChooser(newValue)
end

function onStop()
    print("file_scene:onStop()")
end

function onKeyDown(event)
	local key = event.key
	if key == 13 or key == 269 then	-- <CR>
		print('file_scene:<CR>')
		backHandler()
	elseif key == 27 or key == 283 then	-- <ESC>
		print('file_scene:<ESC>')
		backHandler()
	end
end

