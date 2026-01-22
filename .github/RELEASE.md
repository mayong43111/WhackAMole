# WhackAMole Release Guide

## 发布新版本

### 1. 准备发布

1. **确认所有更改已提交并推送**
   ```bash
   git status
   git add .
   git commit -m "描述你的更改"
   git push
   ```

2. **更新版本号**（可选，workflow会自动更新）
   - 编辑 `src/WhackAMole.toc`
   - 修改 `## Version:` 行

### 2. 创建并推送 Tag

```bash
# 创建 tag（版本号格式：v主版本.次版本.修订号）
git tag v1.2.0

# 推送 tag 到 GitHub（触发自动发布）
git push origin v1.2.0
```

**版本号规范**：
- **主版本号**（Major）：重大功能变更或架构改变
- **次版本号**（Minor）：新功能添加
- **修订号**（Patch）：Bug修复和小改进

### 3. 自动发布流程

推送 tag 后，GitHub Actions 会自动：
1. ✅ 检出代码
2. ✅ 提取版本号
3. ✅ 更新 TOC 文件中的版本号
4. ✅ 打包插件（`WhackAMole-版本号.zip`）
5. ✅ 生成 Changelog（基于 git commits）
6. ✅ 创建 GitHub Release
7. ✅ 上传 zip 包到 Release

### 4. 查看发布结果

访问仓库的 Releases 页面：
```
https://github.com/你的用户名/WhackAMole/releases
```

## 本地测试打包

在推送 tag 前，可以本地测试打包：

```bash
# 创建临时目录
mkdir -p build/WhackAMole

# 复制文件
cp -r src/* build/WhackAMole/

# 创建 zip
cd build
zip -r WhackAMole-test.zip WhackAMole

# 验证内容
unzip -l WhackAMole-test.zip
```

## 回滚发布

如果需要删除错误的 release：

```bash
# 删除本地 tag
git tag -d v1.2.0

# 删除远程 tag
git push origin --delete v1.2.0
```

然后在 GitHub 网页上删除对应的 Release。

## 示例工作流

```bash
# 1. 完成开发工作
git add .
git commit -m "新增冰霜死骑T1套装支持"
git push

# 2. 创建版本标签
git tag v1.3.0
git push origin v1.3.0

# 3. 等待 GitHub Actions 完成（约1-2分钟）

# 4. 在 Releases 页面下载 WhackAMole-1.3.0.zip
```

## 故障排查

### Workflow 失败

1. 查看 Actions 页面的错误日志
2. 常见问题：
   - TOC 文件路径错误
   - 权限问题（GITHUB_TOKEN）
   - zip 命令不可用

### 版本号冲突

如果相同版本号的 tag 已存在：
```bash
# 删除本地和远程 tag
git tag -d v1.2.0
git push origin --delete v1.2.0

# 创建新 tag
git tag v1.2.1
git push origin v1.2.1
```

## 注意事项

- ⚠️ Tag 一旦推送就会触发发布，请谨慎操作
- ✅ 推荐在推送 tag 前先测试所有功能
- ✅ 确保 TOC 版本号与 tag 版本号一致
- ✅ Changelog 会自动基于 git commits 生成，确保 commit message 清晰
