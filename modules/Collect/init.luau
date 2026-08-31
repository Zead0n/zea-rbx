local Array = require(script.Array)
local Dictionary = require(script.Dictionary)

export type Array<T> = Array.Array<T>
export type Dictionary<K, V> = Dictionary.Dictionary<K, V>

local Iter = {}

Iter.array = Array.new
Iter.dictionary = Dictionary.new

return Iter
