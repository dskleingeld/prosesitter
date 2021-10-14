local log = require("prosesitter/log")
local shared = require("prosesitter/shared")
local marks = require("prosesitter/on_event/marks/marks")
local api = vim.api

M = {}

local function format(issues)
	return { "todo" }
end

-- open hover window if lint error on current pos else return
function M.popup()
	local row, col = unpack(api.nvim_win_get_cursor(0))
	local start = { row - 1, col } -- row needs to be zero indexed for get_extmarks
	local stop = { row - 1, 0 } -- search entire line, TODO handle multi line extmarks
	local mark = marks.get_closest_mark(start, stop)

	if mark == nil then
		return false
	end

	local id = mark[1][1]
	local issues = shared.issues:for_id(id)

	vim.lsp.util.open_floating_preview(format(issues), "markdown", {})
end

return M
