local ClientReplicator = {}
ClientReplicator.__index = ClientReplicator

export type ClientReplicator<T> = typeof(setmetatable(
	{} :: {
		value: T,
		remote: RemoteEvent,
		syncConn: RBXScriptConnection,
		observeConns: { RBXScriptConnection },
	},
	ClientReplicator
))

function ClientReplicator.new<T>(re: RemoteEvent, initialData: T): ClientReplicator<T>
	local self = setmetatable({}, ClientReplicator) :: ClientReplicator<T>
	self.value = initialData
	self.remote = re

	self.syncConn = re.OnClientEvent:Connect(function(syncValue)
		self.value = syncValue
	end)

	self:sync()

	return self
end

function ClientReplicator.get<T>(self: ClientReplicator<T>): T
	return self.value
end

function ClientReplicator.observe<T>(self: ClientReplicator<T>, callback: (T) -> ...any): RBXScriptConnection
	return self.remote.OnClientEvent:Connect(callback)
end

function ClientReplicator.sync<T>(self: ClientReplicator<T>)
	self.remote:FireServer()
end

function ClientReplicator.Destroy<T>(self: ClientReplicator<T>)
	self.syncConn:Disconnect()

	for _, observeConn in self.observeConns do
		observeConn:Disconnect()
	end
end

return ClientReplicator
