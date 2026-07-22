type PredicateFn = (module: ModuleScript) -> boolean

local Loader = {}

--[[
	Create a simple predicate that checks the name of the script.
	Useful for filtering scripts with magic characters.

	```lua
	-- Only retrieves scripts that are children of `script` and ends with 'Client'
	-- e.g InventoryClient, MoneyClient, StoreClient
	local childScripts = Loader.childScripts(script, Loader.matches("Client$"))

	-- Only retrieves scripts that are children of `script` and starts with 'Client'
	-- e.g ClientInventory, ClientMoney, ClientStore
	local childScripts = Loader.childScripts(script, Loader.matches("^Client"))
	```
]]
function Loader.matches(matchName: string): PredicateFn
	return function(module: ModuleScript): boolean
		return module.Name:match(matchName) ~= nil
	end
end

--[[
	Get child module scripts of `parent`.
	Pass a `(ModuleScript) -> boolean` in `predicate` to filter.
]]
function Loader.childScripts(parent: Instance, predicate: PredicateFn?): { ModuleScript }
	local modules: { ModuleScript } = {}
	for _, child in parent:GetChildren() do
		if not child:IsA("ModuleScript") or (predicate and not predicate(child)) then
			continue
		end

		table.insert(modules, child)
	end

	return modules
end

--[[
	Get descendant module scripts of `parent`.
	Pass a `(ModuleScript) -> boolean` in `predicate` to filter.
]]
function Loader.descendantScripts(parent: Instance, predicate: PredicateFn?): { ModuleScript }
	local modules: { ModuleScript } = {}
	for _, descendant in parent:GetDescendants() do
		if not descendant:IsA("ModuleScript") or (predicate and not predicate(descendant)) then
			continue
		end

		table.insert(modules, descendant)
	end

	return modules
end

--[[
	Create a starter function that when invoked, calls and passes the arguments to the
	function/method in parallel and returns a table of the results from the call(s).

	Use `isMethod` to specify whether the callback is a function or method.

	This could be used to start character systems that need to be cleaned up on death for example.

	> [NOTE]: I do not recommend using this example in your projects;
	> Make it as simple or robust as you need.

	```lua
	-- client/SomeClient.luau
	local SomeClient = {}

	function SomeClient.startCharacter(character)
		local conn = character.Humanoid.Jumping:Connect(function(active)
			if active then
				print("Jumped")
			end
		end)

		return function()
			conn:Disconnect()
		end
	end

	return SomeClient

	-- client/init.luau
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	local Loader = require(path.to.Loader)

	local childScripts = Loader.childScripts(script)
	local startCharacterSystems = Loader.createPromiseStarter(childScripts, "startCharacter")

	player.CharacterAdded:Connect(function(character)
		local cleanups = startCharacterSystems(character)

		charcter.Humanoid.Died:Wait()

		for _, cleanup in cleanups do
			cleanup()
		end
	end)
	```
]]
function Loader.createStarter(scripts: { ModuleScript }, functionName: string, isMethod: boolean?): (...any) -> { any }
	local function createCaller(moduleScript: ModuleScript)
		local module = require(moduleScript)
		local method = module[functionName]

		if typeof(method) ~= "function" then
			warn(`'{moduleScript.Name}' does not have '{functionName}' in order to start`)
		end

		return function(...)
			debug.setmemorycategory(moduleScript.Name)
			return if not isMethod then method(...) else method(module, ...)
		end
	end

	local callers = {}
	for _, ms in scripts do
		table.insert(callers, createCaller(ms))
	end

	return function(...)
		local results = {}

		local t = coroutine.running()

		local finishedCalls = 0

		for _, call in callers do
			task.defer(function(...)
				local result = call(...)
				if result then
					table.insert(results, result)
				end

				finishedCalls += 1
				if finishedCalls >= #callers then
					coroutine.resume(t)
				end
			end, ...)
		end

		coroutine.yield()

		return results
	end
end

return Loader
