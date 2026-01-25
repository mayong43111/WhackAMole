# WhackAMole 技能语音生成工具

使用 Azure 语音服务为魔兽世界技能生成中文语音提示文件。

## 功能

- 从文本配置文件批量生成技能语音
- 自动转换为 OGG 格式（单声道，44.1kHz，128kbps）
- 与现有 WhackAMole 插件完全兼容
- 支持 Azure AD 安全认证

## 前置条件

- Azure 订阅账户
- Python 3.7+
- FFmpeg（用于音频格式转换）

## 创建 Azure 语音服务

### 使用 Azure CLI

如果尚未安装 Azure CLI，请访问 [安装 Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)。

```bash
# 登录 Azure
az login

# 创建资源组
az group create \
  --name WhackAMole-TTS-RG \
  --location eastasia

# 创建免费层语音服务
az cognitiveservices account create \
  --name whackamole-tts-speech \
  --resource-group WhackAMole-TTS-RG \
  --kind SpeechServices \
  --sku F0 \
  --location eastasia \
  --yes

# 配置 Azure AD 权限
az role assignment create \
  --role "Cognitive Services User" \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope $(az cognitiveservices account show \
    --name whackamole-tts-speech \
    --resource-group WhackAMole-TTS-RG \
    --query id -o tsv)
```

### 定价层说明

- **F0 (免费层)**: 每月 5 小时音频输出，足够生成数百个技能语音
- **S0 (标准层)**: 按使用量付费

## 配置文件说明

### .env 文件

已包含在项目中，包含以下配置：

```env
AZURE_SPEECH_REGION=eastasia
AZURE_SPEECH_RESOURCE_ID=/subscriptions/.../whackamole-tts-speech
AZURE_SPEECH_ENDPOINT=https://whackamole-tts-speech.cognitiveservices.azure.com/
```

**注意**: 使用 Azure AD 认证时，`AZURE_SPEECH_RESOURCE_ID` 是必需的。TTS 服务使用特殊的授权格式：`aad#{resourceId}#{token}`。

### skills.txt 文件格式

```
# 注释行以 # 开头
# 格式：技能中文名:输出文件名.ogg

冲锋:Charge.ogg
斩杀:Execute.ogg
```

**规则：**
- 每行一个技能
- 使用 `:` 或 `：` 分隔
- 支持 `#` 注释
- 空行会被忽略

### 语速设置

默认语速为 **1.5 倍速**，适合游戏内快速播报技能名称。

**可用值：**
- 数字：`0.5` 到 `2.0`（如 `1.0`, `1.5`, `1.8`）
- 关键字：`slow`（慢速）、`medium`（正常）、`fast`（快速）

**时长参考**（以"利刃风暴"4个字为例）：
- 1.0x：~1.48秒
- 1.5x：~0.98秒 ✅ 推荐
- 2.0x：~0.74秒

## 可用语音

