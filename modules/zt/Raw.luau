--!strict

local Type = require(script.Parent.Type)

local function rawMatcher(expectedType: string): (any) -> (boolean, string?)
	return function(value)
		local typeName = typeof(value)
		if typeName ~= expectedType then
			return false, `{expectedType} expected, instead got {typeName}`
		end

		return true
	end
end

local function basicType(expectedType: string)
	return setmetatable({ _match = rawMatcher(expectedType) }, Type) :: any
end

local Raw = {}

Raw.number = basicType("number") :: number
Raw.string = basicType("string") :: string
Raw.boolean = basicType("boolean") :: boolean
Raw.bool = Raw.boolean
Raw.table = basicType("table") :: { any }
Raw.userdata = basicType("userdata") :: { [any]: any }

return Raw
