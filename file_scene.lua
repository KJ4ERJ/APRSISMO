module(..., package.seeall)

--local Component = require "hp/gui/Component"

local backAnim
local titleText
local confirm
local newValue
local scroller, guiView
local match

function backHandler()
	SceneManager:closeScene({animation = "popOut"})
end

	local function buildChooser(dir, newValue, confirm)
		local width = Application.viewWidth
		if Application.viewWidth > Application.viewHeight then --	landscape, shrink the width
			width = width * 0.75
		end
		local left = (Application.viewWidth-width)/2

		dir = MOAIFileSystem.getAbsoluteDirectoryPath(dir)
		local dirs = MOAIFileSystem.listDirectories(dir)
		local files = MOAIFileSystem.listFiles(dir)
		if not dirs then dirs = {} end
		if not files then files = {} end
		table.sort(dirs) table.sort(files)
		local entries = { }
		if not (dir == "/" or dir:sub(2,-1) == ":/") then
			table.insert(entries, {label="..", value=dir.."/..", detail=MOAIFileSystem.getAbsoluteDirectoryPath(dir.."/.."),
						tapBack = function(v) buildChooser(v, newValue, confirm) end})
		end
		for i, d in pairs(dirs) do
			table.insert(entries, {label=d, value=dir.."/"..d, detail=MOAIFileSystem.getAbsoluteDirectoryPath(dir.."/"..d),
						tapBack = function(v) buildChooser(v, newValue, confirm) end})
		end
		for i, f in pairs(files) do
			if not match or f:match(match) then
				local detail = ""
				local attrs, err = lfs.attributes(MOAIFileSystem.getAbsoluteFilePath(dir.."/"..f))
				if attrs then
					if attrs.size then detail = detail..tostring(attrs.size) end
					if attrs.modification then detail = detail.." Mod:"..os.date("%x %X", attrs.modification) end
					if attrs.access then detail = detail.." Acc:"..os.date("%x %X", attrs.access) end
				end
				table.insert(entries, {label=f, value=dir.."/"..f, detail=detail,
						tapBack = function(v)
										print("file_scene:tapBack:"..tostring(v).." confirm:"..tostring(confirm).." newValue:"..tostring(newValue))
										if not confirm or confirm(v) then
											newValue(v)
											backHandler()
										else print("file_scene("..titleText..") confirm rejected "..tostring(v))
										end
									end})
			end
		end

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
		
		for i, e in ipairs(entries) do
			local v = e.value
			local button = Group {}

			local titleBackground = Graphics {width = width, height = heightValue, left = 0, top = 0}
			titleBackground:setPenColor(unpack(colorRow.default)):fillRect()
			button:addChild(titleBackground)

			local text = e.label or tostring(v)
			
			if e.image then
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
			
			if e.detail then
				local rowText  = TextLabel{
										text=e.detail,
										textSize = 20*config.Screen.scale,
										size = {guiView:getWidth(), heightValue},
										color = {0,0,0},
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
				color = {0,0,0},
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

			if type(e.tapBack) == "function" then
				rowValue:addEventListener("touchUp",
						function(event)
							if event.isTap then
								print("file_scene:"..tostring(v)..' tapped!')
								e.tapBack(v)
							end
						end)
			end
		end
		scroller:updateLayout()
		scroller:ajustScrollSize()
		performWithDelay(20,function() scroller:setPos(0,1) end)
	end

function onCreate(params)

	backAnim = params.backAnimation
	titleText = params.titleText
	confirm = params.confirm
	newValue = params.newValue
	match = params.match

	scene.backHandler = backHandler
	scene.menuHandler = backHandler

	local width = Application.viewWidth
	if Application.viewWidth > Application.viewHeight then --	landscape, shrink the width
		width = width * 0.75
	end
	local left = (Application.viewWidth-width)/2

	buildChooser(params.dir or ".", newValue, confirm)
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

