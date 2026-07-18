--!strict

type TypeInfo = {
	kind: string,
	_match: (any) -> (boolean, string?),
	_literal: string?,
	_chain: { any }?,
}

local Type = {}
Type.__index = Type
Type.__call = function(self: Type, ...)
	return self:matches(...)
end
Type.__tostring = function(self: Type)
	local msg = self.kind
	local chainStrings = self:_chainStrings()

	if chainStrings then
		msg ..= `({table.concat(chainStrings, ", ")})`
	end

	if self._literal then
		msg ..= `("{self._literal}")`
	end

	return msg
end

export type Type = typeof(setmetatable({} :: TypeInfo, Type))

function Type.new(kind: string, matcher: (any) -> (boolean, string?), chain: { Type }?, literal: string?)
	return setmetatable({
		kind = kind,
		_match = matcher,
		_chain = chain,
		_literal = literal,
	}, Type) :: any
end

function Type.isZtType(value: any): boolean
	return typeof(value) == "table" and getmetatable(value) == Type
end

function Type.matches(self: Type, ...: any): (boolean, string?)
	local ok, err = self._match(...)
	return ok, if err then self:_formatErr(err) else nil
end

function Type.assert<T...>(self: Type, ...: T...): T...
	local ok, reason = self:matches(...)
	if not ok then
		error(reason, 2)
	end

	return ...
end

function Type.concatAssert<T...>(self: Type, concatErr: string, ...: T...): T...
	local ok, reason = self:matches(...)
	if not ok then
		error(`{concatErr}{reason}`, 2)
	end

	return ...
end

function Type._chainStrings(self: Type): { string }
	if not self._chain then
		return {}
	end

	local chainStrings = {}
	for _, chainType in self._chain do
		table.insert(chainStrings, tostring(chainType))
	end

	return chainStrings
end

function Type._formatErr(self: Type, msg: string)
	local fixedMsg = msg
	local chainStrings = self:_chainStrings()
	for typeIndex in msg:gmatch("$chain(%d+)") do
		local i = tonumber(typeIndex)
		if not i then
			continue
		end

		local chainString = chainStrings[i]
		if not chainString then
			continue
		end

		fixedMsg = fixedMsg:gsub(`$chain{i}`, chainString)
	end

	return fixedMsg:gsub("$type", tostring(self))
end

return Type
