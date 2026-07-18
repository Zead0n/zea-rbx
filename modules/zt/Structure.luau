--!strict

local Type = require(script.Parent.Type)
local Raw = require(script.Parent.Raw)

-- local function checkSingleInput(...): (boolean, string?)
-- 	local args = { ... }
-- 	if #args > 1 then
-- 		return false, "Can only accept 1 argurment"
-- 	end
--
-- 	return Type.isZtType(args[1])
-- end

local function zTypeCheck(...: any): string?
	for i, v in { ... } do
		if not Type.isZtType(v) then
			return `argument #{i}, is not a zType.`
		end
	end

	return
end

local tupleCast: <Out...>(...any) -> Out... = function(...)
	return ...
end

local function tupleTypeCheck<T...>(...): ({ Type.Type }?, boolean?, string?)
	local hasVarg = false
	local types = { ... }

	for index, argType: Type.Type in types do
		if not Type.isZtType(argType) then
			return nil, nil, `tuple: argument #{index} is not a zType.`
		end

		if argType.kind == "tuple" then
			return nil, nil, "tuple: cannot have a tuple within."
		end

		if argType.kind == "vararg" then
			if index == #types then
				hasVarg = true
			else
				return nil, nil, "tuple: vararg type can only be at the end of a tuple."
			end
		end
	end

	return types, hasVarg
end

local Structure = {}

function Structure.dictionary<K, V>(keyType: K, valueType: V): { [K]: V }
	assert(Type.isZtType(keyType), "keyType (argument #1), is not a zType")
	assert(Type.isZtType(keyType), "valueType (argument #2), is not a zType")

	local function matcher(values): (boolean, string?)
		local ok: boolean, result: string? = (Raw.table :: any):matches(values)
		if not ok then
			return false, result
		end

		for key, value in values do
			local keyOk: boolean = (keyType :: any):matches(key)
			if not keyOk then
				return false, `key type '$chain1' expected, got {typeof(key)} instead.`
			end

			local valueOk: boolean = (valueType :: any):matches(value)
			if not valueOk then
				return false, `value type '$chain2' expected, got {typeof(value)} instead.`
			end
		end

		return true
	end

	return Type.new("table", matcher, { keyType :: any, valueType :: any }) :: any
end

function Structure.array<T>(valueType: T): { T }
	assert(Type.isZtType(valueType), "valueType (argument #1), is not a zType")

	return Structure.dictionary(Raw.number, valueType)
end

