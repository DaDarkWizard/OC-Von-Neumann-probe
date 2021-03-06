local utils = require("utils")
local vec3 = require("vec3")
local VectorChunk = require("vectorchunk")
local inspect = require("inspect")

local VectorMap = {}
VectorMap.__index = VectorMap
VectorMap.fileHeader = "<c4lllc1"
VectorMap.magicString = "CHNK"
VectorMap.extension = "chnk"
VectorMap.chunkFolder= "/home/chunks/"
setmetatable(VectorMap, {__call = function(cls, packValues, allowFloats, chunkSize, storedType)
	local self = {}
	self.chunks = {}
	self.packValues = packValues or false
	self.allowFloats = allowFloats or false
	self.chunkSize = chunkSize or vec3(4096, 256, 4096)
	self.storedType = storedType or "f"
	-- order is important since we're overriding __newindex method!
	-- setmetatable has to be called after setting fields
	setmetatable(self, cls) -- cls is current table: VectorMap
	return self
end })

-- converts vector from global coordinates to local coordinates in a chunk calculated using given chunk offset
local function localFromAbsolute(vector, chunkSize)
    return vector.x % chunkSize.x, vector.y % chunkSize.y, vector.z % chunkSize.z
end

-- calculates global coordinates from local coordinates in a chunk using given chunk offset
local function absoluteFromLocal(vector, offset, chunkSize)
	return vector.x + chunkSize.x * offset.x, vector.y + chunkSize.y * offset.y, vector.z + chunkSize.z * offset.z
end

-- calculates chunk offset from global coordinates
local function offsetFromAbsolute(vector, chunkSize)
	return vector.x // chunkSize.x, vector.y // chunkSize.y, vector.z // chunkSize.z
end

local function packxyz(x, y, z)
	return string.pack("<lll", x, y, z)
end

local function unpackxyz(number)
	return string.unpack("<lll", number)
end

function VectorMap:getHashAndLocalCoords(vector)
	local x, y, z = offsetFromAbsolute(vector, self.chunkSize)
	local chunkHash = packxyz(x, y, z)
	if self.chunks[chunkHash] == nil then
		self.chunks[chunkHash] = VectorChunk(self.packValues, self.allowFloats, vec3(0, 0, 0))
	end
	local localx, localy, localz = localFromAbsolute(vector, self.chunkSize)
	return chunkHash, localx, localy, localz
end

function VectorMap:at(vector)
	local x, y, z = offsetFromAbsolute(vector, self.chunkSize)
	local chunk = self.chunks[packxyz(x, y, z)]
	if chunk ~= nil then
		local localx, localy, localz = localFromAbsolute(vector, self.chunkSize)
		return chunk:atxyz(localx, localy, localz)
	else
		return nil -- return something else, possibly some enum.not_present
	end
end

function VectorMap:atIndex(index)
	for hash, chunk in pairs(self.chunks) do
		local element = chunk:atIndex(index)
		if element then
			return element
		end
	end
end

function VectorMap:set(vector, element)
	local chunkHash, x, y, z = self:getHashAndLocalCoords(vector)
	self.chunks[chunkHash]:setxyz(x, y, z, element)
end

function VectorMap:setIndex(index, vector)
	if vector then
		local chunkHash, x, y, z = self:getHashAndLocalCoords(vector)
		self.chunks[chunkHash]:setIndexXyz(index, x, y, z)
	else
		vector = self:atIndex(index)
		local chunkHash = self:getHashAndLocalCoords(vector)
		self.chunks[chunkHash]:setIndex(index, nil)
	end
end

function VectorMap:getPackFormat(dataFormat)
	return "<" .. dataFormat
end

function VectorMap:getFileName(chunkCoords)
	return self.chunkFolder .. tostring(chunkCoords) .. "." .. self.extension
end

