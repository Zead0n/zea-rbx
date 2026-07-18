export type Resolver = (any, ...any) -> (boolean, string?, ...any)

local util = {}

function util.assert(ok: boolean, err: string?, ...)
	if not ok then
		error(err)
	end

	return ...
end

return util
