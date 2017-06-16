module(..., package.seeall)

local timeout = 2000
--timeout = 60*1000

function onEnterFrame()
    --print("onEnterFrame()")
end

function onKeyDown(event)
    print("splash:onKeyDown(event)")
end

function onKeyUp(event)
    print("splash:onKeyUp(event)")
end

function onTouchDown(event)
--    print("splash:onTouchDown(event)@"..tostring(wx)..','..tostring(wy)..printableTable(' onTouchDown', event))
end

function onTouchUp(event)
--    print("splash:onTouchUp(event)@"..tostring(wx)..','..tostring(wy)..printableTable(' onTouchUp', event))
--    SceneManager:closeScene({animation = "popOut"})
end

function onTouchMove(event)
    --print("splash:onTouchMove(event)")
end

function gotoMap()
	print('splash:opening APRSmap')
	SceneManager:openScene("APRSmap")
	print('splash:opened APRSmap')
end

local function resizeHandler ( width, height )
	layer:setSize(width,height)
	if titleBackground then
		titleGroup:removeChild(titleBackground)
		titleBackground:dispose()
	end
--    titleBackground = Mesh.newRect(0, 0, width, 40, titleGradientColors )
	titleBackground = Graphics {width = width, height = 40, left = 0, top = 0}
    --titleBackground:setPenColor(0.707, 0.8125, 0.8125, 0.75):fillRect()	-- 181,208,208 from OSM zoom 0 map
    titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
	titleBackground:setPriority(2000000000)
	titleGroup:addChild(titleBackground)
	local x,y = titleText:getSize()
	titleText:setLoc(width/2, 25)
	image:setLoc(width/2, height/2)
end

function onCreate(e)
	print('splash:onCreate')
	local width, height = Application.viewWidth, Application.viewHeight

    layer = Layer {scene = scene, touchEnabled = true }
	
	scene.resizeHandler = resizeHandler

    titleGroup = Group()
	titleGroup:setLayer(layer)

	titleGradientColors = { "#BDCBDC", "#BDCBDC", "#897498", "#897498" }
--	local colors = { "#DCCBBD", "#DCCBBD", "#987489", "#987489" }

    -- Parameters: left, top, width, height, colors
    --titleBackground = Mesh.newRect(0, 0, width, 40, titleGradientColors )
	titleBackground = Graphics {width = width, height = 40, left = 0, top = 0}
    --titleBackground:setPenColor(0.707, 0.8125, 0.8125, 0.75):fillRect()	-- 181,208,208 from OSM zoom 0 map
    titleBackground:setPenColor(0.25, 0.25, 0.25, 0.75):fillRect()	-- dark gray like Android
	titleBackground:setPriority(2000000000)
	titleGroup:addChild(titleBackground)

	titleText = TextLabel { text="APRSISMO", textSize=28 }
	titleText:fitSize()
	titleText:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	titleText:setLoc(width/2, 20)
	titleText:setPriority(2000000001)
	titleGroup:addChild(titleText)
	titleGroup:addEventListener("touchDown", gotoMap)

	if type(layer.setClearColor) == 'function' then layer:setClearColor ( 181/255, 208/255, 208/255, 1 ) else print('setClearColor='..type(layer.setClearColor)) end
    image = Sprite {texture = "icon-google.png", layer = layer, left = 0, top = 0}
	local x,y = image:getSize()
	print('icon-google.png is '..tostring(x)..'x'..tostring(y)..' screen:'..tostring(width)..'x'..tostring(height))
	image:setLoc(width/2, height/2)
	image:setPriority(2000000000)
	image:addEventListener("touchDown", gotoMap)

--[[
	display.newText(splashScreen, 'Tap to Begin', 0, 0, native.systemFont, 28)
	splashScreen[2].x = display.contentWidth/2
	splashScreen[2].y = splashScreen[1].y + splashScreen[1].contentHeight/2 - splashScreen[2].contentHeight/2
	splashScreen[2]:setTextColor(0,0,0)
	splashScreen:toBack()
	splashScreen:addEventListener( "touch", gotoMap )
]]

end

function onStart()
	--image:moveRot ( 0,0,360,1.5 )
    print("splash:onStart()")
	if MOAIEnvironment.appVersion and #MOAIEnvironment.appVersion > 0 then
		versionToast = toast.new(MOAIEnvironment.appDisplayName..' '..tostring(MOAIEnvironment.appVersion or ''), timeout, nil, gotoMap)
	else 	mapTimer = performWithDelay(timeout, gotoMap)
	end
end

function onResume()
    print("splash:onResume()")
end

function onPause()
    print("splash:onPause()")
end

function onStop()
    print("splash:onStop()")
	toast.destroy(versionToast, true)
end

function onDestroy()
    print("splash:onDestroy()")
end

