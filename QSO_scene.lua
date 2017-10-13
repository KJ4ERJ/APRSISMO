module(..., package.seeall)

----------------------------------------------------------------------------------
--
-- QSO.lua
--
----------------------------------------------------------------------------------
local otp = require("otp")	-- for sending protected commands
local QSOs = require("QSOs")	-- for sending messages and reloading conversation

local tableView = nil

local QSO

local freezeRefresh

local function refresh(event)
	if not freezeRefresh then
		if not event or event.isTap then
			QSOs:refresh(QSO)
		end
	end
end

local function closeScene()
	SceneManager:closeScene({animation="popOut"})
end

-- Called when the scene's view does not exist:
function onCreate( params )
QSO = params.QSO

	scene.backHandler = closeScene
	scene.menuHandler = closeScene

print(printableTable('onCreate:QSO',QSO))

	if QSO.to == 'ANSRVR' and QSO.additional then
		local now = MOAISim.getDeviceTime()
		if not QSO.refreshed or (now-QSO.refreshed) > 30*60 then	-- only every 30 minutes
			local text = 'J '..QSO.additional
--			sendStatus = sendAPRSMessage(QSO.to, text, QSO.additional)
			sendStatus = sendAPRSMessage(QSO.to, text)
			if not sendStatus then QSO.refreshed = now else print('QSO:onCreate:sendStatus(J):'..sendStatus) end
		end
	end
end

