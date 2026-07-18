local RunService = game:GetService("RunService")

local util = require(script.Parent.util)

local IS_SERVER = RunService:IsServer()

type Signal<A...> = {
	Connect: (self: Signal<A...>, fn: (A...) -> ()) -> RBXScriptConnection,
	ConnectParallel: (self: Signal<A...>, fn: (A...) -> ()) -> RBXScriptConnection,
	Once: (self: Signal<A...>, fn: (A...) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal<A...>) -> A...,
}

type PlayerSignal<A...> = {
	Connect: (self: PlayerSignal<A...>, fn: (player: Player, A...) -> ()) -> RBXScriptConnection,
	ConnectParallel: (self: PlayerSignal<A...>, fn: (player: Player, A...) -> ()) -> RBXScriptConnection,
	Once: (self: PlayerSignal<A...>, fn: (player: Player, A...) -> ()) -> RBXScriptConnection,
	Wait: (self: PlayerSignal<A...>) -> (Player, A...),
}

local Event = {}
Event.__index = Event

export type Event<A...> = typeof(setmetatable(
	{} :: {
		OnServerEvent: PlayerSignal<A...>,
		OnClientEvent: Signal<A...>,
		remote: RemoteEvent,
		_resolver: util.Resolver,
		_args: (A...) -> A...,
	},
	Event
))

function Event.new<A...>(name: string, parent: Instance, resolver: util.Resolver, args: (A...) -> A...): Event<A...>
	local remoteEvent: RemoteEvent
	if IS_SERVER then
		local duplicateRemote = parent:FindFirstChild(name)
		if duplicateRemote and duplicateRemote:IsA("RemoteEvent") then
			error(`'{name}' RemoteEvent already exists, cannot create TypeRemote.`)
		end

		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = name
		remoteEvent.Parent = parent
	else
		local possibleRemote = parent:WaitForChild(name, 5) :: RemoteEvent?
		if not possibleRemote then
			error(`'{name}' RemoteEvent not found, failed to create TypeRemote.`)
		end

		assert(possibleRemote:IsA("RemoteEvent"), `'{name}' is not a RemoteEvent, failed to create TypeRemote.`)
		remoteEvent = possibleRemote
	end

	local self = setmetatable({}, Event) :: Event<A...>

	if IS_SERVER then
		self.OnServerEvent = remoteEvent.OnServerEvent
	else
		self.OnClientEvent = remoteEvent.OnClientEvent
	end

	self.remote = remoteEvent
	self._resolver = resolver
	self._args = args

	return self
end

function Event.FireServer<A...>(self: Event<A...>, ...: A...)
	local ok, err = self._resolver(self._args, ...)
	if not ok then
		error(err)
	end

	self.remote:FireServer(...)
end

function Event.FireClient<T, A...>(self: Event<A...>, player: Player, ...: A...)
	local ok, err = self._resolver(self._args, ...)
	if not ok then
		error(err)
	end

	self.remote:FireClient(player, ...)
end

function Event.FireAllClients<T, A...>(self: Event<A...>, ...: A...)
	local ok, err = self._resolver(self._args, ...)
	if not ok then
		error(err)
	end

	self.remote:FireAllClients(...)
end

function Event.Destroy(self: Event<...any>)
	self.remote:Destroy()
end

return Event
