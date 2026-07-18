--!strict

local Classes = require(script.Classes)
local Type = require(script.Type)
local Raw = require(script.Raw)
local Structure = require(script.Structure)

export type ZtType = Type.Type

local zt = {}

zt.isZtType = Type.isZtType

-- Primitive Types
zt.any = Raw.any
zt.unknown = Raw.unknown
zt.never = Raw.never
zt.nonNil = Raw.nonNil
zt.none = Raw.none
zt.number = Raw.number
zt.string = Raw.string
zt.boolean = Raw.boolean
zt.bool = Raw.bool
zt.vector = Raw.vector
zt.thread = Raw.thread
zt.buffer = Raw.buffer
zt.table = Raw.table
zt.userdata = Raw.userdata

-- Roblox Types
zt.BrickColor = Raw.BrickColor
zt.CFrame = Raw.CFrame
zt.Color3 = Raw.Color3
zt.Enum = Raw.Enum
zt.EnumItem = Raw.EnumItem
zt.Font = Raw.Font
zt.Instance = Raw.Instance
zt.Ray = Raw.Ray
zt.Rect = Raw.Rect
zt.Region3 = Raw.Region3
zt.UDim = Raw.UDim
zt.UDim2 = Raw.UDim2
zt.Vector2 = Raw.Vector2
zt.Vector3 = Raw.Vector3

-- Structured Types
zt.array = Structure.array
zt.dictionary = Structure.dictionary
zt.struct = Structure.struct
zt.tuple = Structure.tuple
zt.vararg = Structure.vararg
zt.union = Structure.union
zt.literal = Structure.literal
zt.stringEnum = Structure.stringEnum
zt.optional = Structure.optional
zt.args = Structure.args
zt.returns = Structure.returns
zt.fn = Structure.fn
zt.wrapFn = Structure.wrapFn
zt.wrapArgsFn = Structure.wrapArgsFn
zt.wrapReturnsFn = Structure.wrapReturnsFn

zt.IsA = function(obj: string)
	local objClass = Classes[obj]
	if not objClass then
		error(`'{obj}' Class type is not valid, or is missing`)
	end

	return Classes[obj]
end

local mt = {
	__call = function<T>(self, structTemplate: T): T
		assert(typeof(structTemplate) == "table", "zt only takes a table to make a struct.")
		return zt.struct(structTemplate)
	end,
}

return setmetatable(zt, mt)
