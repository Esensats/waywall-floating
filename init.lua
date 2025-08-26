--- floating.lua
--- Single entry-point for floating visibility.

--- --- @class FloatingAPI
--- --- @field show fun()                      -- show once, does not change override
--- --- @field hide fun()                      -- hide once, does not change override
--- --- @field override_on fun()               -- set persistent override ON (shows)
--- --- @field override_off fun()              -- set persistent override OFF (hides)
--- --- @field override_toggle fun(): boolean  -- toggle override, returns new state
--- --- @field is_overridden fun(): boolean    -- current override state
--- --- @field hide_after_timeout fun(delay_ms: integer) -- hide later if not overridden
--- local floating = {}
---
--- local waywall = require("waywall")
---
--- -- ---- override object (persists intent) -------------------------
---
--- --- Creates a floating override object with toggle/set/get controls.
--- --- @param action_enable fun()
--- --- @param action_disable fun()
--- --- @return table
--- local function create_floating_override(action_enable, action_disable)
---   local toggled_on = false
---   local called_before = false
---
---   local function reset()
---     toggled_on = false
---     action_disable()
---   end
---
---   local function call_reset_once()
---     if not called_before then
---       called_before = true
---       reset()
---     end
---   end
---
---   local self = {}
---
---   --- @return boolean
---   function self.get()
---     return toggled_on
---   end
---
---   --- @param value boolean
---   function self.set(value)
---     call_reset_once()
---     toggled_on = value
---     if toggled_on then
---       action_enable()
---     else
---       action_disable()
---     end
---   end
---
---   --- @return boolean
---   function self.toggle()
---     self.set(not toggled_on)
---     return toggled_on
---   end
---
---   return self
--- end
---
--- local function show_once() waywall.show_floating(true) end
--- local function hide_once() waywall.show_floating(false) end
---
--- local override = create_floating_override(
---   show_once,
---   hide_once
--- )
---
--- -- ---- immediate show/hide (do NOT touch override) ---------------
---
--- function floating.show() show_once() end
--- function floating.hide() hide_once() end
---
--- -- ---- override API ----------------------------------------------
---
--- function floating.override_on()  override.set(true)  end
--- function floating.override_off() override.set(false) end
--- function floating.override_toggle() return override.toggle() end
--- function floating.is_overridden() return override.get() end
---
--- -- ---- timeout helper --------------------------------------------
---
--- --- @param action fun()
--- --- @return fun(delay_ms: integer)
--- local function create_resettable_timeout(action)
---   local generation = 0
---   return function(delay_ms)
---     generation = generation + 1
---     local my_gen = generation
---     waywall.sleep(delay_ms)
---     if my_gen == generation then action() end
---   end
--- end
---
--- floating.hide_after_timeout = create_resettable_timeout(function()
---   if not override.get() then
---     -- Only hide if no persistent override is active.
---     hide_once()
---   end
--- end)
---
--- return floating

-- floating.lua
--- Single entry-point for floating visibility.

--- @class FloatingBackend
--- @field show_floating fun(state: boolean)
--- @field sleep fun(ms: integer)

--- @param backend FloatingBackend
--- @return FloatingAPI
local function create_floating(backend)
	--- @class FloatingAPI
	local floating = {}

	-- override object
	local override = (function()
		local function create_override(action_enable, action_disable)
			local toggled_on = false
			local called_before = false

			local function reset()
				toggled_on = false
				action_disable()
			end

			local function call_reset_once()
				if not called_before then
					called_before = true
					reset()
				end
			end

			local self = {}

			function self.get()
				return toggled_on
			end

			function self.set(value)
				call_reset_once()
				toggled_on = value
				if toggled_on then
					action_enable()
				else
					action_disable()
				end
			end

			function self.toggle()
				self.set(not toggled_on)
				return toggled_on
			end

			return self
		end

		return create_override(function()
			backend.show_floating(true)
		end, function()
			backend.show_floating(false)
		end)
	end)()

	-- immediate show/hide

	--- Show floating once, does not change override state.
	function floating.show()
		backend.show_floating(true)
	end

	--- Hide floating once, does not change override state.
	function floating.hide()
		backend.show_floating(false)
	end

	-- override API

	--- Set persistent override ON (shows floating).
	function floating.override_on()
		override.set(true)
	end

	--- Set persistent override OFF (hides floating).
	function floating.override_off()
		override.set(false)
	end

	--- Toggle override.
	--- @return boolean new override state
	function floating.override_toggle()
		return override.toggle()
	end

	--- @return boolean current override state
	function floating.is_overridden()
		return override.get()
	end

	--- resettable timeout helper
	--- @param action fun() -- action to perform after timeout
	--- @return fun(delay_ms: integer) -- function to call to set/reset timeout
	local function create_resettable_timeout(action)
		local generation = 0
		return function(delay_ms)
			generation = generation + 1
			local my_gen = generation
			backend.sleep(delay_ms)
			if my_gen == generation then
				action()
			end
		end
	end

	--- Hide floating after a delay if not overridden.
	floating.hide_after_timeout = create_resettable_timeout(function()
		if not override.get() then
			backend.show_floating(false)
		end
	end)

	return floating
end

return create_floating
