--!strict

type TypeInfo = {
	kind: string,
	_match: (any) -> (boolean, string?),
	_chain: { any },
}

local Type = {}
Type.__index = Type

export type Type<T...> = typeof(setmetatable({} :: TypeInfo, Type))

function Type.new(kind: string, matcher: (any) -> (boolean, string?), chain: { Type<any> }?)
	return setmetatable({ kind = kind, _match = matcher, _chain = chain }, Type) :: any
end

function Type.isZtType(value: any): boolean
	return typeof(value) == "table" and getmetatable(value) == Type
end

function Type.matches<T...>(self: Type<T...>, ...: any): (boolean, string?)
	return self._match(...)
end

function Type.assert<T...>(self: Type<T...>, ...): T...
	local ok, reason = self:matches(...)
	if not ok then
		error(reason)
	end
	return ...
end

return Type