function VectorMap:saveChunk(coords)
	local chunkCoords = vec3(offsetFromAbsolute(coords, self.chunkSize))
	local chunkHash = packxyz(chunkCoords.x, chunkCoords.y, chunkCoords.z)
	local data = string.pack(self.fileHeader, self.magicString, self.chunkSize.x, self.chunkSize.y, self.chunkSize.z, self.storedType)
	local packFormat = self:getPackFormat(self.storedType)
	for x = 0, self.chunkSize.x - 1 do
		for y = 0, self.chunkSize.y - 1 do
			for z = 0, self.chunkSize.z - 1 do
				local block = self.chunks[chunkHash]:atxyz(x, y, z)
				data = data .. string.pack(packFormat, block and block or -1)
			end
		end
	end
	
	local filePath = self:getFileName(chunkCoords)
	local chunkFile = io.open(filePath, "w")
	chunkFile:write(data)
	chunkFile:close()
end

function VectorMap:loadChunk(coords)
	local chunkCoords = vec3(offsetFromAbsolute(coords, self.chunkSize))
	local chunkHash = packxyz(chunkCoords.x, chunkCoords.y, chunkCoords.z)
	local filePath = self:getFileName(chunkCoords)
	local chunkFile = io.open(filePath, "r")
	
	if io.type(chunkFile) == "file" then
		local magicString, chunkSizex, chunkSizey, chunkSizez, dataFormat = string.unpack(self.fileHeader, chunkFile:read(8))

		if magicString == self.magicString and
		chunkSizex == self.chunkSize.x and 
		chunkSizey == self.chunkSize.y and 
		chunkSizez == self.chunkSize.z then
			local packFormat = self:getPackFormat(dataFormat)
			local formatSize = string.packsize(packFormat)
			
			for x = 0, self.chunkSize.x - 1 do
				for y = 0, self.chunkSize.y - 1 do
					for z = 0, self.chunkSize.z - 1 do
						local block = string.unpack(packFormat, chunkFile:read(formatSize))
						self.chunks[chunkHash]:setxyz(x, y, z, block ~= -1 and block or nil)
					end
				end
			end
		end
	end
end

function VectorMap.__index(self, index)
	if utils.isInstance(index, vec3) then
		return self:at(index)
	elseif type(index) == "number" then
		return self:atIndex(index)
	else
		return getmetatable(self)[index] -- gets metatable with methods and metamethods and returns a method
	end
end

function VectorMap.__newindex(self, index, elem)
	if utils.isInstance(index, vec3) then
		self:set(index, elem)
	elseif type(index) == "number" then
        self:setIndex(index, elem)
	else
		rawset(self, index, elem) -- dealing with raw table elements
	end
end

--[[ returns the largest integer that is the index of an element where a nil follows it at index + 1 (note
that this is very inefficient as there's no sensible way of implementing __len operator without cluttering
other parts of the code, so ipairs and pairs should favoured over using __len operator in almost all cases) --]]
function VectorMap.__len(self)
	local n = 1
	while self:atIndex(n) do
		n = n + 1
	end
	return n - 1
end

function VectorMap.__pairs(self)
	local chunk
	local chunkIterator
	local chunkIndex
	chunkIndex, chunk = next(self.chunks, nil)
	if chunk then
		chunkIterator = pairs(chunk)
	end
	local function iterator(self, index)
		if chunkIterator then
			local chunkVector = vec3(unpackxyz(chunkIndex))
			index, element = chunkIterator(chunk, index and vec3(localFromAbsolute(index, self.chunkSize)) or index)
			if element then
				return vec3(absoluteFromLocal(index, chunkVector, self.chunkSize)), element
			else
				chunkIndex, chunk = next(self.chunks, chunkIndex)
				if chunk then
					chunkIterator = pairs(chunk)
					return iterator(self, index)
				end
			end
		end
	end

	return iterator, self, nil
end

function VectorMap:pairs()
    return self.__pairs(self)
end

function VectorMap:ipairs()
	local function statelessIterator(self, index)
        index = index + 1
        local element = self:atIndex(index)
        if element then
            return index, element
        end
    end

    return statelessIterator, self, 0
end

return VectorMap