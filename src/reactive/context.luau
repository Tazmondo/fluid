local graph = require("./graph")

-- The U generic exists so that context can be ergonomically included as a child in create calls
export type Context<T> = (() -> T) & (<U>(value: T, component: () -> U) -> U)

local NIL: {
	__T: "NIL",
} = newproxy()

local function context<T>(...: T): Context<T>
	local has_default = select("#", ...) > 0
	local default_value = ...
	local values = setmetatable({}, { __mode = "k" }) :: { [graph.Node<any>]: unknown }

	local function use_context(...): any
		if select("#", ...) == 0 then
			local scope = graph.get_scope()

			while scope do
				local value = values[scope]

				if value ~= nil then
					return if value == NIL then nil else value
				end

				scope = scope.parent
			end

			if has_default then
				return default_value
			end

			error("attempt to get context when no context or default value is set", 2)
		end

		local value, component = ...

		local parent = graph.assert_stable_parent()
		local provider = graph.create_stable_node(parent)

		values[provider] = if value == nil then NIL else value

		local result = graph.run_as(provider, component)

		if not result.success then
			graph.destroy(provider)
			error(`error while running context:\n\n{result.err}\n{result.trace}`, 2)
		end

		return result.value
	end

	return use_context :: Context<T>
end

return context