-- Called immediately after scene has moved onscreen:
function onStart( )
print(printableTable('onStart:QSO',QSO))
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
        text = QSO.id:gsub("<","<<"), textSize = 28*config.Screen.scale,
        size = {guiView:getWidth(), 50*config.Screen.scale},
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

	local lineColor = { 220/255, 220/255, 220/255 }
	local msgHeight = 36*config.Screen.scale -- 36
	local timeHeight = 14*config.Screen.scale	-- Added to msgHeight if timestamp included
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
			textSize = 28*config.Screen.scale,
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
		local text = TextLabel{
			text=text,
			textSize = 29*config.Screen.scale,
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

	local lastDate = ''
	local lastTime = 0

	local function newMessage(msg, height, color)
		local isRight = (msg.fromTo == QSO.id)
		local doDate, doTime = false, false
		local test
--print('QSO['..tostring(i)..']:'..type(m.when)..'('..tostring(m.when)..')')
		test = os.date('%Y-%m-%d',msg.when)
		if lastDate ~= test then
			lastDate = test
			doDate = true
		end
		test = os.date('%H:%M:%S:',msg.when)
		if test ~= lastTime then
			lastTime = test
			doTime = true
		end
		local timestamp = nil
		if doDate then
			timestamp = os.date('%Y-%m-%d %H:%M:%S',msg.when)
		elseif doTime then
			timestamp = os.date('%H:%M:%S',msg.when)
		end
		if timestamp or msg.ack or msg.acked then
			height = height + timeHeight	-- Make this cell a bit taller for timestamp
		end
		
		local button = Group {}

--[[
#define COLOR_MESSAGE_ADOPTED RGB(0,0,255)
#define COLOR_MESSAGE_SOURCE_DONE RGB(0,192,0)	/* Sent and ack'd */
#define COLOR_MESSAGE_SOURCE_ACK RGB(0xFF,0x8C,0x00)	/* Sent, pending ack */
#define COLOR_MESSAGE_SOURCE_QUEUED RGB(0xFF,0xD7,0x00)	/* Blocked by previous */
#define COLOR_MESSAGE_SOURCE_STALLED RGB(0xDB,0x70,0x93)	/* Exhausted first set */
#define COLOR_MESSAGE_SOURCE_EXHAUSTED RGB(0xC7,0x15,0x85)	/* Exhausted all retries */
#define COLOR_MESSAGE_SOURCE_CANCELLED RGB(0x94,0x00,0xD3)	/* Cancelled by user (or ONE-SHOT) */
#define COLOR_MESSAGE_REPLY RGB(255,0,0)
#define COLOR_MESSAGE_INTRO RGB(192,192,64)
]]
		local status
		if msg.blocked then
			status = "Blocked" color = {0xff/255, 0xd7/255, 0}
		elseif msg.cancelled then
			status = "Cancelled" color = {0x94/255, 0, 0xd3/255}
		elseif msg.rejected then
			status = "Rejected!" color = {0xc7/255, 0x15/255, 0x85/255}
		elseif msg.retries and msg.retries <= 0 then
			status = "No Retries" color = {0xc7/255, 0x15/255, 0x85/255}
		elseif msg.ack and not msg.acked then
			status = "Retry in "..tostring(msg.nextRetry-os.time()).."sec, "..tostring(msg.retries).." left"
			color = {0xff/255, 0x8c/255, 0}
		end

		local titleBackground = Graphics {width = width, height = height+1, left = 0, top = 0}
		titleBackground:setPenColor(unpack(color)):fillRect()
		button:addChild(titleBackground)
		
		local text = TextLabel{
			text=msg.text:gsub("<","<<"),
			textSize = 29*config.Screen.scale,
			size = {width, height},
			color = {0,0,0},
			parent=button,
			align = {"left", "bottom"},
			wordBreak = MOAITextBox.WORD_BREAK_CHAR,
		}
		if #msg.text > 0 then
			text:fitSize()
			local useWidth = guiView:getWidth()-pad*2
			local xs, ys = text:getSize()
			if xs > useWidth then
				local scale = useWidth/xs*0.95
				text:dispose()
				text = TextLabel{
					text=msg.text:gsub("<","<<"),
					textSize = 29*config.Screen.scale*scale,
					size = {guiView:getWidth()/2, heightValue},
					color = {0,0,0},
					parent=button,
					align = {"left", "bottom"},
					wordBreak = MOAITextBox.WORD_BREAK_CHAR,
				}
				text:fitSize()
			end
			--text:setWidth(useWidth)
		end
		
		if isRight then text:setLeft(pad)
		else text:setRight(guiView:getWidth()-pad) end
		--text:setTop((height-text:getHeight())/2)
		
		if type(text.getBaseline) == 'function' then
			local baseline = text:getBaseline()
			print("Height == "..text:getHeight().." Baseline:"..baseline)
			text:setTop(height-baseline-pad)
		else text:setBottom(height)
		end

		if timestamp then
			local timeText = TextLabel{
				text=timestamp,
				textSize = 14*config.Screen.scale,
				size = {width, height},
				color = {64/255,64/255,64/255},
				parent=button,
				align = {"center", "top"},
			}
			timeText:fitSize()
			timeText:setPos(0,0)
			if isRight then timeText:setLeft(pad)
			else timeText:setRight(width-pad) end
			--timeText:setPos(0, 0)	-- Maybe setLoc?
				--timeText.x = w/2
				--timeText.y = timeText.contentHeight/2
		end
		
		local ackText = msg.ack or ""
		if msg.acked then
			ackText = ackText.."="..os.date("%H:%M:%S", msg.acked[1])
			if msg.rejected then
				ackText = 'Rejected'..ackText
			elseif #msg.acked > 1 then
				ackText = ackText.."+"..os.date("%H:%M:%S", msg.acked[#msg.acked])
				if #msg.acked > 2 then
					ackText = ackText.."("..tostring(#msg.acked)..")"
				end
			end
		end
		if #ackText > 0 then
			local timeText = TextLabel{
				text=ackText,
				textSize = 14*config.Screen.scale,
				size = {width, height},
				color = {64/255,64/255,64/255},
				parent=button,
				align = {"center", "top"},
			}
			timeText:fitSize()
			timeText:setPos(0,0)
			if isRight then timeText:setRight(width-pad)
			else timeText:setLeft(pad) end
		end
	
		if status then
			local statusText = TextLabel{
				text=status,
				textSize = 14*config.Screen.scale,
				size = {width, height},
				color = {64/255,64/255,64/255},
				parent=button,
				align = {"center", "top"},
			}
		end

		button:resizeForChildren()
		button:setParent(scroller)
		return button
	end

--	button = newButton("Refresh", qsoHeight, newColor.default)
--	button:addEventListener("touchUp", refresh)

	--newTitle(QSO.id, titleHeight, titleColor.default)

	for i,m in ipairs(QSO) do
		if type(i) == 'number' then	-- ignore the extra pairs
			print('m.fromTo:'..tostring(m.fromTo)..' QSO.id:'..tostring(QSO.id)..' text:'..tostring(m.text))
			button = newMessage(m, msgHeight, m.read and qsoColor.default or qsoColor.new)
			m.read = os.time()
		end
	end

	button = newButton("-", titleHeight, newColor.default)
		--button:addEventListener("touchUp", refresh )
		local backButton = Button {
			text = "Back", textSize = 20,
			alpha = 0.8,
			size = {100, 50},
			parent = button,
			onClick = closeScene,
		}
		backButton:setScl(config.Screen.scale,config.Screen.scale,1)
		backButton:setLeft(0)
		--backButton:setRight(width)
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

	if type(QSO.to) == 'string' then
		local newButton = Button {
			text = "Compose",
			textSize = 20,
			alpha = 0.8,
			size = {120, 50},
			parent = button,
			onClick = function()
					freezeRefresh = true
					SceneManager:openScene("textentry_scene",
					{
						animation = "popIn", backAnimation = "popOut",
						scale = config.Screen.scale,
						size = { Application.viewWidth * 0.95, 300*config.Screen.scale},
						type = DialogBox.TYPE_WARNING,
						title = QSO.id:gsub('<','<<'),
						text = "Enter Text to send",
						value = "",
						buttons = {"Send", "Cancel"},
						onResult = function(e)
							if e.result == 'Send' or e.result == 'Enter' then
								if type(e.value) == 'string' and #e.value > 0 then
									local sendStatus
									if QSO.to == 'ANSRVR' and QSO.additional then
										local text = 'CQ '..QSO.additional..' '..e.value
--										sendStatus = sendAPRSMessage(QSO.to, text, QSO.additional)
										QSOs:newQSOMessage(QSO, "ME", QSO.to, text)
										sendStatus = sendAPRSMessage(QSO.to, text)
									else
										sendStatus = sendAPRSMessage(QSO.to, e.value)
									end
									toast.new(sendStatus or "Message Sent", 5000)
									performWithDelay(100, refresh)
								end
							end
							freezeRefresh = false
						end,
					})
				end}
		newButton:setScl(config.Screen.scale,config.Screen.scale,1)
		newButton:setLeft((width-newButton:getWidth())/2)

		if type(otp) == 'table' and type(otp.secret) == 'table' 
		and QSO.to == config.OTP.Target and config.OTP.Sequence then
			local cmdButton = Button {
				text = "Cmd",
				textSize = 20,
				alpha = 0.8,
				size = {120, 50},
				parent = button,
				onClick = function()
						freezeRefresh = true
						SceneManager:openScene("textentry_scene",
						{
							animation = "popIn", backAnimation = "popOut",
							scale = config.Screen.scale,
							size = { Application.viewWidth * 0.95, 300*config.Screen.scale},
							type = DialogBox.TYPE_WARNING,
							title = QSO.id:gsub('<','<<'),
							text = "Enter Text to send",
							value = "CMD"..otp:getPassword(config.OTP.Sequence or 0).." ",
							buttons = {"Send", "Cancel"},
							onResult = function(e)
								if e.result == 'Send' or e.result == 'Enter' then
									if type(e.value) == 'string' and #e.value > 0 then
										local sendStatus = sendAPRSMessage(QSO.to, e.value)
										toast.new(sendStatus or "Message Sent", 5000)
										performWithDelay(100, refresh)
										config.OTP.Sequence = config.OTP.Sequence + 1
										config:save("OTPSequence")
									end
								end
								freezeRefresh = false
							end,
						})
					end}
			cmdButton:setScl(config.Screen.scale,config.Screen.scale,1)
			cmdButton:setLeft(newButton:getRight())
		end
	end
		
	local minx, miny, maxx, maxy = scroller:scrollBoundaries()
	print('Scroller '..minx..','..miny..' -> '..maxx..','..maxy)
	scroller:ajustScrollSize()
	minx, miny, maxx, maxy = scroller:scrollBoundaries()
	print('Scroller '..minx..','..miny..' -> '..maxx..','..maxy)
	--scroller:scrollTo(0, -2000, 0.25, MOAIEaseType.SOFT_EASE_IN, function() print('Scrolled to bottom') end )	-- scroll to the bottom
	local xsize, ysize = scroller:getSize()
	local px, py = scroller:getParent():getSize()
	print('Scroller is '..xsize..'x'..ysize..' parent is '..px..'x'..py)
	performWithDelay(20,function() scroller:setPos(0,-2000000) end)
end


-- Called when scene is about to move offscreen:
function onStop( )

	if tableView then
		tableView:removeSelf()
		tableView = nil
	end
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

--print('QSO initialized!')