- `zh-CN-XiaoxiaoNeural` - 女声（默认）
- `zh-CN-YunxiNeural` - 男声
- `zh-CN-YunyangNeural` - 男声
- 更多语音请参考 [Azure 语音库](https://docs.microsoft.com/azure/cognitive-services/speech-service/language-support#neural-voices)

## 常见问题

### 认证失败

**问题**: `DefaultAzureCredential failed to retrieve a token`

**解决方案**:
```bash
# 确保已登录 Azure CLI
az logout
az login

# 检查权限
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv)
```

### FFmpeg 未找到

**问题**: `未找到 ffmpeg`

**解决方案**:
```bash
# Debian/Ubuntu
sudo apt install ffmpeg

# macOS
brew install ffmpeg

# Red Hat/CentOS/Rocky (使用静态编译版本)
cd /tmp
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz
sudo cp ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/
```

### 音频质量调整

默认设置：单声道，44.1kHz，128kbps，1.5倍语速

**调整语速**：通过命令行参数指定（见上方示例）

**调整音频格式**：如需修改采样率或比特率，编辑 [generate.py](generate.py) 中的 `_convert_to_ogg` 方法。

### 免费层配额

F0 免费层限制：
- 每月 500 万字符
- 每月 5 小时音频输出

对于 WhackAMole 的使用场景（几百个短语音），免费层完全足够。

## 文件结构

```
tools/TTS/
├── README.md           # 本文档
├── requirements.txt    # Python 依赖
├── .env               # Azure 配置（不提交到 Git）
├── .gitignore         # Git 忽略规则
├── generate.py        # 语音生成脚本
├── skills.txt         # 技能配置文件
├── venv/              # Python 虚拟环境（不提交）
├── temp/              # 临时 WAV 文件（不提交）
└── dist/              # 测试输出目录（不提交）
```

## 参考资源

- [Azure 语音服务文档](https://docs.microsoft.com/azure/cognitive-services/speech-service/)
- [Python SDK 文档](https://docs.microsoft.com/python/api/azure-cognitiveservices-speech/)
- [语音库](https://docs.microsoft.com/azure/cognitive-services/speech-service/language-support#neural-voices)
- [定价信息](https://azure.microsoft.com/pricing/details/cognitive-services/speech-services/)

## 快速开始

### 1. 安装 FFmpeg

```bash
# Debian/Ubuntu
sudo apt install ffmpeg

# macOS
brew install ffmpeg

# Red Hat/CentOS/Rocky (静态编译版本)
cd /tmp && wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz && \
tar xf ffmpeg-release-amd64-static.tar.xz && \
sudo cp ffmpeg-*-amd64-static/ffmpeg /usr/local/bin/

# Windows - 下载并安装
# https://ffmpeg.org/download.html
```

### 2. 创建虚拟环境并安装依赖

```bash
cd tools/TTS

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate  # Linux/macOS
# Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

### 3. 配置 Azure 凭据

确保已使用 Azure CLI 登录：

```bash
az login
```

### 4. 编辑技能列表

编辑 [skills.txt](skills.txt) 文件，格式为：

```
技能中文名:输出文件名.ogg
```

示例：
```
冲锋:Charge.ogg
斩杀:Execute.ogg
致死打击:MortalStrike.ogg
```

### 5. 生成语音文件

```bash
# 批量生成（使用默认设置：1.5倍速，输出到 ../../src/Sounds/）
python generate.py skills.txt

# 测试生成（输出到 dist/ 目录）
python generate.py "利刃风暴" TestBladestorm.ogg zh-CN-XiaoxiaoNeural 1.5 ./dist

# 单独生成一个（使用默认语速）
python generate.py "冲锋" Charge.ogg

# 自定义语速（1.8倍速）
python generate.py skills.txt zh-CN-XiaoxiaoNeural 1.8

# 使用关键字设置语速
python generate.py skills.txt zh-CN-XiaoxiaoNeural fast

# 使用其他语音（男声）+ 自定义语速
python generate.py skills.txt zh-CN-YunxiNeural 1.5

# 完整示例：自定义语音、语速和输出目录
python generate.py skills.txt zh-CN-YunxiNeural 1.8 ./dist
```

**参数说明：**
- 单个文件模式：`python generate.py <文本> <文件名.ogg> [语音] [语速] [输出目录]`
- 批量生成模式：`python generate.py <配置文件.txt> [语音] [语速] [输出目录]`
- JSON格式：`python generate.py --json <配置文件.json> [语音] [语速] [输出目录]`

**可选参数：**
- 语音：默认 `zh-CN-XiaoxiaoNeural`（女声）
- 语速：默认 `1.5`（1.5倍速，推荐）
- 输出目录：默认 `../../src/Sounds/`

**输出目录：**
- 默认：`../../src/Sounds/`（相对于 tools/TTS）
- 测试：`./dist/`（不提交到 Git，用于测试）

**生成的文件：**
- 格式：Ogg Vorbis
- 规格：单声道，44.1kHz，~128kbps
- 兼容性：与现有 WhackAMole 音频文件完全兼容
