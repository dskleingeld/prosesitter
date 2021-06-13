local shared = require("functions/prosesitter/shared")
local query = require("vim.treesitter.query")
local get_parser = vim.treesitter.get_parser
local api = vim.api

local cfg = shared.cfg
local ns = shared.ns
local prose_check_iter = shared.prose_check_iter

local M = {}

local function add_extmark(bufnr, lnum, start_col, end_col)
	-- TODO: This errors because of an out of bounds column when inserting
	-- newlines. Wrapping in pcall hides the issue.

	local ok, _ = pcall(api.nvim_buf_set_extmark, bufnr, ns, lnum, start_col, {
		end_line = lnum,
		end_col = end_col,
		hl_group = cfg.hl_id,
		ephemeral = true,
	})

	if not ok then
		print(("ERROR: Failed to add extmark, lnum=%d pos=%d"):format(lnum, end_col))
	end
end

local hl_queries = {}
function M:on_line(_, winid, bufnr, lnum)
	local parser = get_parser(bufnr)
	local hl_query = hl_queries[parser:lang()]
	local line = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]

	parser:for_each_tree(function(tstree, _)
		local root_node = tstree:root()
		local root_start_row, _, root_end_row, _ = root_node:range()

		-- Only worry about trees within the line range
		if root_start_row > lnum or root_end_row < lnum then
			return
		end

		for id, node in hl_query:iter_captures(root_node, bufnr, lnum, lnum + 1) do
			if vim.tbl_contains(cfg.captures, hl_query.captures[id]) then
				local start_row, start_col, end_row, end_col = node:range()
				if lnum ~= start_row then
					start_col = 0
				end
				if lnum ~= end_row then
					end_col = -1
				end
				local prose = line:sub(start_col + 1, end_col)
				for p_start, p_end in prose_check_iter(prose) do
					add_extmark(bufnr, lnum, start_col + p_start, start_col + p_end)
				end
			end
		end
	end)
end

function M:on_win(_, _, bufnr)
	if not api.nvim_buf_is_loaded(bufnr) or api.nvim_buf_get_option(bufnr, "buftype") ~= "" then
		return false
	end
	if vim.tbl_isempty(cfg.captures) then
		return false
	end
	local ok, parser = pcall(get_parser, bufnr)
	if not ok then
		return false
	end
	local lang = parser:lang()
	if not hl_queries[lang] then
		hl_queries[lang] = query.get_query(lang, "highlights")
	end
	-- FIXME: shouldn't be required. Possibly related to:
	-- https://github.com/nvim-treesitter/nvim-treesitter/issues/1124
	parser:parse()
end

return M
