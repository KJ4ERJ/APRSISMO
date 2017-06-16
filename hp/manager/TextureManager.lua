---------------------------------------------------------------------------------------------------
-- This is a class to manage the Texture.
---------------------------------------------------------------------------------------------------

local ResourceManager = require("hp/manager/ResourceManager")
local Logger = require("hp/util/Logger")

local M = {}
local cache = {}

setmetatable(cache, {__mode = "v"})

M.DEFAULT_FILTER = MOAITexture.GL_LINEAR

----------------------------------------------------------------
-- Requests the texture. <br>
-- The textures are cached internally.
-- @param path path
-- @return MOAITexture instance.
----------------------------------------------------------------
function M:request(path)
    path = ResourceManager:getFilePath(path)

    if cache[path] == nil then
        local texture = MOAITexture.new()
--print("TextureManager:request:loading("..tostring(path)..")")
        texture:load(path)
        texture.path = path
        
        if M.DEFAULT_FILTER then
            texture:setFilter(M.DEFAULT_FILTER)
        end
		local x,y = texture:getSize()
		if x == 0 and y == 0 then
			print('TextureManager:request('..tostring(path)..'):getSize() is 0x0, NOT caching!')
			return texture
		--else
			--print('TextureManager:request('..tostring(path)..'):getSize() is '..tostring(x)..'x'..tostring(y)..', caching!')
		end
        cache[path] = texture
    end
    
    local texture = cache[path]
    return cache[path]
end

return M
