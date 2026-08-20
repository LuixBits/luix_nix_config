local M = {}

-- neotest-phpunit assumes that Neovim and PHPUnit see identical paths. These
-- project commands deliberately run PHPUnit in Docker, where the application
-- is mounted at /var/www/html. Keep that project-specific boundary here while
-- leaving discovery, JUnit parsing, diagnostics, and status handling to the
-- upstream adapter.
local project_profiles = {
	{
		marker = "bin/roiguard",
		command = { "bin/roiguard", "phpunit" },
		container_root = "/var/www/html",
	},
	{
		marker = "bin/webshop",
		command = { "bin/webshop", "phpunit" },
		container_root = "/var/www/html",
	},
}

local function joinpath(...)
	return vim.fs.joinpath(...)
end

local function profile_for_root(root)
	if not root then
		return nil
	end

	for _, profile in ipairs(project_profiles) do
		if vim.uv.fs_stat(joinpath(root, profile.marker)) then
			return profile
		end
	end
end

local function relative_path(root, path)
	local relative = vim.fs.relpath(root, path)
	if relative and relative ~= "." and relative ~= ".." and not vim.startswith(relative, "../") then
		return relative
	end
end

local function prepare_results_file(root)
	local result_dir = joinpath(root, ".phpunit.cache")
	vim.fn.mkdir(result_dir, "p")

	local token = vim.fn.fnamemodify(vim.fn.tempname(), ":t")
	local relative = joinpath(".phpunit.cache", "neotest-" .. token .. ".xml")
	local absolute = joinpath(root, relative)

	-- The host creates the report and the container truncates it. A
	-- world-writable file avoids depending on matching host/container UIDs.
	require("neotest.lib").files.write(absolute, "")
	assert(vim.uv.fs_chmod(absolute, 438), "Could not make PHPUnit result file writable")

	return relative, absolute
end

---@param adapter neotest.Adapter
---@return neotest.Adapter
function M.wrap(adapter)
	local upstream_root = adapter.root
	local upstream_build_spec = adapter.build_spec
	local upstream_results = adapter.results

	adapter.root = function(dir)
		local root = upstream_root(dir)
		if root then
			return root
		end

		-- Webshop is commonly opened at its repository root while its PHP
		-- application (and composer.json) lives below src/html.
		local repository_root = vim.fs.root(dir, ".git") or dir
		local nested_root = joinpath(repository_root, "src", "html")
		if profile_for_root(nested_root) then
			return nested_root
		end
	end

	adapter.build_spec = function(args)
		local position = args.tree:data()
		local root = args.tree:root():data().path
		local profile = profile_for_root(root)

		if not profile then
			return upstream_build_spec(args)
		end

		if args.strategy == "dap" then
			error(
				"PHPUnit runs in Docker through the project command; "
					.. "Docker test debugging is not configured. Run it with <leader>tn instead."
			)
		end

		local report_relative, report_absolute = prepare_results_file(root)
		local command = vim.deepcopy(profile.command)
		command[1] = joinpath(root, command[1])

		local test_path = relative_path(root, position.path)
		if test_path then
			table.insert(command, test_path)
		end

		table.insert(command, "--log-junit=" .. report_relative)

		if position.type == "test" then
			vim.list_extend(command, {
				"--filter",
				"::" .. position.name .. "( with data set .*)?$",
			})
		end

		vim.list_extend(command, args.extra_args or {})

		return {
			command = command,
			cwd = root,
			env = args.env,
			context = {
				luix_phpunit = true,
				results_path = report_absolute,
				host_root = root,
				container_root = profile.container_root,
			},
		}
	end

	adapter.results = function(spec, process_result, tree)
		if not (spec.context and spec.context.luix_phpunit) then
			return upstream_results(spec, process_result, tree)
		end

		local lib = require("neotest.lib")
		local logger = require("neotest.logging")
		local output_file = spec.context.results_path
		local ok, data = pcall(lib.files.read, output_file)
		pcall(vim.uv.fs_unlink, output_file)

		if not ok or data == "" then
			logger.error("PHPUnit did not create a JUnit report:", output_file)
			return {}
		end

		local container_pattern = spec.context.container_root:gsub("([^%w])", "%%%1")
		data = data:gsub(container_pattern, function()
			return spec.context.host_root
		end)

		local parsed_ok, parsed = pcall(lib.xml.parse, data)
		if not parsed_ok then
			logger.error("Failed to parse PHPUnit JUnit report:", output_file)
			return {}
		end

		local results_ok, results =
			pcall(require("neotest-phpunit.utils").get_test_results, parsed, process_result.output)
		if not results_ok then
			logger.error("Failed to collect PHPUnit results:", results)
			return {}
		end

		return results
	end

	return adapter
end

return M
