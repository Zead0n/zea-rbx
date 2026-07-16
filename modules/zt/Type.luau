--!strict

export type TypeInfo = {
	_match: (any) -> (boolean, string?),
	-- _assert: (any) -> any,
}

type TypeMt = {
	__call: (TypeMt, ...any) -> ...any,
	matches: (TypeMt, ...any) -> (boolean, string?),
	assert: (TypeMt, ...any) -> ...any,
}

local Type = {}
Type.__index = Type

type Type = typeof(setmetatable({} :: TypeInfo, Type))

function Type.matches(self: Type, ...: any): (boolean, string?)
	return self._match(...)
end

function Type.assert<T...>(self: Type, ...: T...): T...
	local ok, reason = self:matches(...)
	if not ok then
		error(reason)
	end
	return ...
end

return Type
