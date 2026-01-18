-- run_tests.lua
-- Main Entry point for running tests locally

-- Ensure we can require files from current directory
package.path = package.path .. ";./?.lua"

print("====================================")
print("  WhackAMole Unit Test Suit")
print("====================================")

local runner_utils = require("Tests.Test_Utils")
runner_utils:Run()

local runner_spec = require("Tests.Test_SpecDetection")
runner_spec:Run()
