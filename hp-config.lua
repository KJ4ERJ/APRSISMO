MOAISim.setStep ( 1 / 30 )
--MOAISim.clearLoopFlags ()
--MOAISim.setLoopFlags ( MOAISim.SIM_LOOP_ALLOW_BOOST )
--MOAISim.setLoopFlags ( MOAISim.SIM_LOOP_LONG_DELAY )
--MOAISim.setBoostThreshold ( 0 )
--MOAISim.setBoostThreshold ( 2 )

TextLabel.DEFAULT_FONT = "arial-rounded.ttf"

local viewWidth, viewHeight = MOAIGfxDevice.getViewSize ()
print(string.format("width=%s height=%s", tostring(viewWidth), tostring(viewHeight)))

local x, y = 640, 480
x = MOAIEnvironment.screenWidth or viewWidth or MOAIEnvironment.horizontalResolution
y = MOAIEnvironment.screenHeight or viewHeight or MOAIEnvironment.verticalResolution
print(string.format("x=%s y=%s", tostring(x), tostring(y)))
if x == nil then x = 800 end
if y == nil then y = 480 end
if x == 0 then x = 1000 end	-- 480
if y == 0 then y = 1000 end	-- 800
if Application:isDesktop() then
	x, y = 1024,480	-- Wide and short
	--x, y = 800, 442	-- Matches the Nexus S resolution!
	--x, y = 516, 274	-- Should be 4x2.125 (1/8) inches @ 129dpi
end

local config = {
    title = MOAIEnvironment.appDisplayName,
    screenWidth = x,
    screenHeight = y,
    mainScene = "splash",
}

return config
