return {
	-- theme
	{ "nvim-web-devicons" },
	{
		"catppuccin/nvim",
		config = function()
			-- Apply the active theme from the dotfiles theme registry (the `theme`
			-- CLI picks which). Wrapped so :ThemeReload can swap palettes live.
			local function apply()
				package.loaded["config.theme"] = nil
				local theme = require("config.theme").load()
				require("catppuccin").setup({
					flavour = (theme and theme.flavour) or "latte",
					color_overrides = (theme and { all = theme.colors }) or {},
				custom_highlights = function(colors)
					return {
						LineNr = { fg = colors.surface1 },
						CursorLineNr = { fg = colors.overlay2 },
						CursorLine = { bg = colors.surface0 },
						ColorColumn = { bg = colors.surface0 },
						Visual = { bg = colors.surface1 },
						MsgArea = { fg = colors.subtext0 },
						TabLine = { bg = colors.mantle },
						TabLineFill = { bg = colors.mantle },
						TabLineSel = { fg = colors.subtext0, bg = colors.base },

						GitSignsAdd = { fg = colors.green },
						GitSignsChange = { fg = colors.yellow },
						GitSignsDelete = { fg = colors.red },
						TelescopeBorder = { fg = colors.subtext0 },

						Constant = { fg = colors.blue },
						String = { fg = colors.subtext0 },
						Character = { fg = colors.subtext0 },
						Number = { fg = colors.blue },
						Boolean = { fg = colors.blue },
						Float = { fg = colors.blue },
						Identifier = { fg = colors.green },
						Function = { fg = colors.green },
						Statement = { fg = colors.green },
						Conditional = { fg = colors.green },
						Repeat = { fg = colors.green },
						Label = { fg = colors.green },
						Operator = { fg = colors.subtext0 },
						Keyword = { fg = colors.green },
						Exception = { fg = colors.green },
						PreProc = { fg = colors.yellow },
						Include = { fg = colors.yellow },
						Define = { fg = colors.yellow },
						Macro = { fg = colors.yellow },
						PreCondit = { fg = colors.yellow },
						Type = { fg = colors.blue },
						StorageClass = { fg = colors.overlay2 },
						Structure = { fg = colors.subtext0 },
						Special = { fg = colors.overlay2 },
						SpecialChar = { fg = colors.overlay2 },
					}
				end,
				})
				vim.cmd.colorscheme("catppuccin")
				return theme
			end
			apply()
			-- `theme set <name>` rewrites the registry; :ThemeReload re-reads it live.
			vim.api.nvim_create_user_command("ThemeReload", function()
				local t = apply()
				vim.notify("theme -> " .. ((t and t.name) or "default (no registry)"))
			end, {})
		end,
	},
	{
		"sphamba/smear-cursor.nvim",
		opts = { -- Default  Range
			stiffness = 0.8, -- 0.6      [0, 1]
			trailing_stiffness = 0.5, -- 0.3      [0, 1]
			distance_stop_animating = 0.5, -- 0.1      > 0
		},
	},

	-- productivity
	{
		"rainbowhxch/accelerated-jk.nvim",
		opts = {
			acceleration_limit = 150,
		},
	},
	{
		"christoomey/vim-tmux-navigator",
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
		},
		keys = {},
	},
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		opts = function(_, opts)
			opts.auto_install = true
			opts.highlight = { enable = true }
			opts.indent = { enable = true }
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		opts = {
			options = {
				theme = "ayu_dark",
			},
		},
	},
	{
		"nvim-telescope/telescope.nvim",
		cmd = "Telescope",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope-live-grep-args.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		},
		opts = function(_, opts)
			local telescope = require("telescope")
			telescope.load_extension("ui-select")
			telescope.load_extension("live_grep_args")
			telescope.load_extension("fzf")
			opts.defaults = {
				file_ignore_patterns = {
					"node_modules",
					".npm",
					"android",
					"venv",
					"bin/src",
					"bin/*/com",
					"build/*",
					"bin/*",
				},
			}
		end,
	},
	{
		"nvim-telescope/telescope-ui-select.nvim",
		dependencies = { "nvim-telescope/telescope.nvim" },
		-- opts as a FUNCTION so `require("telescope.themes")` runs when the plugin
		-- loads (telescope on the runtime path), not at spec-eval (cold start, where
		-- telescope isn't loaded yet -> "module 'telescope.themes' not found").
		opts = function()
			return {
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			}
		end,
	},
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
		},
		cmd = { "NvimTreeToggle", "NvimTreeFindFile" },
		config = function()
			local HEIGHT_RATIO = 0.8 -- You can change this
			local WIDTH_RATIO = 0.5 -- You can change this too

			require("nvim-tree").setup({
				view = {
					float = {
						enable = true,
						open_win_config = function()
							local screen_w = vim.opt.columns:get()
							local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
							local window_w = screen_w * WIDTH_RATIO
							local window_h = screen_h * HEIGHT_RATIO
							local window_w_int = math.floor(window_w)
							local window_h_int = math.floor(window_h)
							local center_x = (screen_w - window_w) / 2
							local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()
							return {
								border = "rounded",
								relative = "editor",
								row = center_y,
								col = center_x,
								width = window_w_int,
								height = window_h_int,
							}
						end,
					},
					width = function()
						return math.floor(vim.opt.columns:get() * WIDTH_RATIO)
					end,
				},
			})
			-- this part doesn't seem to work to resize..
			local api = require("nvim-tree.api")

			vim.api.nvim_create_augroup("NvimTreeResize", {
				clear = true,
			})

			vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
				group = "NvimTreeResize",
				callback = function()
					-- Get the nvim-tree window ID
					local winid = api.tree.winid()
					if winid then
						api.tree.reload()
					end
				end,
			})
		end,
		--opts = {
		--	sort = {
		--		sorter = "case_sensitive",
		--	},
		--	filters = {
		--		dotfiles = true,
		--	},
		--	git = {
		--		ignore = false,
		--	},
		--	disable_netrw = true,
		--	hijack_netrw = true,
		--	respect_buf_cwd = true,
		--	sync_root_with_cwd = true,
		--},
	},
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		event = "VeryLazy",
		config = function()
			local harpoon = require("harpoon")
			harpoon:setup({})

			-- basic telescope configuration
			local conf = require("telescope.config").values
			local function toggle_telescope(harpoon_files)
				local file_paths = {}
				for _, item in ipairs(harpoon_files.items) do
					table.insert(file_paths, item.value)
				end

				require("telescope.pickers")
					.new({}, {
						prompt_title = "Harpoon",
						finder = require("telescope.finders").new_table({
							results = file_paths,
						}),
						previewer = conf.file_previewer({}),
						sorter = conf.generic_sorter({}),
					})
					:find()
			end

			vim.keymap.set("n", "<leader>fh", function()
				toggle_telescope(harpoon:list())
			end, { desc = "Open harpoon window" })

			vim.keymap.set("n", "<leader>ha", function()
				harpoon:list():add()
			end, { desc = "Harpoon add file" })
			vim.keymap.set("n", "<leader>hd", function()
				harpoon:list():remove()
			end, { desc = "Harpoon remove file" })
			-- harpoon quick-select on <leader>1-4. (was <C-h/t/n/s>, but <C-h>
			-- collided with TmuxNavigateLeft and broke seamless tmux<>nvim nav.)
			vim.keymap.set("n", "<leader>1", function()
				harpoon:list():select(1)
			end, { desc = "Harpoon file 1" })
			vim.keymap.set("n", "<leader>2", function()
				harpoon:list():select(2)
			end, { desc = "Harpoon file 2" })
			vim.keymap.set("n", "<leader>3", function()
				harpoon:list():select(3)
			end, { desc = "Harpoon file 3" })
			vim.keymap.set("n", "<leader>4", function()
				harpoon:list():select(4)
			end, { desc = "Harpoon file 4" })

			-- Toggle previous & next buffers stored within Harpoon list
			vim.keymap.set("n", "<leader>hj", function()
				harpoon:list():prev()
			end, { desc = "Harpoon prev" })
			vim.keymap.set("n", "<leader>hk", function()
				harpoon:list():next()
			end, { desc = "Harpoon next" })
		end,
	},
	{
		"numToStr/FTerm.nvim",
		cmd = "FTermToggle",
		keys = {
			{ "<leader>st", '<cmd>lua require("FTerm").toggle()<cr>', desc = "Toggle terminal" },
		},
		opts = {
			border = "double",
			dimensions = {
				height = 0.9,
				width = 0.9,
			},
		},
	},
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {},
	},

	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {
			-- name the leader prefixes so the popup reads as a menu, not raw keys
			spec = {
				{ "<leader>f", group = "find" },
				{ "<leader>t", group = "tree" },
				{ "<leader>l", group = "lsp" },
				{ "<leader>d", group = "debug" },
				{ "<leader>h", group = "harpoon" },
				{ "<leader>r", group = "http" },
				{ "<leader>i", group = "tools" },
				{ "<leader>s", group = "term" },
			},
		},
		keys = {
			{
				"<leader>?",
				function()
					require("which-key").show({ global = false })
				end,
				desc = "Buffer Local Keymaps (which-key)",
			},
		},
	},

	--language servers and auto-completion
	{
		"L3MON4D3/LuaSnip",
		dependencies = {
			"saadparwaiz1/cmp_luasnip",
			"rafamadriz/friendly-snippets",
		},
		opts = {},
	},

	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		opts = function(_, opts)
			local cmp = require("cmp")
			require("luasnip.loaders.from_vscode").lazy_load() -- adds backup snippets from friendly snippets
			opts.snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
				end,
			}
			opts.window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			}
			opts.mapping = cmp.mapping.preset.insert({
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
			})
			opts.sources = cmp.config.sources({
				{ name = "nvim_lsp" }, -- get snippets from the LSP
				{ name = "luasnip" }, -- get snippets from luasnip
				{ name = "buffer" },
			})
		end,
	},
	{ "hrsh7th/cmp-nvim-lsp" },
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			vim.lsp.config("gopls", {
				capabilities = capabilities,
				settings = {
					gopls = {
						completeUnimported = true,
						analyses = {
							unusedparams = true,
						},
						staticcheck = true,
						gofumpt = true,
						usePlaceholders = true,
					},
				},
			})
			vim.lsp.config("html", {
				capabilities = capabilities,
				settings = {},
			})
			vim.lsp.config("htmx", {
				capabilities = capabilities,
				settings = {},
			})
			vim.lsp.config("gradle_ls", {
				capabilities = capabilities,
				settings = {},
			})
			vim.lsp.config("lua_ls", {
				capabilities = capabilities,
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							checkThirdParty = false,
						},
						telemetry = { enable = false },
					},
				},
			})
			-- basedpyright: enhanced pyright fork with better code actions including auto-import
			vim.lsp.config("basedpyright", {
				capabilities = capabilities,
				settings = {
					basedpyright = {
						disableOrganizeImports = true, -- ruff handles this
						analysis = {
							autoImportCompletions = true,
							typeCheckingMode = "standard",
						},
					},
				},
			})
			vim.lsp.config("ruff", {
				capabilities = capabilities,
				init_options = {
					settings = {
						lineLength = 100,
						lint = { enable = true },
					},
				},
			})

			vim.lsp.config("omnisharp", {
				capabilities = capabilities,
				settings = {
					FormattingOptions = {
						EnableEditorConfigSupport = true,
						OrganizeImports = true,
					},
					RoslynExtensionsOptions = {
						EnableAnalyzersSupport = true,
						EnableImportCompletion = true,
						AnalyzeOpenDocumentsOnly = true,
					},
				},
			})

			vim.lsp.enable({ "gopls", "html", "htmx", "gradle_ls", "lua_ls", "basedpyright", "ruff", "omnisharp" })

			---- TODO where is lemminx from?
			--lspconfig.lemminx.setup({
			--  capabilities = capabilities,
			--})
			--lspconfig.kotlin_language_server.setup({
			--  capabilities = capabilities,
			--})
			--lspconfig.gradle_ls.setup({
			--  capabilities = capabilities,
			--})
			--lspconfig.ts_ls.setup({
			--  capabilities = capabilities,
			--})
			--lspconfig.htmx.setup({
			--  capabilities = capabilities,
			--})
			--lspconfig.lua_ls.setup({
			--  capabilities = capabilities,
			--})
			--capabilities.textDocument.completion.completionItem.snippetSupport = true
			--lspconfig.terraformls.setup({
			--  capabilities = capabilities,
			--})
			--lspconfig.gopls.setup({
			--  capabilities = capabilities,
			--  settings = {
			--    gopls = {
			--      completeUnimported = true,
			--      analyses = {
			--        unusedparams = true,
			--      },
			--      staticcheck = true,
			--      gofumpt = true,
			--      usePlaceholders = true,
			--    },
			--  },
			--})
			----lspconfig.gitlab_lsp.setup({
			----	capabilities = capabilities,
			----})
			----lspconfig.yamlls.setup({
			----  on_attach = function(client, bufnr)
			----    client.server_capabilities.documentFormattingProvider = true
			----    --on_attach(client, bufnr)
			----end,
			----  capabilities = capabilities,
			----  settings = {
			----    yaml = {
			----      schemas = {
			----        ["https://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/schemas/v3.0/schema.yaml"] = "/*",
			----      },
			----    },
			----  },
			----})
		end,
	},
	-- formatting with conform.nvim (replaces none-ls for Neovim 0.11 compatibility)
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>lf",
				function()
					require("conform").format({ async = true, lsp_fallback = true })
				end,
				mode = "",
				desc = "Format buffer",
			},
		},
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "black" },
				go = { "goimports-reviser", "gofumpt", "golines" },
				javascript = { "prettierd", "prettier", stop_after_first = true },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				yaml = { "yamlfmt" },
				cs = { "csharpier" },
			},
			formatters = {
				golines = {
					prepend_args = { "-m", "250" },
				},
			},
			format_on_save = function(bufnr)
				local path = vim.api.nvim_buf_get_name(bufnr)
				-- Skip formatting for GitLab CI files and CI/CD templates
				if path:match("gitlab%-ci") or path:match("%.gitlab%-ci%.ya?ml") then
					return nil
				end
				return { timeout_ms = 500, lsp_fallback = true }
			end,
		},
	},

	-- debugging
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
		opts = {},
	},
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			--dap.config_overrides = {
			--	vmArgs = "-Dspring.profiles.active=dev",
			--}
			dap.configurations.java = {
				{
					name = "Debug (nvim-dap) - Spring Boot local DEBUG - Default Profile",
					request = "launch",
					type = "java",
					-- 	--args = {},
					--vmArgs = "-Dlogging.level.root=info -Dlogging.level.com.example.app=info",
					vmArgs = "-Dlogging.level.root=debug -Dlogging.level.com.example.app=debug",
				},
				{
					name = "Debug (nvim-dap) - Spring Boot local DEBUG",
					request = "launch",
					type = "java",
					-- 	--args = {},
					--vmArgs = "-Dlogging.level.root=info -Dlogging.level.com.example.app=info -Dspring.profiles.active=local",
					vmArgs = "-Dlogging.level.root=debug -Dlogging.level.com.example.app=debug -Dspring.profiles.active=local",
				},
				{
					name = "Debug (nvim-dap) - Spring Boot local INFO",
					request = "launch",
					type = "java",
					-- 	--args = {},
					vmArgs = "-Dlogging.level.root=info -Dlogging.level.com.example.app=info -Dspring.profiles.active=local",
					--vmArgs = "-Dlogging.level.root=debug -Dlogging.level.com.example.app=debug -Dspring.profiles.active=local",
				},
				{
					name = "Debug (nvim-dap) - Current File",
					request = "launch",
					type = "java",
					-- 	--args = {},
					--vmArgs = "-Dlogging.level.root=info -Dlogging.level.com.example.app=info -Dspring.profiles.active=local",
					--vmArgs = "-Dlogging.level.root=debug -Dlogging.level.com.example.app=debug -Dspring.profiles.active=local",
				},
			}

			-- C# / .NET debugging with netcoredbg
			dap.adapters.coreclr = {
				type = "executable",
				command = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg",
				args = { "--interpreter=vscode" },
			}

			dap.configurations.cs = {
				{
					type = "coreclr",
					name = "Launch - netcoredbg",
					request = "launch",
					program = function()
						return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
					end,
					cwd = function()
						return vim.fn.getcwd()
					end,
					env = {
						DOTNET_ROOT = "/usr/lib/dotnet",
					},
				},
				{
					type = "coreclr",
					name = "Launch current project",
					request = "launch",
					program = function()
						local cwd = vim.fn.getcwd()
						local project_name = vim.fn.fnamemodify(cwd, ":t")
						local possible_paths = {
							cwd .. "/bin/Debug/net8.0/" .. project_name .. ".dll",
							cwd .. "/bin/Debug/net7.0/" .. project_name .. ".dll",
							cwd .. "/bin/Debug/net6.0/" .. project_name .. ".dll",
						}
						for _, path in ipairs(possible_paths) do
							if vim.fn.filereadable(path) == 1 then
								return path
							end
						end
						return vim.fn.input("Path to dll: ", cwd .. "/bin/Debug/", "file")
					end,
					cwd = function()
						return vim.fn.getcwd()
					end,
					env = {
						DOTNET_ROOT = "/usr/lib/dotnet",
					},
					stopAtEntry = false,
				},
				{
					type = "coreclr",
					name = "Attach to process",
					request = "attach",
					processId = require("dap.utils").pick_process,
				},
			}

			dap.listeners.before.attach.dapui_config = function()
				dapui.open()
			end
			dap.listeners.before.launch.dapui_config = function()
				dapui.open()
			end
			--dap.listeners.before.event_terminated.dapui_config = function()
			--	dapui.close()
			--end
			--dap.listeners.before.event_exited.dapui_config = function()
			--	dapui.close()
			--end
		end,
	},
	{
		"mfussenegger/nvim-dap-python",
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			local dap = require("dap")
			local dap_python = require("dap-python")

			dap.adapters.python = {
				type = "executable",
				-- command = python_path,
				args = { "-m", "debugpy.adapter" },
			}

			-- Add default configurations
			dap.configurations.python = {
				{
					type = "python",
					request = "launch",
					name = "Launch file (nvim-dap)",
					program = "${file}",
					--  pythonPath = get_python_path,
				},
				{
					type = "python",
					request = "launch",
					name = "Launch module (nvim-dap)",
					module = "main",
					-- pythonPath = get_python_path,
				},
			}
			dap_python.setup()
		end,
	},
	{
		"leoluz/nvim-dap-go",
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			local dap = require("dap")
			local dap_go = require("dap-go")
			dap_go.setup({
				dap_configurations = {
					{
						type = "go",
						name = "Debug cmd/main.go",
						request = "launch",
						program = "${file}",
					},
				},
			})

			-- Route program stdout/stderr to an integrated terminal buffer
			-- instead of the REPL for all Go debug configurations
			for _, config in ipairs(dap.configurations.go) do
				config.console = "integratedTerminal"
			end
		end,
	},
	{
		"mfussenegger/nvim-jdtls",
		dependencies = { "mfussenegger/nvim-dap" },
		--  these settings do not work
		--config = function()

		--	settings = {
		--		java = {
		--			configuration = {
		--				-- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
		--				-- And search for `interface RuntimeOption`
		--				-- The `name` is NOT arbitrary, but must match one of the elements from `enum ExecutionEnvironment` in the link above
		--				runtimes = {
		--					{
		--						name = "Java 17",
		--						path = "/usr/lib/jvm/java-17-openjdk-amd64/",
		--					},
		--				},
		--			},
		--		},
		--	}
		--end,
		-- these settings are not needed the default config works
		--opts = function(_, opts)
		--  local config = {
		--    cmd = { "/path/to/jdt-language-server/bin/jdtls" },
		--    root_dir = vim.fs.dirname(vim.fs.find({ "gradlew", ".git", "mvnw" }, { upward = true })[1]),
		--  }
		--  require("jdtls").start_or_attach(config)
		--end,
	},
	{
		"mxsdev/nvim-dap-vscode-js",
		dependencies = { "mfussenegger/nvim-dap" },
		opts = function(_, opts)
			-- node_path = "node", -- Path of node executable. Defaults to $NODE_PATH, and then "node"
			--
			opts.debugger_path = vim.fn.stdpath("data") .. "/mason/bin"
			opts.adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" }
			opts.debugger_cmd = { "js-debug-adapter" } -- Command to use to launch the debug server. Takes precedence over `node_path` and `debugger_path`.
			-- which adapters to register in nvim-dap
			-- log_file_path = "(stdpath cache)/dap_vscode_js.log" -- Path for file logging
			-- log_file_level = false -- Logging level for output to file. Set to false to disable file logging.
			-- log_console_level = vim.log.levels.ERROR -- Logging level for output to console. Set to false to disable console output.
			for _, language in ipairs({ "typescript", "javascript", "javascriptreact" }) do
				require("dap").configurations[language] = {
					{
						type = "pwa-node",
						request = "launch",
						name = "Launch file",
						program = "${file}",
						cwd = "${workspaceFolder}",
					},
					{
						type = "pwa-node",
						request = "attach",
						name = "Attach",
						processId = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					},
				}
			end
		end,
	},
	-- package management
	{
		"williamboman/mason.nvim",
		lazy = false,
		opts = {},
	},

	-- coding helpers
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = true,
		-- use opts = {} for passing setup options
	},

	--	{"rest-nvim/rest.nvim",},
	{
		"mistweaverco/kulala.nvim",
		config = function()
			local kulala = require("kulala")
			kulala.setup({
				default_env = "local",
				global_keymaps = true,
				global_keymaps_prefix = "<leader>R",
				kulala_keymaps_prefix = "",
				additional_curl_options = {
					"--insecure",
				},
			})
		end,

		--opts = {
		--	--display_mode = "float",
		--	split_direction = "vertical",
		--	content_types = {
		--		["application/json"] = {
		--			formatter = { "jq", "." },
		--		},
		--	},
		--},
	},
	{
		"kevinhwang91/nvim-ufo",
		event = "BufReadPost",
		dependencies = { "kevinhwang91/promise-async" },
		config = function()
			require("ufo").setup({
				provider_selector = function(bufnr, filetype, buftype)
					return { "treesitter", "indent" }
				end,
			})
		end,
	},
	{
		"greggh/claude-code.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim", -- Required for git operations
		},
		config = function()
			require("claude-code").setup({
				window = {
					position = "float",
					float = {
						width = "90%", -- Take up 90% of the editor width
						height = "90%", -- Take up 90% of the editor height
						row = "center", -- Center vertically
						col = "center", -- Center horizontally
						relative = "editor",
						border = "double", -- Use double border style
					},
				},
			})
		end,
	},
	--{
	--  "https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim.git",
	--  -- Activate when a file is created/opened
	--  event = { "BufReadPre", "BufNewFile" },
	--  -- Activate when a supported filetype is open
	--  ft = { "go", "javascript", "python", "ruby" },
	--  cond = function()
	--    -- Only activate if token is present in environment variable.
	--    -- Remove this line to use the interactive workflow.
	--    return vim.env.GITLAB_TOKEN ~= nil and vim.env.GITLAB_TOKEN ~= ""
	--  end,
	--  opts = {
	--    minimal_message_level = vim.log.levels.DEBUG,
	--    statusline = {
	--      -- Hook into the built-in statusline to indicate the status
	--      -- of the GitLab Duo Code Suggestions integration
	--      enabled = true,
	--    },
	--  },
	--  code_suggestions = {
	--    -- For the full list of default languages, see the 'auto_filetypes' array in
	--    -- https://gitlab.com/gitlab-org/editor-extensions/gitlab.vim/-/blob/main/lua/gitlab/config/defaults.lua
	--    auto_filetypes = { "go", "python", "javascript" }, -- Default is { 'ruby' }
	--    ghost_text = {
	--      enabled = true,                               -- ghost text is an experimental feature
	--      toggle_enabled = "<leader>ge",
	--      accept_suggestion = "<leader>ga",
	--      clear_suggestions = "<leader>gc",
	--      stream = true,
	--    },
	--  },
	--},
}
