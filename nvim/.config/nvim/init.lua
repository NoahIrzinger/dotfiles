-- needed for nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true

-- When Neovim is launched outside an interactive shell, mise may not have
-- populated PATH. Keep mise-managed tools like tree-sitter/node/jq visible to
-- plugins that spawn external commands (kulala.nvim, mason, treesitter, etc.).
do
	local home = vim.fn.expand("~")
	local paths = {
		home .. "/.local/share/mise/shims",
		home .. "/.local/bin",
		home .. "/.local/share/nvim/mason/bin",
		home .. "/go/bin",
		home .. "/.dotfiles/themes",
	}
	for i = #paths, 1, -1 do
		if vim.fn.isdirectory(paths[i]) == 1 and not vim.env.PATH:find(paths[i], 1, true) then
			vim.env.PATH = paths[i] .. ":" .. vim.env.PATH
		end
	end
end

-- basic settings
vim.wo.number = true

vim.o.expandtab = true -- expand tab input with spaces characters
vim.o.smartindent = true -- syntax aware indentations for newline inserts
vim.o.tabstop = 2 -- num of space characters per tab
vim.o.shiftwidth = 2 -- spaces per indentation level

require("config.lazy")
require("config.keymaps")

-- Detect Helm templates as filetype "helm" so yamlfmt doesn't mangle {{ }} delimiters
vim.filetype.add({
	pattern = {
		[".*/helm/.+%.yaml"] = "helm",
		[".*/helm/.+%.tpl"] = "helm",
		[".*/templates/.+%.yaml"] = "helm",
		[".*/templates/.+%.tpl"] = "helm",
	},
})

vim.cmd.colorscheme("catppuccin")

vim.opt.clipboard = "unnamedplus"

-- WSL2: use Windows-native clipboard tools so yanks reach the Windows clipboard
-- (xclip/xsel only write to the X11 selection which doesn't reliably sync via WSLg)
if vim.fn.has("wsl") == 1 then
	vim.g.clipboard = {
		name = "WslClipboard",
		copy = {
			["+"] = "/mnt/c/Windows/System32/clip.exe",
			["*"] = "/mnt/c/Windows/System32/clip.exe",
		},
		paste = {
			["+"] = '/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
			["*"] = '/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
		},
		cache_enabled = 0,
	}
end

-- Diagnostics (virtual_lines shows full message, virtual_text is redundant with it)
vim.diagnostic.config({
	virtual_lines = { only_current_line = true },
	virtual_text = false,
})

-- Folding settings (for nvim-ufo)
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- Fold keymaps (after plugins load, ufo provides these)
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
		vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
		vim.keymap.set("n", "<leader>cf", "<cmd>set foldlevel=0<cr>", { desc = "Fold all" })
		vim.keymap.set("n", "<leader>cu", "<cmd>set foldlevel=99<cr>", { desc = "Unfold all" })
	end,
})
