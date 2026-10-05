local Players = game:GetService("Players")
local ServerReplicator = {}
ServerReplicator.__index = ServerReplicator

export type ServerReplicator<T> = typeof(setmetatable(
	{} :: {
		playersValue: { [Player]: T },
		remote: RemoteEvent,
		playerAddedConn: RBXScriptConnection,
		playerRemovedConn: RBXScriptConnection,
		syncConn: RBXScriptConnection,
	},
	ServerReplicator
))

function ServerReplicator.new<T>(re: RemoteEvent, initialData: T): ServerReplicator<T>
	local self = setmetatable({}, ServerReplicator) :: ServerReplicator<T>
	self.playersValue = {}
	self.remote = re

	self.playerAddedConn = Players.PlayerAdded:Connect(function(player)
		self.playersValue[player] = initialData
	end)

	self.playerAddedConn = Players.PlayerRemoving:Connect(function(player)
		self.playersValue[player] = nil
	end)

	self.syncConn = re.OnServerEvent:Connect(function(player, sentValue)
		local playerValue = self.playersValue[player]
		if playerValue == nil or playerValue == sentValue then
			return
		end

		re:FireClient(player, playerValue)
	end)

	for _, player in Players:GetPlayers() do
		self.playersValue[player] = initialData
	end

	return self
end

function ServerReplicator.get<T>(self: ServerReplicator<T>, player: Player): T
	return self.playersValue[player]
end

function ServerReplicator.getAll<T>(self: ServerReplicator<T>): { [Player]: T }
	return self.playersValue
end

function ServerReplicator.set<T>(self: ServerReplicator<T>, player: Player, newValue: T)
	self.playersValue[player] = newValue
	self.remote:FireClient(player, newValue)
end

function ServerReplicator.setAll<T>(self: ServerReplicator<T>, newValue: T)
	for _, player in Players:GetPlayers() do
		self.playersValue[player] = newValue
		self.remote:FireClient(player, newValue)
	end
end

function ServerReplicator.Destroy<T>(self: ServerReplicator<T>)
	self.playerAddedConn:Disconnect()
	self.playerRemovedConn:Disconnect()
	self.syncConn:Disconnect()
end

return ServerReplicator
