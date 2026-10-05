--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ClientReplicator = require(script.ClientReplicator)
local ServerReplicator = require(script.ServerReplicator)

local Replicator = {}
Replicator.__index = Replicator

local function fetchRemoteEvent(parent: Instance, name: string): RemoteEvent
	local remoteEvent: RemoteEvent
	if RunService:IsServer() then
		local duplicateRemote = parent:FindFirstChild(name)
		if duplicateRemote and duplicateRemote:IsA("RemoteEvent") then
			error(`'{name}' RemoteEvent already exists.`)
		end

		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = name
		remoteEvent.Parent = parent
	else
		remoteEvent = assert(parent:WaitForChild(name, 5) :: RemoteEvent?, `'{name}' RemoteEvent not found.`)
		assert(remoteEvent:IsA("RemoteEvent"), `'{name}' is not a RemoteEvent.`)
	end

	return remoteEvent
end

type ServerValues<T> = { [Player]: T }

export type Replicator<T> = typeof(setmetatable(
	{} :: {
		remote: RemoteEvent,
		value: T | ServerValues<T>,
		conns: { RBXScriptConnection },
	},
	Replicator
))

function Replicator.init(parent: Instance?)
	return function<T>(name: string, initialData: T)
		return Replicator.new(parent or script, name, initialData)
	end
end

function Replicator.new<T>(parent: Instance, name: string, initialData: T): Replicator<T>
	local remote = fetchRemoteEvent(parent, name)

	local self = setmetatable({}, Replicator) :: Replicator<T>
	self.remote = remote
	self.conns = {}

	if RunService:IsServer() then
		self.value = {}
		local playerAddedConn = Players.PlayerAdded:Connect(function(player)
			(self.value :: ServerValues<T>)[player] = initialData
		end)
		table.insert(self.conns, playerAddedConn)

		local playerRemovedConn = Players.PlayerRemoving:Connect(function(player)
			(self.value :: ServerValues<T>)[player] = nil
		end)
		table.insert(self.conns, playerRemovedConn)

		local serverSyncConn = remote.OnServerEvent:Connect(function(player, sentValue)
			local playerValue = (self.value :: ServerValues<T>)[player]
			if playerValue == nil or playerValue == sentValue then
				return
			end

			remote:FireClient(player, playerValue)
		end)
		table.insert(self.conns, serverSyncConn)

		for _, player in Players:GetPlayers() do
			(self.value :: ServerValues<T>)[player] = initialData
		end
	else
		self.value = initialData

		local clientSyncConn = remote.OnClientEvent:Connect(function(syncValue)
			self.value = syncValue
		end)
		table.insert(self.conns, clientSyncConn)

		self:sync()
	end

	return self
end

function Replicator.get<T>(self: Replicator<T>, player: Player?): any
	if RunService:IsServer() then
		assert(player, "Replicator 'get' method requires a 'player' parameter on server-side")
		return (self.value :: ServerValues<T>)[player]
	else
		return self.value
	end
end

function Replicator.getAll<T>(self: Replicator<T>): { [Player]: T }
	assert(RunService:IsServer(), "Replicator 'getAll' method can only be run server-side")
	return self.value :: ServerValues<T>
end

function Replicator.set<T>(self: Replicator<T>, player: Player, newValue: T)
	assert(RunService:IsServer(), "Replicator 'set' method can only be run server-side");
	(self.value :: ServerValues<T>)[player] = newValue
	self.remote:FireClient(player, newValue)
end

function Replicator.setAll<T>(self: Replicator<T>, newValue: T)
	assert(RunService:IsServer(), "Replicator 'setAll' method can only be run server-side")
	for _, player in Players:GetPlayers() do
		(self.value :: ServerValues<T>)[player] = newValue
		self.remote:FireClient(player, newValue)
	end
end

function Replicator.sync<T>(self: Replicator<T>)
	assert(RunService:IsClient(), "Replicator 'sync' method can only be run client-side")
	self.remote:FireServer(self.value)
end

function Replicator.observe<T>(self: Replicator<T>, callback: (T) -> ...any)
	assert(RunService:IsClient(), "Replicator 'observe' method can only be run client-side")
	return self.remote.OnClientEvent:Connect(callback)
end

function Replicator.Destroy<T>(self: Replicator<T>)
	for _, conn in self.conns do
		conn:Disconnect()
	end

	self.remote:Destroy()
end

return Replicator
