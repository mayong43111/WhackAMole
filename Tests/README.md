# WhackAMole 单元测试

这个目录包含了 WhackAMole 插件核心逻辑的单元测试。
为了在游戏外运行这些测试（例如在 VS Code 中），我们使用了 `MockWoW.lua` 来模拟魔兽世界 API 环境。

## 目录结构
*   **`run_tests.lua`**: 测试入口脚本，负责运行所有测试用例。
*   **`MockWoW.lua`**: 模拟 WoW API (如 `UnitClass`, `GetTalentTabInfo` 等)。
*   **`TestRunner.lua`**: 轻量级的单元测试框架（包含断言和报告功能）。
*   **`Test_*.lua`**: 各个模块的具体测试用例。
*   **`lua_dist/`**: 包含便携版的 Lua 5.1 解释器（Windows）。

## 运行测试

测试需要在插件根目录 (`WhackAMole/`) 下运行，以确保能正确加载项目文件。

### 方法 1: 使用内置 Lua (推荐)
如果你已经完整拉取了项目（包含了 `Tests/lua_dist`），可以直接在 VS Code 的终端（PowerShell）中运行：

```powershell
& ".\Tests\lua_dist\lua5.1.exe" ".\Tests\run_tests.lua"
```

### 方法 2: 使用系统 Lua
如果你本地已安装 Lua 5.1 并配置了环境变量，可以直接运行：

```bash
lua Tests/run_tests.lua
```

## 查看结果

运行命令后，控制台将输出测试报告：

*   **[PASS]** 表示测试通过。
*   **[FAIL]** 表示测试失败，并会显示具体的错误信息和行号。
*   底部会有汇总信息，例如 `Summary: 7 Passed, 0 Failed`。

示例输出：
```text
====================================
  WhackAMole Unit Test Suit
====================================
--------------------------------------------------
Running Tests (3)...
--------------------------------------------------
[PASS] formatKey should normalize strings
[PASS] formatKey should remove special chars
[PASS] deepCopy should copy tables recursively
...
--------------------------------------------------
Summary: 7 Passed, 0 Failed
--------------------------------------------------
```