local function copyArray<T>(array: { T }, deep: boolean?): { T }
	local new = table.clone(array)

	if deep then
		for index, value in ipairs(array) do
			if type(value) == "table" then
				new[index] = copyArray(value, true)
			end
		end
	end

	return new
end

local function copyDictionary<K, T>(dictionary: { [K]: T }, deep: boolean?): { [K]: T }
	local new = table.clone(dictionary)

	if deep then
		for key, value in pairs(dictionary) do
			if type(value) == "table" then
				new[key] = copyDictionary(value, deep)
			end
		end
	end

	return new
end

local Array = {}
Array.__index = Array

export type Array<T> = typeof(setmetatable({} :: { array: { T } }, Array))

function Array.new<T>(array: { T }): Array<T>
	local self = setmetatable({}, Array) :: Array<T>
	self.array = array
	return self
end

function Array.map<T, R>(self: Array<T>, transform: (T, number, { T }) -> R?): Array<R>
	local newArray: { R } = {}

	for idx, value in ipairs(self.array) do
		local newValue = transform(value, idx, self.array)

		if newValue ~= nil then
			table.insert(newArray, newValue)
		end
	end

	return Array.new(newArray)
end

function Array.filter<T>(self: Array<T>, predicate: (T, number, { T }) -> boolean): Array<T>
	local newArray: { T } = {}

	for idx, value in ipairs(self.array) do
		if predicate(value, idx, self.array) then
			table.insert(newArray, value)
		end
	end

	return Array.new(newArray)
end

function Array.copy<T>(self: Array<T>, deep: boolean?): Array<T>
	return Array.new(copyArray(self.array, deep))
end

function Array.collect<T>(self: Array<T>): { T }
	return self.array
end

local Iter = {}

Iter.array = Array.new

return Iter
