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

local Dictionary = {}
Dictionary.__index = Dictionary

export type Dictionary<K, V> = typeof(setmetatable({} :: { dictionary: { [K]: V } }, Dictionary))

function Dictionary.new<K, V>(dict: { [K]: V }): Dictionary<K, V>
	local self = setmetatable({}, Dictionary) :: Dictionary<K, V>
	self.dictionary = dict
	return self
end

function Dictionary.keys<K, V>(self: Dictionary<K, V>): { K }
	local keys: { K } = {}

	for key, _ in pairs(self.dictionary) do
		table.insert(keys, key)
	end

	return keys
end

function Dictionary.values<K, V>(self: Dictionary<K, V>): { V }
	local values: { V } = {}

	for _, value in pairs(self.dictionary) do
		table.insert(values, value)
	end

	return values
end

function Dictionary.map<K, V, X, Y>(self: Dictionary<K, V>, callback: (V, K, { [K]: V }) -> (X?, Y?)): Dictionary<Y, X>
	local newDict: { [Y]: X } = {}

	for key, value in pairs(self.dictionary) do
		local newValue = callback(value, key, self.dictionary)

		if newValue ~= nil then
			newDict[key] = newValue
		end
	end

	return Dictionary.new(newDict)
end

function Dictionary.filter<K, V>(self: Dictionary<K, V>, callback: (V, K, { [K]: V }) -> boolean): Dictionary<K, V>
	local newDict: { [K]: V } = {}

	for key, value in pairs(self.dictionary) do
		if callback(value, key, self.dictionary) then
			newDict[key] = value
		end
	end

	return Dictionary.new(newDict)
end

function Dictionary.findKey<K, V>(self: Dictionary<K, V>, callback: (V, K, { [K]: V }) -> boolean): K?
	for key, value in pairs(self.dictionary) do
		if callback(value, key, self.dictionary) then
			return key
		end
	end

	return nil
end

function Dictionary.collect<K, V>(self: Dictionary<K, V>): { [K]: V }
	return self.dictionary
end

return Dictionary
