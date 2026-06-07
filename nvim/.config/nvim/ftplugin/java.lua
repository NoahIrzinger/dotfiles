local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = vim.fn.expand("~/workspace/") .. project_name
local mason_share = vim.fn.stdpath("data") .. "/mason/share"

local bundles = {
  vim.fn.glob(mason_share .. "/java-debug-adapter/com.microsoft.java.debug.plugin-*.jar", 1),
}
vim.list_extend(bundles, vim.split(vim.fn.glob(mason_share .. "/java-test/*.jar", 1), "\n"))

local config = {
  cmd = {
    "java",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    --"-Dlog.level=ALL",
    "-Dspring.profiles.active=dev",
    "-Xmx1g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",
    "-jar",
    vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
    "-configuration",
    vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
    "-data",
    workspace_dir,
  },
  root_dir = vim.fs.dirname(vim.fs.find({ "gradlew", ".git", "mvnw" }, { upward = true })[1]),
  settings = {
    java = {
      jdt = {
        ls = {
          androidSupport = {
            enabled = true,
          },
        },
      },
    },
  },
  init_options = {
    bundles = bundles,
  },
}
require("jdtls").start_or_attach(config)
