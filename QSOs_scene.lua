module(..., package.seeall)

local QSOs = require('QSOs')

-- Forward reference for our tableView
--local tableView = nil

local QSOCount

local freezeRefresh

local function refresh(event)
	if not freezeRefresh then
		if not event or event.isTap then
			QSOs:refresh()
		end
	end
end

local function closeScene()
	SceneManager:closeScene({animation="popOut"})
end

-- Called when the scene's view does not exist:
function onCreate( params )

print('QSOs:onCreate')

QSOCount = QSOs:getCount()

scene.backHandler = closeScene
scene.menuHandler = closeScene

end

function onResume(  )
print('QSOs:onResume:QSOs='..QSOs:getCount()..' was '..QSOCount)
if QSOCount ~= QSOs:getCount() then performWithDelay(100,function() refresh() end) end
end

-- Called immediately after scene has moved onscreen:
function onStart(  )
print('QSOs:onStart')

if QSOCount ~= QSOs:getCount()  then
	refresh()
else
	-- Create a Scroller
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
		HScrollEnabled = false,
        layout = VBoxLayout {
            align = {"center", "center"},
			padding = {0,0,0,0},
			--gap = {0,0},
            --padding = {10, 10, 10, 10},
            gap = {1, 1},
        },
    }

	local titleGroup = Group {}

	local titleBackground = Graphics {width = width, height = 50*config.Screen.scale, left = 0, top = 0}
    titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
	titleGroup:addChild(titleBackground)

    titleLabel = TextLabel {
        text = "APRS QSOs", textSize = 28*config.Screen.scale,
        size = {guiView:getWidth(), 50*config.Screen.scale},
        --size = {width, 50},
        color = {1, 1, 1},
        parent = titleGroup,
        align = {"center", "center"},
    }
	titleLabel:fitSize()
	titleLabel:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	titleLabel:setLoc(width/2, 20*config.Screen.scale)

		local button = Button {
			text = "Back", textSize = 20,
			alpha = 0.8,
			size = {100, 50},
			parent = titleGroup,
			onClick = closeScene,
		}
		button:setScl(config.Screen.scale,config.Screen.scale,1)
		button:setLeft(0)
		--button:setRight(width)
		local refreshButton = Button {
			text = "Refresh",
			textSize = 20,
			alpha = 0.8,
			size = {100, 50},
			parent = titleGroup,
			onClick = function() refresh(nil) end
		}
		refreshButton:setScl(config.Screen.scale,config.Screen.scale,1)
		refreshButton:setRight(width)
	
	titleGroup:resizeForChildren()
	titleGroup:setParent(scroller)
	titleGroup:addEventListener("touchUp", function(e) print("QSOs_scene:titleGroup:touchUp!") end)

	local lineColor = { 220/255, 220/255, 220/255 }
	local titleHeight = 50*config.Screen.scale
	local titleColor = { default = { 150/255, 160/255, 180/255, 200/255 }, }
	local qsoHeight = 60*config.Screen.scale
	local qsoColor = { default = { 181/255, 208/255, 208/255 },
						new = { 30/255, 144/255, 255/255 },
						over = { 30/255, 144/255, 255/255 },
					}
	local newColor = { default = { 189/255, 203/255, 220/255 },
						over = { 30/255, 144/255, 255/255 },
					}
	local pad = 5*config.Screen.scale

	local function newTitle(text, height, color)
		button = Group {}
		local titleBackground = Graphics {width = width, height = height, left = 0, top = 0}
		titleBackground:setPenColor(unpack(color)):fillRect()
		button:addChild(titleBackground)
		local text = TextLabel{
			text=text,
			textSize = 29*config.Screen.scale,
			size = {width, height},
			color = {0,0,0},
			parent=button,
			align = {"center", "center"},
		}
		text:fitSize()
		text:setLeft(pad) text:setTop((height-text:getHeight())/2)
		button:resizeForChildren()
		button:setParent(scroller)
		return button
	end
	local function newButton(text, height, color, onRight)
		button = Group {}
		local titleBackground = Graphics {width = width, height = height, left = 0, top = 0}
		titleBackground:setPenColor(unpack(color)):fillRect()
		button:addChild(titleBackground)
