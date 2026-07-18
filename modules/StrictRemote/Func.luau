--!strict

local RunService = game:GetService("RunService")

local util = require(script.Parent.util)

local IS_SERVER = RunService:IsServer()

local Func = {}
Func.__index = Func

export type Func<A..., R...> = typeof(setmetatable(
	{} :: {
		OnServerInvoke: (Player, A...) -> R...,
		OnClientInvoke: (A...) -> R...,
		remote: RemoteFunction,
		_resolver: util.Resolver,
		_args: (A...) -> ...any,
		_returns: (...any) -> R...,
	},
	Func
))

function Func.new<A..., R...>(
	name: string,
	parent: Instance,
	resolver: util.Resolver,
	args: (A...) -> A...,
	returns: (R...) -> R...
): Func<A..., R...>
	local remoteFunction: RemoteFunction
	if IS_SERVER then
		local duplicateRemote = parent:FindFirstChild(name)
		if duplicateRemote and duplicateRemote:IsA("RemoteFunction") then
			error(`'{name}' RemoteFunction already exists, cannot create TypeRemote.`)
		end

		remoteFunction = Instance.new("RemoteFunction")
		remoteFunction.Name = name
		remoteFunction.Parent = parent
	else
		local possibleRemote = parent:WaitForChild(name, 5) :: RemoteFunction?
		if not possibleRemote then
			error(`'{name}' RemoteFunction not found, failed to create TypeRemote.`)
		end

		assert(possibleRemote:IsA("RemoteFunction"), `'{name}' is not a RemoteFunction, failed to create TypeRemote.`)
		remoteFunction = possibleRemote
	end

	local self = setmetatable({}, Func) :: Func<A..., R...>

	self.remote = remoteFunction
	self._resolver = resolver
	self._args = args
	self._returns = returns

	return self
end

function Func.SetServerInvoke<A..., R...>(self: Func<A..., R...>, onInvoke: (Player, A...) -> R...)
	self.remote.OnServerInvoke = onInvoke
end

function Func.SetClientInvoke<A..., R...>(self: Func<A..., R...>, onInvoke: (A...) -> R...)
	self.remote.OnClientInvoke = onInvoke
end

function Func.InvokeServer<A..., R...>(self: Func<A..., R...>, ...: A...): R...
	local ok, err = self._resolver(self._args, ...)
	if not ok then
		error(err)
	end

	return util.assert(self._resolver(self._returns, self.remote:InvokeServer(...)))
end

function Func.InvokeClient<A..., R...>(self: Func<A..., R...>, player: Player, ...: A...): R...
	local ok, err = self._resolver(self._args, ...)
	if not ok then
		error(err)
	end

	return util.assert(self._resolver(self._returns, self.remote:InvokeClient(player, ...)))
end

function Func.Destroy(self: Func<(...any), (...any)>)
	self.remote:Destroy()
end

return Func
