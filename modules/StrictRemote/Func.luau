local RunService = game:GetService("RunService")

local util = require(script.Parent.util)

local IS_SERVER = RunService:IsServer()

local Func = {}
Func.__index = Func

export type Func<T..., R...> = typeof(setmetatable(
	{} :: {
		OnServerInvoke: (Player, T...) -> R...,
		OnClientInvoke: (T...) -> R...,
		remote: RemoteFunction,
		_resolver: util.Resolver,
		_args: (T...) -> T...,
		_returns: (R...) -> R...,
	},
	Func
))

function Func.new<T..., R...>(
	name: string,
	parent: Instance,
	resolver: util.Resolver,
	args: (T...) -> T...,
	returns: (R...) -> R...
): Func<T..., R...>
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

	local self = setmetatable({}, Func) :: Func<T..., R...>

	self.remote = remoteFunction
	self._resolver = resolver
	self._args = args
	self._returns = returns

	return self
end

function Func.SetServerInvoke<T..., R...>(self: Func<T..., R...>, onInvoke: (Player, T...) -> R...)
	self.remote.OnServerInvoke = onInvoke
end

function Func.SetClientInvoke<T..., R...>(self: Func<T..., R...>, onInvoke: (T...) -> R...)
	self.remote.OnClientInvoke = onInvoke
end

function Func.InvokeServer<T..., R...>(self: Func<T..., R...>, ...: T...): R...
	local ok, err = self._resolver(self._args, ...)
	if not ok then
		error(err)
	end

	return util.assert(self._resolver(self._returns, self.remote:InvokeServer(...)))
end

function Func.InvokeClient<T..., R...>(self: Func<T..., R...>, player: Player, ...: T...): R...
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
