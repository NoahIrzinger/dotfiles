-- config.theme: load the active color palette from the dotfiles theme registry.
-- A theme lives at <dotfiles>/themes/<name>.theme as `flavour=` plus 26 Catppuccin
-- palette slots (name=hex, no leading #). The `theme` CLI sets which one is active.
local M = {}

local function dotfiles_root()
	local env = os.getenv("DOTFILES_DIR")
	if env and env ~= "" then
		return env
	end
	return vim.fn.expand("~/.dotfiles")
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

local function parse_theme(path)
	local content = read_file(path)
	if not content then
		return nil
	end
	local out = {}
	for line in content:gmatch("[^\r\n]+") do
		if not line:match("^%s*#") then
			local key, val = line:match("^%s*([%w_]+)%s*=%s*([^%s#]+)")
			if key and val then
				out[key] = val
			end
		end
	end
	return out
end

-- Returns { name, flavour, colors = { slot = "#hex", ... } } or nil if the
-- registry is absent (fresh machine before `theme` has ever run).
function M.load()
	local dir = dotfiles_root() .. "/themes"
	local active = read_file(dir .. "/active")
	active = active and active:gsub("%s+", "") or ""
	if active == "" then
		active = "dark"
	end

	local raw = parse_theme(dir .. "/" .. active .. ".theme")
	if not raw then
		return nil
	end

	local flavour = raw.flavour or "mocha"
	raw.flavour = nil

	local colors = {}
	for slot, hex in pairs(raw) do
		colors[slot] = "#" .. hex:gsub("^#", "")
	end

	return { name = active, flavour = flavour, colors = colors }
end

return M
