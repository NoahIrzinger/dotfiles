local set = vim.keymap.set

-- file management
local function get_project_root()
	local cwd = vim.fn.getcwd()
	local git_dir = vim.fn.finddir(".git", cwd .. ";")
	if git_dir == "" then
		return cwd -- Default to current working directory if no .git folder is found
	else
		return vim.fn.fnamemodify(git_dir, ":h") -- Get the parent directory of .git
	end
end

set("n", "<leader>fp", function()
	require("telescope.builtin").find_files({ cwd = get_project_root() })
end, { desc = "Telescope Find Files In Closest Directory with .git" })
set("n", "<leader>fr", function()
	require("telescope.builtin").find_files({ cwd = vim.fn.expand("~/src/http") })
end, { desc = "Telescope Find HTTP Files in /src/requests" })
set("n", "<leader>ff", function()
	require("telescope.builtin").find_files({
		find_command = { "fdfind", "--type", "f", "--color", "never", "--no-ignore-vcs", "--hidden" },
	})
end, { desc = "Telescope Find Files Working Directory" })
--set("n", "<leader>ff", "<cmd>Telescope find_files hidden=true<cr>", { desc = "Telescope Find Files Working Directory" })
--set(
--	"n",
--	"<leader>fh",
--	"<cmd>cd ~ <cr> | <cmd>Telescope find_files hidden=true<cr>",
--	{ desc = "Telescope Find Files Home Directory" }
--)
--set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Telescope live grep" })
set("n", "<leader>fq", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>")
-- this works with '<leader>fg' then search for: "foo" -tsomefolder etc...
set("n", "<leader>fg", function()
	require("telescope.builtin").live_grep({
		vimgrep_arguments = {
			-- all required except `--smart-case`
			"rg",
			"--no-ignore",
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"--smart-case",
		},
	})
	require("telescope").extensions.live_grep_args.live_grep_args()
end, { desc = "Telescope live grep" })
set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Telescope buffers" })
--set('n', '<leader>fh', "<cmd>Telescope help_tags<cr>", { desc = 'Telescope help tags' })

set("n", "<leader>tt", "<cmd>NvimTreeToggle<cr>", { desc = "NvimTree Toggle Working Directory" })
set("n", "<leader>th", "<cmd>cd ~ <cr> | <cmd>NvimTreeToggle<cr>", { desc = "NvimTree Toggle Home Directory" })
set("n", "<leader>fy", "<cmd>NvimTreeFindFile<cr>", { desc = "NvimTree find current file" })

-- language server (formatting handled by conform.nvim)
set("n", "<leader>li", vim.lsp.buf.hover, { desc = "Display Hover Info" })
set("n", "<leader>ld", vim.lsp.buf.definition, { desc = "Go To Definition" })
set("n", "<leader>lr", vim.lsp.buf.references, { desc = "Show References" })
set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Code Actions" })
set("n", "<leader>lc", vim.lsp.buf.rename, { desc = "Rename symbol under cursor" })

-- debugging
set(
	"n",
	"<leader>db",
	"<cmd>lua require('dap').toggle_breakpoint()<cr>",
	{ silent = true, noremap = true, desc = "Debugger Toggle Breakpoint" }
)
set(
	"n",
	"<leader>dn",
	"<cmd>lua require('jdtls').test_nearest_method()<cr>",
	{ noremap = true, desc = "Debugger Test Nearest Method (Unit Test)" }
)
set("n", "<leader>ds", "<cmd>lua require('dap').terminate()<cr>", { noremap = true, desc = "Debugger Terminate" })
-- check for vscode launch.json files first when debugger starts
set("n", "<leader>dc", function()
	if vim.fn.filereadable(".vscode/launch.json") then
		require("dap.ext.vscode").load_launchjs(nil, {})
	end
	require("dap").continue()
end, { noremap = true, desc = "Debugger Continue" })
set("n", "<leader>do", "<cmd>lua require('dap').step_over()<cr>", { noremap = true, desc = "Debugger Step Over" })
set("n", "<leader>di", "<cmd>lua require('dap').step_into()<cr>", { noremap = true, desc = "Debugger Step Into" })
local function open_max_float()
  local width = vim.o.columns
  local height = vim.o.lines - 2 -- subtract cmdline/statusline
  require('dapui').float_element(nil, {
    width = width,
    height = height,
    position = 'center'
  })
end
set("n", "<leader>df", open_max_float, { desc = "Open Floating Element Full Size" })
--set(
--	"n",
--	"<leader>df",
--	"<cmd>lua require('dapui').float_element(nil, {width = 200, height = 200, position = 'center'})<cr>",
--	{ desc = "Open Floating Element" }
--)
set(
	"n",
	"<leader>dl",
	"<cmd>lua require('dapui').float_element('repl', {width = 200, height = 50, position = 'center'})<cr>",
	{ desc = "Open Floating Debug Logs" }
)
-- dapui listeners are configured in the plugin
set("n", "<leader>dt", "<cmd>lua require('dapui').toggle()<cr>", { desc = "Debugger Toggle UI" })

-- plugins
set("n", "<leader>il", "<cmd>Lazy<cr>", { desc = "Lazy Open" })
set("n", "<leader>im", "<cmd>Mason<cr>", { desc = "Mason Open" })

-- http client
set("n", "<leader>re", "<cmd>lua require('kulala').run()<cr>", { silent = true, desc = "Execute HTTP Request" })
set(
	"n",
	"<leader>rt",
	"<cmd>lua require('kulala').toggle_view()<cr>",
	{ silent = true, desc = "Toggle HTTP Request Header and Body" }
)
set("n", "<leader>ri", "<cmd>lua require('kulala').inspect()<cr>", { silent = true, desc = "Inspect Request" })

--terminal
vim.keymap.set("n", "<leader>st", '<CMD>lua require("FTerm").toggle()<CR>')
vim.keymap.set("t", "<leader>st", '<C-\\><C-n><CMD>lua require("FTerm").toggle()<CR>')
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { noremap = true })

--tmux navigation (works with or without tmux)
set("n", "<c-h>", "<cmd>TmuxNavigateLeft<cr>")
set("n", "<c-j>", "<cmd>TmuxNavigateDown<cr>")
set("n", "<c-k>", "<cmd>TmuxNavigateUp<cr>")
set("n", "<c-l>", "<cmd>TmuxNavigateRight<cr>")

vim.api.nvim_set_keymap("n", "<leader>-", ":split<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>\\", ":vsplit<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "j", "<Plug>(accelerated_jk_gj)", {})
vim.api.nvim_set_keymap("n", "k", "<Plug>(accelerated_jk_gk)", {})

-- Toggle Code Suggestions on/off with CTRL-g in normal mode:
--set('n', '<leader>gg', '<Plug>(GitLabToggleCodeSuggestions)')
--
--
vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<CR>', { desc = 'Toggle Claude Code' })
