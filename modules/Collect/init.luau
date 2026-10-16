--!strict
local Tbl = require(script.Tbl)

export type Sieve<K, V> = Tbl.Table<K, V>

local Sieve = {}

local mt = {
	__call = Tbl.new,
}

return setmetatable(Sieve, mt)
