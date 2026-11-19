<script def>
{
  "navigationBarTitleText": "图像判定助手"
}
</script>

<script setup>
import scanPhoto, { mimeType as scanMime } from '../../assets/scan.jpg';

const VISION_PROMPT = '这是一张扫描到的图片。请判断画面里是什么，属于什么类别或场所，并给出判断依据，控制在三句话内。';

async function blobToDataUrl(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  const chunk = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunk) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunk));
  }
  return `data:${scanMime || 'image/jpeg'};base64,${btoa(binary)}`;
}

function withTimeout(promise, ms, fallback) {
  return Promise.race([
    promise,
    new Promise((resolve) => setTimeout(() => resolve(fallback), ms))
  ]);
}

export default {
  data: {
    phase: 'idle',
    scanOk: false,
    status: '准备扫描…',
    result: '',
    preview: '',
    engine: '-'
  },

  onReady() {
    this.scan();
  },

  async scan() {
    if (this.data.phase === 'scanning') return;
    this.setData({ phase: 'scanning', scanOk: false, result: '', status: '正在扫描…' });
    try {
      // 用包内资源模拟“摄像头扫描到一幅图像”，并转成 Data URL 供模型使用
      await blobToDataUrl(scanPhoto);
      this.setData({
        preview: '../../assets/scan.jpg',
        scanOk: true,
        phase: 'scanned',
        status: '扫描成功'
      });
    } catch (error) {
      this.setData({ phase: 'error', status: `扫描失败：${error.message || error}` });
      return;
    }
    this.judge(await blobToDataUrl(scanPhoto));
  },

  async judge(dataUrl) {
    this.setData({ status: '内置模型判定中…' });
    let availability = 'unavailable';
    try {
      availability = await withTimeout(LanguageModel.availability(), 4000, 'unavailable');
    } catch (error) {
      availability = 'error';
    }
    this.setData({ engine: availability });
    if (availability !== 'available') {
      this.setData({
        phase: 'done',
        status: '扫描成功 · 内置模型仅在真机可用'
      });
      return;
    }
    let session;
    try {
      session = await LanguageModel.create({
        initialPrompts: [{ role: 'system', content: '你是图像判定助手，回答简洁准确。' }]
      });
      const answer = await session.prompt([{
        role: 'user',
        content: [
          { type: 'text', text: VISION_PROMPT },
          { type: 'image_url', image_url: { url: dataUrl } }
        ]
      }]);
      this.setData({ phase: 'done', status: '判定完成', result: answer });
    } catch (error) {
      this.setData({ phase: 'done', status: `判定失败：${error.message || error}` });
    } finally {
      if (session) session.destroy();
    }
  }
};
</script>

<page>
  <view class="container">
    <text class="title">图像判定助手</text>
    <text class="badge {{ scanOk ? 'ok' : '' }}">{{ scanOk ? '扫描成功 ✓' : '未扫描' }}</text>
    <image class="preview" src="{{ preview }}" mode="aspectFill" wx:if="{{ preview }}"></image>
    <text class="status">{{ status }}</text>
    <text class="engine">模型：{{ engine }}</text>
    <text class="result" wx:if="{{ result }}">{{ result }}</text>
    <button bindtap="scan">重新扫描</button>
  </view>
</page>

<style>
.container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100vh;
  padding: 12px;
  box-sizing: border-box;
}
.title {
  color: #40FF5E;
  font-size: 20px;
  margin-bottom: 4px;
}
.badge {
  color: #9ad7a6;
  font-size: 13px;
  border: 1px solid #2f7a3d;
  border-radius: 10px;
  padding: 2px 10px;
  margin-bottom: 6px;
}
.badge.ok {
  color: #06160a;
  background: #40FF5E;
  border-color: #40FF5E;
}
.preview {
  width: 168px;
  height: 112px;
  border-radius: 8px;
  border: 1px solid #2f7a3d;
  margin-bottom: 6px;
}
.status {
  color: #e6ffe9;
  font-size: 14px;
  margin-bottom: 2px;
}
.engine {
  color: #8fb896;
  font-size: 12px;
  margin-bottom: 2px;
}
.result {
  color: #40FF5E;
  font-size: 14px;
  line-height: 19px;
  text-align: center;
}
button {
  margin-top: 8px;
  color: #40FF5E;
  border: 1px solid #40ff5d42;
  border-radius: 10px;
  padding: 5px 14px;
  font-size: 14px;
}
</style>
