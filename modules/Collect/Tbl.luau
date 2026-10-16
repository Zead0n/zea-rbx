--!strict

-- local function copyTable(tbl: { [any]: any }, deep: boolean?)
-- 	local new = table.clone(tbl)
--
-- 	if deep then
-- 		for key, value in tbl do
-- 			if type(value) == "table" then
-- 				new[key] = copyTable(value, deep)
-- 			end
-- 		end
-- 	end
--
-- 	return new
-- end

local Tbl = {}
Tbl.__index = Tbl

export type Table<K, V> = typeof(setmetatable({} :: { tbl: { [K]: V } }, Tbl))

function Tbl.new<K, V>(tbl: { [K]: V }): Table<K, V>
	local self = setmetatable({}, Tbl) :: Table<K, V>
	self.tbl = tbl
	return self
end

function Tbl.keys<K, V>(self: Table<K, V>): { K }
	local keys: { K } = {}

	for key, _ in self.tbl do
		table.insert(keys, key)
	end

	return keys
end

function Tbl.values<K, V>(self: Table<K, V>): { V }
	local values: { V } = {}

	for _, value in self.tbl do
		table.insert(values, value)
	end

	return values
end

function Tbl.map<K, V, NV>(self: Table<K, V>, callback: (V, K, { [K]: V }) -> NV): Table<K, NV>
	local newDict: { [K]: NV } = {}

	for key, value in self.tbl do
		local newValue = callback(value, key, self.tbl)

		if newValue ~= nil then
			newDict[key] = newValue
		end
	end

	return Tbl.new(newDict)
end

function Tbl.mapKeys<K, V, NK>(self: Table<K, V>, callback: (V, K, { [K]: V }) -> NK): Table<NK, V>
	local newDict: { [NK]: V } = {}

	for key, value in self.tbl do
		local newKey = callback(value, key, self.tbl)

		if newKey ~= nil then
			newDict[newKey] = value
		end
	end

	return Tbl.new(newDict)
end

function Tbl.mapDict<K, V, NK, NV>(self: Table<K, V>, callback: (V, K, { [K]: V }) -> (NV, NK)): Table<NK, NV>
	local newDict: { [NK]: NV } = {}

	for key, value in self.tbl do
		local newValue, newKey = callback(value, key, self.tbl)

		if newValue ~= nil then
			newDict[newKey] = newValue
		end
	end

	return Tbl.new(newDict)
end

function Tbl.filter<K, V>(self: Table<K, V>, callback: (V, K, { [K]: V }) -> boolean): Table<K, V>
	local newDict: { [K]: V } = {}

	for key, value in self.tbl do
		if callback(value, key, self.tbl) then
			newDict[key] = value
		end
	end

	return Tbl.new(newDict)
end

function Tbl.find<K, V>(self: Table<K, V>, callback: (V, K, { [K]: V }) -> boolean): (V?, K?)
	for key, value in self.tbl do
		if callback(value, key, self.tbl) then
			return value, key
		end
	end

	return nil, nil
end

function Tbl.all<K, V>(self: Table<K, V>, callback: (V, K, { [K]: V }) -> boolean): boolean
	for key, value in self.tbl do
		if not callback(value, key, self.tbl) then
			return false
		end
	end

	return true
end

function Tbl.any<K, V>(self: Table<K, V>, callback: (V, K, { [K]: V }) -> boolean): boolean
	for key, value in self.tbl do
		if callback(value, key, self.tbl) then
			return true
		end
	end

	return false
end

function Tbl.collect<K, V>(self: Table<K, V>): { [K]: V }
	return self.tbl
end

return Tbl
