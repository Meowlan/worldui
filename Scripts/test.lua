Test = class()

local function vecAbs(a)
	return sm.vec3.new(math.abs(a.x), math.abs(a.y), math.abs(a.z))
end

function Test:voxel( position)
    local shape = self.shape
    local bounds = shape.localRotation * (shape:getBoundingBox() * 4)

    local a, b = shape.localPosition + bounds, shape.localPosition

    local pos = sm.vec3.new(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
    bounds = vecAbs(bounds)

    pos = pos + shape.localRotation * position
    local block = shape.body:createBlock(sm.uuid.new("a6c6ce30-dd47-4587-b475-085d55c6a3b4"), sm.vec3.one(), pos, true)
    return block
end

function Test:createMengerSponge(x, y, z, size, depth)
    if depth == 0 then
        self:voxel(sm.vec3.new(x, y, z))
    else
        local newSize = size / 3
        for dx = 0, 2 do
            for dy = 0, 2 do
                for dz = 0, 2 do
                    local skipCenter = (dx == 1 and dy == 1 and dz == 1) or 
                    (dx == 1 and dy == 1 and (dz == 2 or dz == 0)) or
                    (dx == 1 and dz == 1 and (dy == 2 or dy == 0)) or
                    (dy == 1 and dz == 1 and (dx == 2 or dx == 0))

                    local nx, ny, nz = x + dx * newSize, y + dy * newSize, z + dz * newSize

                    local outerwallonly = true--nx == 0 or ny == 0 or nz == 0
                    local splice = dx == 0 or dy == 0 or dz == 0
                    if not skipCenter and outerwallonly and splice then
                        self:createMengerSponge(nx, ny, nz, newSize, depth - 1)
                    end
                end
            end
        end
    end
end

function Test:server_onCreate()
    for _, body in ipairs(sm.body.getAllBodies()) do
        for _, shape in ipairs(body:getShapes()) do
            if shape.isBlock then
                shape:destroyShape()
            end
        end
    end

    local depth = 4
    local size = 3^depth
    self:createMengerSponge(0, 0, 0, size, depth)
end

function Test:server_onRefresh()
    self:server_onCreate()
end