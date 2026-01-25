#!/usr/bin/env python3
"""为魔兽世界技能生成 OGG 格式语音文件"""

import os
import sys
import json
import subprocess
from pathlib import Path
from dotenv import load_dotenv
from azure.cognitiveservices.speech import SpeechConfig, SpeechSynthesizer, AudioConfig
from azure.identity import DefaultAzureCredential


class SkillAudioGenerator:
    """技能语音生成器：使用 Azure TTS 生成 OGG 音频文件"""
    
    def __init__(self, output_dir="../../src/Sounds", voice="zh-CN-XiaoyiNeural", speech_rate="1.5"):
        load_dotenv()
        
        self.region = os.getenv("AZURE_SPEECH_REGION")
        self.voice = voice
        self.speech_rate = speech_rate
        
        output_path = Path(output_dir)
        self.output_dir = output_path if output_path.is_absolute() else (Path(__file__).parent / output_dir).resolve()
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.temp_dir = Path(__file__).parent / "temp"
        self.temp_dir.mkdir(exist_ok=True)
        
        self._init_azure_auth()
        self._print_init_info()
    
    def _init_azure_auth(self):
        """初始化 Azure 认证"""
        self.credential = DefaultAzureCredential()
        token = self.credential.get_token("https://cognitiveservices.azure.com/.default")
        resource_id = os.getenv("AZURE_SPEECH_RESOURCE_ID")
        
        if not resource_id:
            raise ValueError("AZURE_SPEECH_RESOURCE_ID not found in .env file")
        
        authorization_token = f"aad#{resource_id}#{token.token}"
        
        self.speech_config = SpeechConfig(subscription="dummy", region=self.region)
        self.speech_config.authorization_token = authorization_token
        self.speech_config.speech_synthesis_voice_name = self.voice
    
    def _print_init_info(self):
        """打印初始化信息"""
    def _print_init_info(self):
        """打印初始化信息"""
        print(f"✅ 初始化完成")
        print(f"   输出目录: {self.output_dir}")
        print(f"   语音: {self.voice}")
        print(f"   语速: {self.speech_rate}")
        print(f"   区域: {self.region}")
    
    def text_to_ogg(self, text, filename, ssml=None):
        """将文本转换为 OGG 音频文件"""
        output_ogg = self.output_dir / filename
        
        # Check if file exists to skip redundant generation
        if output_ogg.exists():
            print(f"⏩ 跳过 (已存在): {filename}")
            return True

        temp_wav = self.temp_dir / f"{Path(filename).stem}.wav"
        
        try:
            audio_config = AudioConfig(filename=str(temp_wav))
            synthesizer = SpeechSynthesizer(speech_config=self.speech_config, audio_config=audio_config)
            
            if ssml:
                result = synthesizer.speak_ssml_async(ssml).get()
            else:
                ssml_text = self._build_ssml(text)
                result = synthesizer.speak_ssml_async(ssml_text).get()
            
            if result.reason.name != "SynthesizingAudioCompleted":
                print(f"❌ 合成失败: {result.reason}")
                if result.cancellation_details:
                    print(f"   详情: {result.cancellation_details.error_details}")
                return False
            
            if not self._convert_to_ogg(temp_wav, output_ogg):
                return False
            
            print(f"✅ {filename}: '{text}'")
            
            if temp_wav.exists():
                temp_wav.unlink()
            
            return True
        except Exception as e:
            print(f"❌ 错误: {e}")
            return False
    
    def _build_ssml(self, text):
        """构建 SSML 标记"""
        # 智能语速调整 (User Requested: 2字=1.2倍, >2字=1.5倍)
        # 只有在默认语速 (1.5) 下才生效，允许通过命令行覆盖
        rate = self.speech_rate
        if rate == "1.5":
            clean_text = text.strip()
            if len(clean_text) <= 2:
                rate = "1.2"
            else:
                rate = "1.5"
        
        print(f"   ℹ️  智能语速: '{text}' -> {rate}x")

        return f"""<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN">
    <voice name="{self.voice}">
        <prosody rate="{rate}">{text}</prosody>
    </voice>
</speak>"""
    
    def _convert_to_ogg(self, wav_file, ogg_file):
        """使用 FFmpeg 将 WAV 转换为 OGG (单声道, 44.1kHz, 128kbps)"""
        try:
            result = subprocess.run(['which', 'ffmpeg'], capture_output=True, text=True)
            if result.returncode != 0:
                print("❌ 未找到 ffmpeg，请安装: sudo apt install ffmpeg")
                return False
            
            cmd = [
                'ffmpeg', '-i', str(wav_file),
                '-filter:a', 'volume=2.5',  # 增加音量 (约 +8dB)
                '-acodec', 'libvorbis',
                '-ac', '1',
                '-ar', '44100',
                '-b:a', '128k',
                '-y',
                str(ogg_file)
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"❌ FFmpeg 转换失败: {result.stderr}")
                return False
            
            return True
        except Exception as e:
            print(f"❌ 转换错误: {e}")
            return False
    
    def generate_from_file(self, text_file):
        """从文本文件批量生成音频 (格式: 技能名称:文件名.ogg)"""
        skills = []
        
        with open(text_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                
                if not line or line.startswith('#'):
                    continue
                
                separator = ':' if ':' in line else '：'
                if separator not in line:
                    print(f"⚠️  跳过第 {line_num} 行（格式错误）: {line}")
                    continue
                
                parts = line.split(separator, 1)
                if len(parts) != 2:
                    print(f"⚠️  跳过第 {line_num} 行（格式错误）: {line}")
                    continue
                
                text = parts[0].strip()
                filename = parts[1].strip()
                
                if text and filename:
                    skills.append({'text': text, 'filename': filename})
        
        if not skills:
            print("❌ 未找到有效的技能配置")
            return
        
        self._batch_generate(skills)
    
    def generate_from_json(self, json_file):
        """从 JSON 文件批量生成音频"""
        with open(json_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        skills = config.get('skills', [])
        self._batch_generate(skills)
    def _batch_generate(self, skills):
        """批量生成音频文件"""
        total = len(skills)
        success = 0
        
        print(f"\n🎤 开始生成 {total} 个技能语音...")
        print("=" * 60)
        
        for i, skill in enumerate(skills, 1):
            filename = skill['filename']
            text = skill['text']
            ssml = skill.get('ssml')
            
            print(f"\n[{i}/{total}] {filename}")
            
            if self.text_to_ogg(text, filename, ssml):
                success += 1
        
        print("\n" + "=" * 60)
        print(f"✅ 完成: {success}/{total} 成功")
        print(f"📁 输出目录: {self.output_dir}")


def print_usage():
    """打印使用说明"""
    print("用法:")
    print("  1. 单个文件: python generate.py <文本> <文件名.ogg> [语音] [语速] [输出目录]")
    print("  2. 批量生成: python generate.py <配置文件.txt> [语音] [语速] [输出目录]")
    print("  3. JSON格式:  python generate.py --json <配置文件.json> [语音] [语速] [输出目录]")
    print("\n文本配置格式（每行一个技能）:")
    print("  技能名称:文件名.ogg")
    print("\n参数说明:")
    print("  语速: 0.5-2.0 的数字，或 slow/medium/fast（默认 1.5）")
    print("\n示例:")
    print("  python generate.py '冲锋' Charge.ogg")
    print("  python generate.py skills.txt")
    print("  python generate.py skills.txt zh-CN-YunxiNeural 1.8")
    print("  python generate.py skills.txt zh-CN-XiaoxiaoNeural fast ./output")
    print("\n默认输出目录: ../../src/Sounds")


def main():
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)
    
    if sys.argv[1] == '--json':
        if len(sys.argv) < 3:
            print("❌ 请指定 JSON 配置文件")
            sys.exit(1)
        
        json_file = sys.argv[2]
        voice = sys.argv[3] if len(sys.argv) > 3 else "zh-CN-XiaoxiaoNeural"
        speech_rate = sys.argv[4] if len(sys.argv) > 4 else "1.5"
        output_dir = sys.argv[5] if len(sys.argv) > 5 else "../../src/Sounds"
        
        generator = SkillAudioGenerator(output_dir=output_dir, voice=voice, speech_rate=speech_rate)
        generator.generate_from_json(json_file)
    
    elif len(sys.argv) >= 3:
        text = sys.argv[1]
        filename = sys.argv[2]
        voice = sys.argv[3] if len(sys.argv) > 3 else "zh-CN-XiaoxiaoNeural"
        speech_rate = sys.argv[4] if len(sys.argv) > 4 else "1.5"
        output_dir = sys.argv[5] if len(sys.argv) > 5 else "../../src/Sounds"
        
        generator = SkillAudioGenerator(output_dir=output_dir, voice=voice, speech_rate=speech_rate)
        success = generator.text_to_ogg(text, filename)
        sys.exit(0 if success else 1)
    
    else:
        config_file = sys.argv[1]
        voice = sys.argv[2] if len(sys.argv) > 2 else "zh-CN-XiaoxiaoNeural"
        speech_rate = sys.argv[3] if len(sys.argv) > 3 else "1.5"
        output_dir = sys.argv[4] if len(sys.argv) > 4 else "../../src/Sounds"
        
        if not Path(config_file).exists():
            print(f"❌ 文件不存在: {config_file}")
            sys.exit(1)
        
        generator = SkillAudioGenerator(output_dir=output_dir, voice=voice, speech_rate=speech_rate)
        generator.generate_from_file(config_file)

if __name__ == "__main__":
    main()
