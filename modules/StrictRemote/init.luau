--!strict
local RunService = game:GetService("RunService")

export type Resolver<T> = (T, any) -> (boolean, string?)

local function fetchRemoteEvent(parent: Instance, name: string, isUnreliable: boolean): RemoteEvent
	local remoteType = if isUnreliable then "UnreliableRemoteEvent" else "RemoteEvent"
	local remote: Instance

	if RunService:IsServer() then
		local duplicateRemote = parent:FindFirstChild(name)
		if duplicateRemote and duplicateRemote:IsA("RemoteEvent") then
			error(`'{name}' RemoteEvent already exists, cannot create TypeRemote.`)
		end

		remote = Instance.new(remoteType)
		remote.Name = name
		remote.Parent = parent
	else
		local possibleRemote = parent:WaitForChild(name, 5) :: RemoteEvent?
		if not possibleRemote then
			error(`'{name}' RemoteEvent not found, failed to create TypeRemote.`)
		end

		assert(possibleRemote:IsA("RemoteEvent"), `'{name}' is not a RemoteEvent, failed to create TypeRemote.`)
		remote = possibleRemote
	end

	return remote :: any
end

local function fetchRemoteFunction(parent: Instance, name: string): RemoteFunction
	local remoteFunction: RemoteFunction
	if RunService:IsServer() then
		local duplicateRemote = parent:FindFirstChild(name)
		if duplicateRemote and duplicateRemote:IsA("RemoteFunction") then
			error(`'{name}' RemoteFunction already exists.`)
		end

		remoteFunction = Instance.new("RemoteFunction")
		remoteFunction.Name = name
		remoteFunction.Parent = parent
	else
		remoteFunction = assert(parent:WaitForChild(name, 5) :: RemoteFunction?, `'{name}' RemoteFunction not found.`)
		assert(remoteFunction:IsA("RemoteFunction"), `'{name}' is not a RemoteFunction.`)
	end

	return remoteFunction
end

local function assertWrapper<T>(resolver: Resolver<T>, argMatchers: { T })
	local expectedArgCount = #argMatchers

	return function(...: any)
		local args = table.pack(...)

		if args.n > expectedArgCount then
			error("Too many arguments", 4)
		end

		for idx = 1, args.n do
			local argMatcher = argMatchers[idx]
			if not argMatcher then
				continue
			end

			local arg = args[idx]
			local ok, err = resolver(argMatcher, arg)
			if not ok then
				error(err or "Unknown resolve", 4)
			end
		end

		return ...
	end
end

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

export type Event<C, A...> = typeof(setmetatable(
	{} :: {
		OnServerEvent: PlayerSignal<A...>,
		OnClientEvent: Signal<A...>,
		remote: RemoteEvent,
		_args: (...any) -> ...any,
	},
	Event
))

function Event.new<C, A...>(
	name: string,
	parent: Instance,
	resolver: Resolver<C>,
	args: { C },
	isUnreliable: boolean
): Event<C, A...>
	local remoteEvent = fetchRemoteEvent(parent, name, isUnreliable)
	local self = setmetatable({}, Event) :: Event<C, A...>

	self.OnServerEvent = remoteEvent.OnServerEvent
	self.OnClientEvent = remoteEvent.OnClientEvent

	self.remote = remoteEvent
	self._args = assertWrapper(resolver, args)

	return self
end

function Event.FireServer<C, A...>(self: Event<C, A...>, ...: A...)
	self.remote:FireServer(self._args(...))
end

function Event.FireClient<C, A...>(self: Event<C, A...>, player: Player, ...: A...)
	self.remote:FireServer(player, self._args(...))
end

function Event.FireAllClients<C, A...>(self: Event<C, A...>, ...: A...)
	self.remote:FireAllClients(self._args(...))
end

function Event.Destroy<C, A...>(self: Event<C, A...>)
	self.remote:Destroy()
end

local Func = {}
Func.__index = Func

