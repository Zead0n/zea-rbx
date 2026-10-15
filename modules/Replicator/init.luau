local GlobalReplicator = require(script.GlobalReplicator)
local LocalReplicator = require(script.LocalReplicator)

local Replicator = {}

function Replicator.init(parent: Instance)
	return {
		scoped = function<T>(name: string, data: T)
			return LocalReplicator.new(parent, name, data)
		end,
		global = function<T>(name: string, data: T)
			return GlobalReplicator.new(parent, name, data)
		end,
	}
end

Replicator.scope = LocalReplicator.new
Replicator.global = GlobalReplicator.new

return Replicator
