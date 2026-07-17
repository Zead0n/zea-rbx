--!strict

local Type = require(script.Type)
local Raw = require(script.Raw)

local function zTypeCheck(...: any): string?
	for i, v in { ... } do
		if not Type.isZtType(v) then
			return `argument {i} isn't a ZType.`
		end
	end

	return
end

local function typeKindList(types: { Type.Type<> }): { string }
	local strings: { string } = {}
	for _, ztype in types do
		table.insert(strings, ztype.kind)
	end
	return strings
end

local tupleCast: <Out...>(...any) -> Out... = function(...)
	return ...
end

local function tupleTypeCheck<T...>(...): ({ Type.Type<any> }?, boolean?, string?)
	-- local args: { [number]: any, n: number } = table.pack(...)
	local hasVarg = false
	local types = { ... }

	for index, argType: Type.Type<any> in types do
		-- local argType: Type.Type<any> = args[index] :: any
		if not Type.isZtType(argType) then
			continue
		end

		if argType.kind == "tuple" then
			return nil, nil, "tuple cannot have a tuple within."
		end

		if argType.kind == "vararg" then
			if index == #types then
				hasVarg = true
			else
				return nil, nil, "vararg type can only be at the end of a tuple."
			end
		end
	end

	return types, hasVarg
end

local zt = {}

zt.isZtType = Type.isZtType

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

function zt.dictionary<K, V>(keyType: K, valueType: V): { [K]: V }
	local err = zTypeCheck(keyType, valueType)
	if err then
		error(err)
	end

	local function matcher(values): (boolean, string?)
		local ok: boolean, result: string? = (zt.table :: any):matches(values)
		if not ok then
			return false, result
		end

		for key, value in values do
			local keyOk: boolean, keyResult: string? = (keyType :: any):matches(key)
			if not keyOk then
				return false, `key type error: '{keyResult}'`
			end

			local valueOk: boolean, valueResult: string? = (valueType :: any):matches(value)
			if not valueOk then
				return false, `value type error: {valueResult}`
			end
		end

		return true
	end

	return Type.new("table", matcher) :: any
end

function zt.array<T>(v: T): { T }
	local err = zTypeCheck(v)
	if err then
		error(err)
	end

	return zt.dictionary(zt.number, v)
end

local function tupleMatcher(types: { Type.Type<any> }, hasVarg: boolean)
	return function(...): (boolean, string?)
		-- local values = table.pack(value)

		for i, elem in { ... } do
			if i > #types and not hasVarg then
				return false, "tuple exceeds limit"
			end

			-- local elem: any = values[i]
			local zType: Type.Type<any> = types[math.min(i, #types)]

			local ok: boolean, result: string? = zType:matches(elem)
			if not ok then
				return false, `tuple argument {i} error: {result}`
			end
		end

		return true
	end
end
function zt.tuple<T...>(...: T...): T...
	local err = zTypeCheck(...)
	if err then
		error(err)
	end

	local types, hasVarg, checkErr = tupleTypeCheck(...)
	if not types or not hasVarg then
		error(checkErr or "Unknown error while checking tuple")
	end

	-- local function matcher(value): (boolean, string?)
	-- 	local values = table.pack(value)
	--
	-- 	for i = 1, values.n do
	-- 		if i > #types and not hasVarg then
	-- 			return false, "tuple exceeds limit"
	-- 		end
	--
	-- 		local elem: any = values[i]
	-- 		local zType: Type.Type<any> = types[math.min(i, #types)]
	--
	-- 		local ok: boolean, result: string? = zType:matches(elem)
	-- 		if not ok then
	-- 			return false, `tuple type error: {result}`
	-- 		end
	-- 	end
	--
	-- 	return true
	-- end

	local matcher = tupleMatcher(types, hasVarg)
	return tupleCast(Type.new("tuple", matcher))
end

function zt.vararg<T>(valueType: T): ...T
	local err = zTypeCheck(valueType)
	if err then
		error(err)
	end

	local function matcher(...): (boolean, string?)
		for _, value in { ... } do
			local ok: boolean, result: string? = (valueType :: any):matches(...)
			if not ok then
				return false, `vararg type error: {result}`
			end
		end

		return true
	end

	return Type.new(`vararg({(valueType :: any).kind})`, matcher)
end

function zt.optional<T>(valueType: T): T?
	local err = zTypeCheck(valueType)
	if err then
		error(err)
	end

	local function matcher(value): (boolean, string?)
		if value == nil then
			return true
		end

		local ok: boolean, result: string? = (valueType :: any):matches(value)
		if not ok then
			return false, `optional type error: \n{result}`
		end

		return true
	end

	return Type.new(`optional({(valueType :: any).kind})`, matcher)
end

type UnionFunc =
	(<T1, T2>(T1, T2) -> T1 | T2)
	& (<T1, T2, T3>(T1, T2, T3) -> T1 | T2 | T3)
	& (<T1, T2, T3, T4>(T1, T2, T3, T4) -> T1 | T2 | T3 | T4)
	& (<T1, T2, T3, T4, T5>(T1, T2, T3, T4, T5) -> T1 | T2 | T3 | T4 | T5)
	& (<T1, T2, T3, T4, T5, T6>(T1, T2, T3, T4, T5, T6) -> T1 | T2 | T3 | T4 | T5 | T6)
	& (<T>(...T) -> T)

local function unionMatcher(types: { Type.Type<any> }, kinds: { string })
	return function(value): (boolean, string?)
		for _, ztype in types do
			local ok: boolean, _ = (ztype :: any):matches(value)
			if ok then
				return true
			end
		end

		local msg = table.concat(kinds, ",\n")
		return false, `union type error, must match with one of the following:\n{msg}`
	end
end
local union: UnionFunc = function<T>(...: T): T
	local err = zTypeCheck(...)
	if err then
		error(err)
	end

	local types = { ... }

	local typeKinds = typeKindList(types :: any)
	local matcher = unionMatcher(types :: any, typeKinds)
	return Type.new(`union({table.concat(typeKinds, ",")})`, matcher)
end :: any
zt.union = union

function zt.literal<T>(valueLiteral: T): T
	local literalStr
	if typeof(valueLiteral) == "string" then
		literalStr = string.format("%q", valueLiteral)
	else
		literalStr = tostring(valueLiteral)
	end

	local function matcher(value): (boolean, string?)
		if value ~= valueLiteral then
			return false, `value must match literal '{literalStr}'`
		end

		return true
	end

	return Type.new(`literal({literalStr})`, matcher)
end

function zt.stringEnum(...: string): string
	local types: { Type.Type<> } = {}
	for _, validValue in { ... } do
		table.insert(types, zt.literal(validValue) :: any)
	end

	return zt.union(table.unpack(types)) :: any
end

return zt
