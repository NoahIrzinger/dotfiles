local M = {}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.WARN, { title = "search" })
end

local function has(cmd)
	return vim.fn.executable(cmd) == 1
end

local function fd_command(cwd)
	if has("fd") then
		return { "fd", "--type", "f", "--hidden", "--follow", "--exclude", ".git", ".", cwd }
	end
	if has("fdfind") then
		return { "fdfind", "--type", "f", "--hidden", "--follow", "--exclude", ".git", ".", cwd }
	end
	return { "find", cwd, "-type", "f", "-not", "-path", "*/.git/*" }
end

local function select_file_fallback(cwd)
	local cmd = fd_command(cwd)
	vim.system(cmd, { text = true }, function(obj)
		vim.schedule(function()
			if obj.code ~= 0 then
				notify("file finder failed: " .. (obj.stderr or table.concat(cmd, " ")), vim.log.levels.ERROR)
				return
			end
			local files = vim.split(obj.stdout or "", "\n", { trimempty = true })
			if #files == 0 then
				notify("no files found under " .. cwd)
				return
			end
			vim.ui.select(files, {
				prompt = "Files",
				format_item = function(item)
					return vim.fn.fnamemodify(item, ":~:.")
				end,
			}, function(choice)
				if choice then
					vim.cmd.edit(vim.fn.fnameescape(choice))
				end
			end)
		end)
	end)
end

local function telescope_files(cwd)
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		return false
	end
	builtin.find_files({ cwd = cwd, hidden = true, no_ignore = false, follow = true })
	return true
end

local function telescope_grep(cwd, query)
	local ok, builtin = pcall(require, "telescope.builtin")
	if not ok then
		return false
	end
	builtin.live_grep({ cwd = cwd, default_text = query })
	return true
end

local function ensure_fff_picker_ready()
	-- fff.file_search() waits via fff.file_picker.wait_for_initial_scan(), and
	-- that module only flips its Lua-side initialized flag when setup() has run.
	-- The native fff UI does this for itself; Telescope-backed integrations need
	-- to do it explicitly or every search times out waiting for the index.
	local ok, file_picker = pcall(require, "fff.file_picker")
	if ok and file_picker and file_picker.setup then
		pcall(file_picker.setup)
	end
end

local function telescope_fff_files(cwd)
	local ok_fff, fff = pcall(require, "fff")
	local ok_tel, pickers = pcall(require, "telescope.pickers")
	if not (ok_fff and ok_tel and fff.file_search) then
		return false
	end
	ensure_fff_picker_ready()
	local finders = require("telescope.finders")
	local make_entry = require("telescope.make_entry")
	local conf = require("telescope.config").values
	local sorters = require("telescope.sorters")

	pickers
		.new({}, {
			prompt_title = "FFF files",
			cwd = cwd,
			finder = finders.new_dynamic({
				fn = function(prompt)
					local ok, result = pcall(fff.file_search, prompt or "", {
						cwd = cwd,
						mode = "files",
						max_results = 200,
						wait_for_index_ms = 3000,
					})
					if not ok or not result or not result.items then
						return {}
					end
					local out = {}
					for _, item in ipairs(result.items) do
						table.insert(out, item.relative_path or item.name)
					end
					return out
				end,
				entry_maker = make_entry.gen_from_file({ cwd = cwd }),
			}),
			previewer = conf.file_previewer({ cwd = cwd }),
			sorter = sorters.empty(), -- FFF already ranked/fuzzy-sorted the results.
		})
		:find()
	return true
end

local function telescope_fff_grep(cwd, opts)
	local ok_fff, fff = pcall(require, "fff")
	local ok_tel, pickers = pcall(require, "telescope.pickers")
	if not (ok_fff and ok_tel and fff.content_search) then
		return false
	end
	ensure_fff_picker_ready()
	local finders = require("telescope.finders")
	local make_entry = require("telescope.make_entry")
	local conf = require("telescope.config").values
	local sorters = require("telescope.sorters")
	opts = opts or {}

	pickers
		.new({}, {
			prompt_title = "FFF grep",
			cwd = cwd,
			default_text = opts.query,
			finder = finders.new_dynamic({
				fn = function(prompt)
					prompt = prompt or ""
					if prompt == "" then
						return {}
					end
					local mode = "plain"
					if opts.grep and opts.grep.modes and opts.grep.modes[1] then
						mode = opts.grep.modes[1]
					end
					local ok, result = pcall(fff.content_search, prompt, {
						cwd = cwd,
						mode = mode,
						smart_case = true,
						page_size = 200,
						max_matches_per_file = 100,
						wait_for_index_ms = 3000,
					})
					if not ok or not result or not result.items then
						return {}
					end
					local out = {}
					for _, item in ipairs(result.items) do
						local path = item.relative_path or item.name
						local line = item.line_number or 1
						local col = item.col or 1
						local text = item.line_content or ""
						table.insert(out, string.format("%s:%d:%d:%s", path, line, col, text))
					end
					return out
				end,
				entry_maker = make_entry.gen_from_vimgrep({ cwd = cwd }),
			}),
			previewer = conf.grep_previewer({ cwd = cwd }),
			sorter = sorters.empty(),
		})
		:find()
	return true
end

function M.find_files(cwd)
	cwd = vim.fn.fnamemodify(cwd or vim.fn.getcwd(), ":p")
	-- Telescope UI, FFF backend: preserves Telescope's insert/normal-mode picker
	-- ergonomics while replacing fd/rg-style path enumeration with FFF's index.
	if telescope_fff_files(cwd) then
		return
	end
	if telescope_files(cwd) then
		return
	end
	local ok, fff = pcall(require, "fff")
	if ok and fff then
		local opened = pcall(function()
			if fff.find_files_in_dir then
				fff.find_files_in_dir(cwd)
			else
				fff.find_files()
			end
		end)
		if opened then
			return
		end
	end
	select_file_fallback(cwd)
end

function M.live_grep(cwd, opts)
	cwd = vim.fn.fnamemodify(cwd or vim.fn.getcwd(), ":p")
	opts = opts or {}
	-- Same idea for grep: Telescope UI with FFF content_search. Fall back to
	-- Telescope's rg-backed live_grep, then FFF's native UI.
	if telescope_fff_grep(cwd, opts) then
		return
	end
	if telescope_grep(cwd, opts.query) then
		return
	end
	local ok, fff = pcall(require, "fff")
	if ok and fff and fff.live_grep then
		local opened = pcall(function()
			opts.cwd = cwd
			fff.live_grep(opts)
		end)
		if opened then
			return
		end
	end
	notify("no grep UI available (fff/telescope unavailable)", vim.log.levels.ERROR)
end

return M
