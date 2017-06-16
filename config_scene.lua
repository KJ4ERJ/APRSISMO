module(..., package.seeall)

--local Component = require "hp/gui/Component"

local backAnim
local config

function onCreate(params)
	backAnim = params.backAnimation
	config = params.config
    --createBackgroundLayer()
	config:makeConfigScroller(scene, backAnim)
end

function onStop()
    print("config_scene:onStop()")
	config:fireActions()
end

--[[
function createBackgroundLayer()
    backgroundLayer = Layer {}
    
    backgroundSprite = BackgroundSprite {
        texture = "background.png",
        layer = backgroundLayer,
    }
    
    SceneManager:addBackgroundLayer(backgroundLayer)
end
]]

function onKeyDown(event)
	local key = event.key
	if key == 27 or key == 283 then	-- <ESC>
		config:unconfigure()
	end
end