type InternalFunc<C, A..., R...> = typeof(setmetatable(
	{} :: {
		remote: RemoteFunction,
		_args: (...any) -> ...any,
		_returns: (...any) -> ...any,
		_predictPromise: any,
	},
	Func
))

-- HACK: luau typesolver can't figure out multiple generic packs in a table with a metatable, this will have to do
export type Func<C, T..., R...> = {
	remote: RemoteFunction,
	_args: (...any) -> ...any,
	_returns: (...any) -> ...any,
	_predictPromise: any,
	SetServerInvoke: (InternalFunc<C, T..., R...>, (Player, T...) -> R...) -> (),
	SetClientInvoke: (InternalFunc<C, T..., R...>, (T...) -> R...) -> (),
	InvokeServer: (InternalFunc<C, T..., R...>, T...) -> R...,
	InvokeClient: (InternalFunc<C, T..., R...>, Player, T...) -> R...,
	Destroy: (InternalFunc<C, T..., R...>) -> (),
}

function Func.new<C, A..., R...>(
	name: string,
	parent: Instance,
	resolver: Resolver<C>,
	args: { C },
	returns: { C }
): InternalFunc<C, A..., R...>
	local remoteFunction = fetchRemoteFunction(parent, name)

	local self = setmetatable({}, Func) :: InternalFunc<C, A..., R...>

	self.remote = remoteFunction
	self._args = assertWrapper(resolver, args)
	self._returns = assertWrapper(resolver, returns)

	return self
end

function Func.SetServerInvoke<C, A..., R...>(self: InternalFunc<C, A..., R...>, onInvoke: (Player, A...) -> R...)
	self.remote.OnServerInvoke = onInvoke
end

function Func.SetClientInvoke<C, A..., R...>(self: InternalFunc<C, A..., R...>, onInvoke: (A...) -> R...)
	self.remote.OnClientInvoke = onInvoke
end

function Func.InvokeServer<C, A..., R...>(self: InternalFunc<C, A..., R...>, ...: A...): R...
	return self._returns(self.remote:InvokeServer(self._args(...)))
end

function Func.InvokeClient<C, A..., R...>(self: InternalFunc<C, A..., R...>, player: Player, ...: A...): R...
	return self._returns(self.remote:InvokeClient(player, self._args(...)))
end

function Func.Destroy<C, A..., R...>(self: InternalFunc<C, A..., R...>)
	if self._predictPromise then
		self._predictPromise:cancel()
		self._predictPromise = nil
	end
	self.remote:Destroy()
end

local StrictRemote = {}

function StrictRemote.init<C>(parent: Instance, resolver: Resolver<C>)
	return {
		unreliableRemoteEvent = function(name: string)
			return StrictRemote.unreliableRemoteEvent(name, parent, resolver)
		end,
		remoteEvent = function(name: string)
			return StrictRemote.remoteEvent(name, parent, resolver)
		end,
		remoteFunction = function(name: string)
			return StrictRemote.remoteFunction(name, parent, resolver)
		end,
	}
end

function StrictRemote.unreliableRemoteEvent<C>(name: string, parent: Instance, resolver: Resolver<C>)
	return function<A...>(...: A...): Event<C, A...>
		local argTypes = table.pack(...) :: any
		argTypes.n = nil

		return Event.new(name, parent, resolver, argTypes, true)
	end
end

function StrictRemote.remoteEvent<C>(name: string, parent: Instance, resolver: Resolver<C>)
	return function<A...>(...: A...): Event<C, A...>
		local argTypes = table.pack(...) :: any
		argTypes.n = nil

		return Event.new(name, parent, resolver, argTypes, false)
	end
end

function StrictRemote.remoteFunction<C>(name: string, parent: Instance, resolver: Resolver<C>)
	return function<A...>(...: A...)
		local argTypes = table.pack(...) :: any
		argTypes.n = nil

		return function<R...>(...: R...): Func<C, A..., R...>
			local returnTypes = table.pack(...) :: any
			returnTypes.n = nil

			return Func.new(name, parent, resolver, argTypes, returnTypes) :: any
		end
	end
end

return StrictRemote
