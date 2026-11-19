<script def>
{
  "navigationBarTitleText": "图像判定助手"
}
</script>

<script setup>
// 目标描述：改这里即可换成你要识别的目标
const TARGET_DESC = '夜间白墙黑瓦的中式商铺墙面，墙上写有大号书法字「金」和「鹽（盐）」，并挂有横匾「金字號」';
const MATCH_PROMPT = `目标：${TARGET_DESC}。下面是眼镜摄像头当前画面。若画面中明显出现该目标，只回答「是」；否则只回答「否」。不要解释。`;
const CHECK_INTERVAL = 3000; // 每 3 秒用镜头抓一帧判定一次

async function blobToDataUrl(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  const chunk = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunk) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunk));
  }
  return `data:${blob.type || 'image/jpeg'};base64,${btoa(binary)}`;
}

export default {
  data: {
    previewSrc: '',     // 摄像头实时画面
    cameraReady: false,
    matched: false,     // 是否识别正确
    status: '正在启动摄像头…',
    error: ''
  },

  onReady() {
    this.start();
  },

  onHide() {
    this.stop();
  },

  onUnload() {
    this.stop();
  },

  async start() {
    const mediaDevices = typeof navigator !== 'undefined' ? navigator.mediaDevices : null;
    if (!mediaDevices || typeof mediaDevices.getUserMedia !== 'function') {
      this.setData({ status: '', error: '当前环境无摄像头' });
      return;
    }
    try {
      const stream = await mediaDevices.getUserMedia({
        audio: false,
        video: { facingMode: 'environment', width: 640, height: 360 }
      });
      const track = stream.getVideoTracks()[0];
      if (!track) throw new Error('摄像头没有视频轨道');
      this.stream = stream;
      this.imageCapture = new ImageCapture(track);
      this.previewUrl = URL.createObjectURL(stream);
      this.setData({ previewSrc: this.previewUrl, cameraReady: true, status: '', error: '' });
      this.loopTimer = setInterval(() => this.tick(), CHECK_INTERVAL);
      setTimeout(() => this.tick(), 1400);
    } catch (error) {
      this.setData({ status: '', error: `摄像头不可用：${error.message || error}` });
    }
  },

  stop() {
    if (this.loopTimer) clearInterval(this.loopTimer);
    this.loopTimer = null;
    if (this.stream && this.stream.getTracks) {
      this.stream.getTracks().forEach((t) => t.stop());
    }
    this.stream = null;
    this.imageCapture = null;
    if (this.previewUrl && typeof URL !== 'undefined' && URL.revokeObjectURL) {
      URL.revokeObjectURL(this.previewUrl);
    }
    this.previewUrl = '';
  },

  async grabFrameDataUrl() {
    const frame = await this.imageCapture.grabFrame();
    try {
      const w = 320;
      const h = Math.max(120, Math.round((w * (frame.height || 180)) / (frame.width || 320)));
      const canvas = new Canvas(w, h);
      canvas.getContext('2d').drawImage(frame, 0, 0, w, h);
      const blob = await canvas.convertToBlob({ type: 'image/jpeg', quality: 0.7 });
      return await blobToDataUrl(blob);
    } finally {
      frame.close();
    }
  },

  async tick() {
    if (this.busy || !this.imageCapture || this.unloaded) return;
    this.busy = true;
    let session;
    try {
      const availability = await LanguageModel.availability();
      if (availability !== 'available') {
        this.setData({ error: '内置模型不可用（需真机）' });
        return;
      }
      const dataUrl = await this.grabFrameDataUrl();
      session = await LanguageModel.create({
        initialPrompts: [{ role: 'system', content: '你是图像匹配器，只回答「是」或「否」。' }]
      });
      const answer = await session.prompt([{
        role: 'user',
        content: [
          { type: 'text', text: MATCH_PROMPT },
          { type: 'image_url', image_url: { url: dataUrl } }
        ]
      }]);
      const text = String(answer || '').replace(/\s/g, '');
      const yes = text.includes('是') && !text.includes('否') && !text.includes('不') && !text.includes('没');
      if (yes) {
        this.setData({ matched: true, status: '' });
      }
    } catch (error) {
      // 单帧失败不打断，继续下一轮
      this.setData({ error: '' });
    } finally {
      if (session) session.destroy();
      this.busy = false;
    }
  }
};
</script>

<page>
  <view class="stage">
    <!-- 正常情况：只显示镜头实时画面 -->
    <video
      class="camera {{ cameraReady ? 'on' : '' }}"
      src="{{ previewSrc }}"
      autoplay
      muted
      object-fit="cover"
    />

    <!-- 识别正确时，才在画面上叠加提示 -->
    <view class="hit" ink:if="{{ matched }}">
      <text class="hit-mark">✓</text>
      <text class="hit-text">识别正确</text>
    </view>

    <text class="hint" ink:if="{{ error }}">{{ error }}</text>
    <text class="hint" ink:if="{{ status }}">{{ status }}</text>
  </view>
</page>

<style>
.stage {
  position: relative;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background: #000000;
}
.camera {
  position: absolute;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
}
.camera.on {
  opacity: 1;
}
.hit {
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  bottom: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}
.hit-mark {
  color: #40FF5E;
  font-size: 72px;
  font-weight: 700;
  line-height: 80px;
}
.hit-text {
  color: #40FF5E;
  font-size: 28px;
  margin-top: 4px;
}
.hint {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 8px;
  text-align: center;
  color: #9ad7a6;
  font-size: 13px;
}
</style>
