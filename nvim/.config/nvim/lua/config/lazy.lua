-- Verify the plugin manager against the committed lock before executing it.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
local lock = vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
local commit = assert(lock["lazy.nvim"] and lock["lazy.nvim"].commit, "lazy.nvim missing from lockfile")
assert(#commit == 40 and commit:match("^%x+$"), "Invalid lazy.nvim commit")
local function git(args)
	local out = vim.fn.system(args)
	if vim.v.shell_error ~= 0 then
		error("lazy.nvim bootstrap failed: " .. out)
	end
	return vim.trim(out)
end
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	git({ "git", "clone", "--filter=blob:none", "--no-checkout", lazyrepo, lazypath })
else
	assert(
		git({ "git", "-C", lazypath, "status", "--porcelain" }) == "",
		"lazy.nvim has local changes; refusing to load"
	)
end
if git({ "git", "-C", lazypath, "rev-parse", "HEAD" }) ~= commit then
	git({ "git", "-C", lazypath, "fetch", "--depth=1", "origin", commit })
end
git({ "git", "-C", lazypath, "checkout", "--detach", commit })
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = ","
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
	spec = {
		-- import your plugins
		{ import = "plugins" },
	},
	-- Configure any other settings here. See the documentation for more details.
	-- colorscheme that will be used when installing plugins.
	install = { colorscheme = { "habamax" } },
	-- check for plugin updates in background (no startup notification)
	checker = { enabled = true, notify = false },
})
