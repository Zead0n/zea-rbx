local CollectionService = game:GetService("CollectionService")

local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)
local Trove = require(script.Parent.Trove)

local DEFAULT_ANCESTORS: { Instance } = { game:GetService("Workspace"), game:GetService("Players") }

type ClassLike<T> = {
	new: (Instance, ...any) -> T,
}

type ComponentEntry<T> = { comp: T?, trove: Trove.Trove }

local Component = {}
Component.__index = Component

export type Component<T> = typeof(setmetatable(
	{} :: {
		_tag: string,
		_ancestors: { Instance },
		_module: ClassLike<T>,
		_trove: Trove.Trove,
		_instanceRegistry: { [Instance]: ComponentEntry<T> },
		--[[
			Fires when a ComponentInstance has been instantiated
		]]
		AddedComponentSignal: Signal.Signal<T, Instance>,
		--[[
			Fires before a ComponentInstance is destroyed and unregisterd
		]]
		RemovingComponentSignal: Signal.Signal<T, Instance>,
	},
	Component
))

--[[
	Create a new Component.
	- `module` is the 'class' module you want to pass the Instance into
	- `tag` is the tag you want to observe
	- `ancestors` is the only ancestors you want your component to be loaded
		(optional / defaults to **{ game:GetService("Workspace"), game:GetService("Players") }**)
	
	Your class module is **REQUIRED** to have a `new` function that accepts an `Instance`.

	Note that if you have a `Destroy` or `destroy` method, it will be called when the underlying
	instance is not in a valid ancestor.
	
	```lua
	-- SomeComponent/SomeClass.luau
	local SomeClass = {}
	SomeClass.__index = SomeClass
	
	export type SomeInstance = typeof(setmetatable(
		{} :: {
			someData: number
		},
		SomeClass
	))
	
	function SomeClass.new(instance: Instance): SomeInstance
		local self = setmetatable({}, SomeClass) :: SomeInstance
		self.Instance = instance
		self.someData = 15
		return self
	end
	
	function SomeClass.doSomething(self: SomeInstance)
		self.someData += 15
	end
	
	function SomeClass.Destroy(self: SomeInstance)
		self.someData = 0
	end
	
	return SomeClass
	
	-- SomeComponent/init.luau
	local SomeClass = require(script.SomeClass)
	local Component = require(path.to.Component)
	return Component.new(SomeClass, "SomeComponent") :: Component.Component<SomeClass.SomeInstance>
	```
]]
function Component.new<T>(module: ClassLike<T>, tag: string, ancestors: { Instance }?): Component<T>
	local self = setmetatable({}, Component) :: Component<T>
	self._tag = tag
	self._ancestors = (ancestors or DEFAULT_ANCESTORS) :: { Instance }
	self._module = module
	self._trove = Trove.new()
	self._instanceRegistry = {}
	self.AddedComponentSignal = self._trove:Construct(Signal)
	self.RemovingComponentSignal = self._trove:Construct(Signal)

	self._trove:Connect(CollectionService:GetInstanceAddedSignal(tag), function(instance: Instance)
		self:_registerInstance(instance)
	end)
	self._trove:Connect(CollectionService:GetInstanceRemovedSignal(tag), function(instance: Instance)
		self:_degisterInstance(instance)
	end)

	for _, taggedInstance in CollectionService:GetTagged(tag) do
		self:_registerInstance(taggedInstance)
	end

	return self
end

function Component._registerInstance<T>(self: Component<T>, instance: Instance)
	local instanceTrove = self._trove:Extend()
	local instanceEntry: ComponentEntry<T> = { trove = instanceTrove }
	self._instanceRegistry[instance] = instanceEntry

	local function descendantCheck(): boolean
		for _, ancestor in self._ancestors do
			if instance:IsDescendantOf(ancestor) then
				return true
			end
		end

		return false
	end

	local function addComponent()
		local instanceComponent = instanceTrove:Construct(self._module, instance)
		instanceEntry.comp = instanceComponent

		instanceTrove:Add(function()
			instanceEntry.comp = nil
		end)

		self.AddedComponentSignal:Fire(instanceComponent, instance)
	end

	local function removeComponent()
		local instanceComponent = instanceEntry.comp
		if not instanceComponent then
			return
		end

		self.RemovingComponentSignal:Fire(instanceComponent, instance)
		instanceEntry.comp = nil
		self._trove:Remove(instanceComponent)
	end

	instanceTrove:Connect(instance.AncestryChanged, function(_, parent)
		if parent and descendantCheck() then
			addComponent()
		else
			removeComponent()
		end
	end)

	if descendantCheck() then
		addComponent()
	end
end

function Component._deregisterInstance<T>(self: Component<T>, instance: Instance)
	local registry = self._instanceRegistry

	local instanceEntry = registry[instance]
	if not instanceEntry then
		return
	end

	instanceEntry.trove:Clean()
	registry[instance] = nil
end

--[[
	Returns a Dictionary of Instance to ComponentInstance
]]
function Component.getComponents<T>(self: Component<T>): { [Instance]: T }
	local compDict: { [Instance]: T } = {}
	for instance, entry in self._instanceRegistry do
		if entry.comp then
			compDict[instance] = entry.comp
		end
	end

	return compDict
end

--[[
	Returns the ComponentInstance of the passed Instance.
	If no ComponentInstance is found, returns `nil`
]]
function Component.getComponent<T>(self: Component<T>, instance: Instance): T?
	return self:getComponents()[instance]
end

--[[
	Returns a Promise of the retrieved ComponentInstance.
]]
function Component.getComponentPromise<T>(self: Component<T>, instance: Instance): Promise.TypedPromise<T>
	local instanceComponent = self:getComponent(instance)
	if instanceComponent then
		return Promise.resolve(instanceComponent)
	end

	-- NOTE: Trove 'AddPromise' method doesn't support typed promises without the lsp screaming.
	-- Waiting for https://github.com/Sleitnick/RbxUtil/pull/263
	local promise = Promise.fromEvent(self.AddedComponentSignal, function(component, cinstance)
		local match = cinstance == instance
		if match then
			instanceComponent = component
		end
		return match
	end):andThenReturn(instanceComponent)

	self._trove:Add(function()
		promise:cancel()
	end)

	return promise
end

--[[
	Returns ComponentInstance of the passed Instance.
	If no ComponentInstance if found, wait for Instance to register until `timeout`.
]]
function Component.waitForComponent<T>(self: Component<T>, instance: Instance, timeout: number?): T?
	return self:getComponentPromise(instance)
		:timeout(timeout or 5)
		:catch(function()
			warn(`Getting '{self._tag}' component for '{instance.Name}' timedout.`)
		end)
		:expect()
end

--[[
	Adds component tag to instance.
]]
function Component.addInstance<T>(self: Component<T>, instance: Instance)
	instance:AddTag(self._tag)
end

--[[
	Adds component tag to instance and returns Promise of added ComponentInstance.
]]
function Component.addInstancePromise<T>(self: Component<T>, instance: Instance): Promise.TypedPromise<T>
	instance:AddTag(self._tag)
	return self:waitForComponent(instance)
end

--[[
	Destory and unregister all components
]]
function Component.Destroy<T>(self: Component<T>)
	task.spawn(self._trove:WrapClean())
end

return Component
