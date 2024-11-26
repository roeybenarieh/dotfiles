local function get_python_interpreter_path()
  -- the VIRTUAL_ENV variable is set by the venv-selector plugin, but I couldn't make it work(cant get the env variable although exists in terminal)
  -- in case of nil, the default debugpy interpreter will be used
  return require("venv-selector").python() or nil
end
local function get_python_dap_rules()
  -- these rules are not documented. they are only present in debugpy code.
  -- the code is at the function _convert_rules_to_exclude_filters in the url:
  -- https://github.com/microsoft/debugpy/blob/42853a99c4d3d4d27e4960c8894d780d4f091d68/src/debugpy/_vendored/pydevd/_pydevd_bundle/pydevd_process_net_command_json.py#L1
  local modules_to_exclude = {
    "runpy",
    "pytest",
    "neotest_python",
    "pluggy",
    "_pytest",
  }
  local rules = {}
  for _, module in ipairs(modules_to_exclude) do
    table.insert(rules, { module = module, include = false })
  end
  return rules
end

return {
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      -- code from lazyvim
      local path = require("mason-registry").get_package("debugpy"):get_install_path()
      require("dap-python").setup(path .. "/venv/bin/python", {
        include_configs = true,
        -- ignore the lsp warning, nvim-dap-python expect a string, but I want that every time the
        -- configuration is called, the function get_python_interpreter_path is called(just like the configuration below)
        pythonPath = get_python_interpreter_path,
      })

      -- for more information about nvim-dap python configurations:
      -- https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings
      -- add python debug configurations
      local dap = require("dap")
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch main.py",
        program = "main.py",
        pythonPath = get_python_interpreter_path,
      })
      -- change every configuration to not use just my code
      for _, config in ipairs(dap.configurations.python) do
        config["justMyCode"] = false
        config["rules"] = get_python_dap_rules()
      end
    end,
  },
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        ["neotest-python"] = {
          -- Extra arguments for nvim-dap configuration
          -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
          dap = {
            justMyCode = false,
            rules = get_python_dap_rules(),
          },
          -- neotest can calculate the python interpreter path by using VIRTUAL_ENV, but just for uniformity.
          python = get_python_interpreter_path,
          -- !!EXPERIMENTAL!! Enable shelling out to `pytest` to discover test
          -- instances for files containing a parametrize mark (default: false)
          pytest_discover_instances = true,
        },
      },
    },
  },
}