local function tupleMatcher(types: { Type.Type }, hasVarg: boolean)
	return function(...): (boolean, string?)
		local args = { ... }

		if #args > #types and not hasVarg then
			return false, "tuple exceeds limit"
		end

		for i, elem in args do
			local zType = types[math.min(i, #types)]

			local ok: boolean = (zType :: any):matches(elem)
			if not ok then
				return false, `argument #{i} expected '{tostring(zType)}', got '{typeof(elem)}' instead`
			end
		end

		return true
	end
end
function Structure.tuple<T...>(...: T...): T...
	local err = zTypeCheck(...)
	if err then
		error(err)
	end

	local types, hasVararg, checkErr = tupleTypeCheck(...)
	if not types or hasVararg == nil then
		error(checkErr or "Unknown error while checking tuple")
	end

	local matcher = tupleMatcher(types, hasVararg)
	return tupleCast(Type.new("tuple", matcher, types))
end

function Structure.vararg<T>(valueType: T): ...T
	assert(Type.isZtType(valueType), "valueType (argument #1), is not a zType")

	local function matcher(...): (boolean, string?)
		for i, value in { ... } do
			local ok: boolean = (valueType :: any):matches(...)
			if not ok then
				return false, `vararg argument #{i} is type '{typeof(value)}', '{tostring(valueType)}' expected`
			end
		end

		return true
	end

	return Type.new(`vararg`, matcher, { valueType :: any })
end

function Structure.optional<T>(valueType: T): T?
	assert(Type.isZtType(valueType), "valueType (argument #1), is not a zType")

	local function matcher(value): (boolean, string?)
		if value == nil then
			return true
		end

		local ok: boolean = (valueType :: any):matches(value)
		if not ok then
			return false, `value is type '{typeof(value)}', expected nil or '{tostring(valueType)}'`
		end

		return true
	end

	return Type.new(`optional`, matcher, { valueType :: any })
end

type UnionFunc =
	(<T1, T2>(T1, T2) -> T1 | T2)
	& (<T1, T2, T3>(T1, T2, T3) -> T1 | T2 | T3)
	& (<T1, T2, T3, T4>(T1, T2, T3, T4) -> T1 | T2 | T3 | T4)
	& (<T1, T2, T3, T4, T5>(T1, T2, T3, T4, T5) -> T1 | T2 | T3 | T4 | T5)
	& (<T1, T2, T3, T4, T5, T6>(T1, T2, T3, T4, T5, T6) -> T1 | T2 | T3 | T4 | T5 | T6)
	& (<T>(...T) -> T)

local function unionMatcher(types: { Type.Type })
	return function(value): (boolean, string?)
		for _, ztype in types do
			local ok: boolean, _ = (ztype :: any):matches(value)
			if ok then
				return true
			end
		end

		return false, `value is type '{typeof(value)}', expected $type`
	end
end
local union: UnionFunc = function<T>(...: T): T
	local err = zTypeCheck(...)
	if err then
		error(err)
	end

	local types = { ... }
	local matcher = unionMatcher(types :: any)
	return Type.new("union", matcher, { types :: any })
end :: any
Structure.union = union

function Structure.literal<T>(valueLiteral: T): T
	local literalStr = if typeof(valueLiteral) == "string"
		then string.format("%q", valueLiteral)
		else tostring(valueLiteral)

	local function matcher(value): (boolean, string?)
		if value ~= valueLiteral then
			return false, `value is '{tostring(value)}', expected '{literalStr}'`
		end

		return true
	end

	return Type.new(`literal`, matcher, nil, literalStr)
end

function Structure.stringEnum(...: string): string
	local types: { Type.Type } = {}
	for _, validValue in { ... } do
		table.insert(types, Structure.literal(validValue) :: any)
	end

	return Structure.union(table.unpack(types)) :: any
end

function Structure.args<T...>(...: T...): (T...) -> ()
	return Structure.tuple(...) :: any
end

function Structure.returns<T...>(...: T...): () -> T...
	return Structure.tuple(...) :: any
end

function Structure.fn<Args..., Rets...>(args: (Args...) -> (), returns: () -> Rets...): (Args...) -> Rets...
	assert(Type.isZtType(args), "args must be zType. Use zt.args to specify args.")
	assert(Type.isZtType(returns), "returns must be zType. Use zt.returns to specify returns.")

	local function matcher(value): (boolean, string?)
		local valueTypeName = typeof(value)
		if valueTypeName ~= "function" then
			return false, `'function' expected, got {valueTypeName} instead.`
		end

		return true
	end

	return Type.new("function", matcher)
end

function Structure.wrapFn<Args..., Rets...>(args: (Args...) -> (), returns: () -> Rets..., fn: (Args...) -> Rets...): (Args...) -> Rets...
	assert(Type.isZtType(args), "args must be zType. Use zt.args to specify args.")
	assert(Type.isZtType(returns), "returns must be zType. Use zt.returns to specify returns.")

	return function(...)
		(args :: any):concatAssert("function arguments: ", ...)
		return (returns :: any):concatAssert("function returns: ", (fn :: any)(...))
	end :: any
end

function Structure.wrapArgsFn<Args...>(args: (Args...) -> (), fn: (Args...) -> ...any): (Args...) -> ...any
	assert(Type.isZtType(args), "args must be zType. Use zt.args to specify args.")

	return function(...)
		(args :: any):concatAssert("function arguments: ", ...)
		return (fn :: any)(...)
	end :: any
end

function Structure.wrapReturnsFn<Rets...>(returns: () -> Rets..., fn: (...any) -> Rets...): (...any) -> Rets...
	assert(Type.isZtType(returns), "returns must be zType. Use zt.returns to specify returns.")

	return function(...)
		return (returns :: any):concatAssert("function returns: ", (fn :: any)(...))
	end :: any
end

function Structure.struct<T>(template: T): T
	assert(typeof(template) == "table", "expected a table to create struct")

	local literalTemplate = {}
	local genericTemplate = {}
	for keyType, elemType in template :: any do
		if not Type.isZtType(elemType) then
			error(`value of '{tostring(keyType)}' is not, zType`, 2)
		end

		if not Type.isZtType(keyType) then
			literalTemplate[keyType] = elemType
			continue
		end

		local existingGenericKey = genericTemplate[keyType]
		if existingGenericKey then
			warn(
				debug.traceback(
					`failed to set generic key type '{tostring(keyType)}'.\n'{tostring(existingGenericKey)}' already assigned.`,
					2
				)
			)
			continue
		end

		genericTemplate[keyType] = elemType
	end

	local function matcher(value): (boolean, string?)
		local isTable: boolean, result: string? = (Raw.table :: any):matches(value)
		if not isTable then
			return false, result
		end

		local missingLiterals = {}
		for literal, elemType in literalTemplate do
			if elemType.kind == "nil" or elemType.kind == "optional" then
				table.insert(missingLiterals, literal)
			end
		end

		local errors = {}
		for key, elem in value do
			-- Check literal key value
			local elemType = (template :: any)[key] :: Type.Type
			if elemType then
				local ok: boolean = elemType:matches(elem)
				if not ok then
					table.insert(errors, `'{tostring(key)}' key is type {typeof(elem)}, expected {tostring(elemType)}`)
				end

				table.remove(missingLiterals, table.find(missingLiterals, key))
				continue
			end

			-- Check generic key value
			local validGenericKey = false
			for genericKeyType: Type.Type, genericElemType: Type.Type in genericTemplate do
				local matchesKey = genericKeyType:matches(key)
				if not matchesKey then
					continue
				end

				validGenericKey = true
				local matchesElem = genericElemType:matches(elem)
				if not matchesElem then
					table.insert(
						errors,
						`generic key '{tostring(genericKeyType)}' has value type '{typeof(elem)}'. expected '{tostring(
							genericElemType
						)}'`
					)
				end

				break
			end

			if not validGenericKey then
				table.insert(errors, `key {tostring(key)} does not have a valid field name or generic type`)
			end
		end

		for _, missingLiteral in missingLiterals do
			table.insert(errors, `'{tostring(missingLiteral)}' is missing.`)
		end

		local isValid = #errors <= 0
		return isValid,
			if not isValid
				then `'{typeof(value)}' does not match struct, errors:\n{table.concat(errors, "\n")}`
				else nil
	end

	return Type.new("table", matcher)
end

return Structure