print('newButton:text='..tostring(text)..' or '..text:gsub("<","<<"))
		local text = TextLabel{
			text=text:gsub("<","<<"),
			textSize = 22*config.Screen.scale,
			size = {width, height},
			color = {0,0,0},
			parent=button,
			align = {"left", "center"},
		}
		text:fitSize()
		if onRight then text:setRight(width-pad)
		else text:setLeft(pad) end
		text:setTop((height-text:getHeight())/2)
		button:resizeForChildren()
		button:setParent(scroller)
		return button
	end
	
	local Qtitle = newTitle("Active QSOs", titleHeight, titleColor.default)
	local newQButton = Button {
		text = "New",
		textSize = 20,
		alpha = 0.8,
		size = {100, 50},
		parent = Qtitle,
		onClick = function ()
				freezeRefresh = true
				SceneManager:openScene("textentry_scene",
				{
					animation = "popIn", backAnimation = "popOut",
					scale = config.Screen.scale,
					size = { Application.viewWidth * 0.95, 200*config.Screen.scale},
					type = DialogBox.TYPE_WARNING,
					title = "New QSO",
					text = "Enter StationID (Callsign-SSID)",
					value = "",
					buttons = {"OK", "Cancel"},
					onResult = function(e)
						if e.result == 'OK' or e.result == 'Enter' then
							if type(e.value) == 'string' and #e.value > 0 then
								e.value = string.upper(trim(e.value))
								print("Dialog result is: '" .. e.result .. "', index " .. tostring(e.resultIndex)..", value "..tostring(e.value))
								QSOs:newQSO(e.value)
							end
						end
						freezeRefresh = false
					end,
				})
			end
	}
	newQButton:setScl(config.Screen.scale,config.Screen.scale,1)
	newQButton:setRight(width)
	--print('QSOs='..type(QSOs)..'('..tostring(QSOs)..')')
	if QSOs then
		for q,a in QSOs:iterate() do
			if not a.additional or #a.additional == 0 then	-- ANSRVR's go below
				local n, t = QSOs:getMessageCount(a)
				if n > 0 then
					newButton(q..' ('..tostring(t)..' msgs '..tostring(n)..' NEW!)', qsoHeight, qsoColor.new)
				else newButton(q..' ('..tostring(t)..' msgs)', qsoHeight, qsoColor.default)
				end
				button:addEventListener("touchUp",
						function(e) if e.isTap then SceneManager:openScene("QSO_scene", { animation="popIn", QSO = a }) end end)
			end
		end
	else
		newButton("*None*", qsoHeight, newColor.default)
	end
	
	local Atitle = newTitle("ANSRVR (Announcements)", titleHeight, titleColor.default)

	local newAButton = Button {
		text = "New",
		textSize = 20,
		alpha = 0.8,
		size = {100, 50},
		parent = Atitle,
		onClick = function ()
					freezeRefresh = true
					SceneManager:openScene("textentry_scene",
					{
						animation = "popIn", backAnimation = "popOut",
						scale = config.Screen.scale,
						size = { Application.viewWidth * 0.95, 200*config.Screen.scale},
						type = DialogBox.TYPE_WARNING,
						title = "New ANSRVR Group",
						text = "Enter Group Name",
						value = "",
						buttons = {"OK", "Cancel"},
						onResult = function(e)
							if e.result == 'OK' or e.result == 'Enter' then
								if type(e.value) == 'string' and #e.value > 0 then
									e.value = string.upper(trim(e.value))
									print("Dialog result is: '" .. e.result .. "', index " .. tostring(e.resultIndex)..", value "..tostring(e.value))
									QSOs:newQSO('ANSRVR', e.value)
								end
							end
							freezeRefresh = false
						end,
					})
				end
	}
	newAButton:setScl(config.Screen.scale,config.Screen.scale,1)
	newAButton:setRight(width)
	if QSOs then
		for q,a in QSOs:iterate() do
			if a.additional and #a.additional > 0 then	-- ANSRVR's go here
				local n, t = QSOs:getMessageCount(a)
				local n, t = QSOs:getMessageCount(a)
				if n > 0 then
					newButton(q..' ('..tostring(t)..' msgs '..tostring(n)..' NEW!)', qsoHeight, qsoColor.new)
				else newButton(q..' ('..tostring(t)..' msgs)', qsoHeight, qsoColor.default)
				end
				button:addEventListener("touchUp",
						function(e) if e.isTap then SceneManager:openScene("QSO_scene", { animation="popIn", QSO = a }) end end)
			end
		end
	else
		newButton("*None*", qsoHeight, newColor.default)
	end
	newTitle("Saved QSOs (Future)", titleHeight, titleColor.default)
	
		button = newButton("-", titleHeight, newColor.default)
		local refreshButton = Button {
			text = "Refresh",
			textSize = 20,
			alpha = 0.8,
			size = {100, 50},
			parent = button,
			onClick = function() refresh(nil) end
		}
		refreshButton:setScl(config.Screen.scale,config.Screen.scale,1)
		refreshButton:setRight(width)
		local backButton = Button {
			text = "Back",
			textSize = 20,
			alpha = 0.8,
			size = {100, 50},
			parent = button,
			onClick = closeScene
		}
		backButton:setScl(config.Screen.scale,config.Screen.scale,1)
		backButton:setLeft(0)
		--backButton:setRight(width)
	performWithDelay(20,function() scroller:setPos(0,1) end)
end
end

-- Called when scene is about to move offscreen:
function onStop( )

end


-- Called prior to the removal of scene's "view" (display group)
function onDestroy( )

end

function onKeyDown(event)
	local key = event.key
	if key == 27 or key == 283 then	-- <ESC>
		closeScene()
	end
end

