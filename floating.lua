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
