local Event = require(script.Event)
local Func = require(script.Func)
local Util = require(script.util)

export type Event<A...> = Event.Event<A...>
export type Func<T..., R...> = Func.Func<T..., R...>

type Config<T> = {
	resolver: Util.Resolver,
	parent: Instance?,
}

local StrictRemote = {}

function StrictRemote.init<T>(config: Config<T>)
	return {
		event = function(name: string)
			return StrictRemote.event(name, config.resolver, config.parent)
		end,
		func = function(name: string)
			return StrictRemote.func(name, config.resolver, config.parent)
		end,
	}
end

function StrictRemote.event(name: string, resolver: Util.Resolver, parent: Instance?)
	return function<A...>(args: (A...) -> A...): Event<A...>
		return Event.new(name, parent or script, resolver, args)
	end
end

function StrictRemote.func<T>(name: string, resolver: Util.Resolver, parent: Instance?)
	return function<A..., R...>(args: (A...) -> A..., ret: (R...) -> R...): Func<(A...), (R...)>
		return Func.new(name, parent or script, resolver, args, ret)
	end
end

return StrictRemote
