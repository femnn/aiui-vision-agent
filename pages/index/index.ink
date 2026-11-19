<script def>
{
  "navigationBarTitleText": "图像判定助手"
}
</script>

<script setup>
// 目标描述：改这里即可换成你要识别的目标
const TARGET_DESC = '一面白墙，墙上有很大的黑色书法字「金」和「鹽（盐）」，上方横匾写着「金字號」，是夜晚的中式老商铺';
const MATCH_PROMPT = `这是眼镜摄像头的画面。${TARGET_DESC}。请判断画面里是否出现上述目标。只要能看到「金」或「鹽」或「金字號」这类字，就回答「是」；完全看不到就回答「否」。只回答一个字：是 或 否。`;
const INTERVAL = 1600;

async function blobToDataUrl(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  const chunk = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunk) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunk));
  }
  return `data:${blob.type || 'image/jpeg'};base64,${btoa(binary)}`;
}

function timeout(promise, ms, fallback) {
  return Promise.race([promise, new Promise((r) => setTimeout(() => r(fallback), ms))]);
}

export default {
  data: {
    frameSrc: '',
    matched: false,
    grabMode: false,      // true=自动抓帧；false=按 Enter/点按拍照
    status: '正在启动摄像头…',
    error: '',
    debug: ''
  },

  onReady() { this.start(); },
  onHide() { this.stop(); },
  onUnload() { this.stop(); },

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
      if (!track) throw new Error('无视频轨道');
      this.stream = stream;
      this.imageCapture = new ImageCapture(track);
      console.log('[vision] camera ready');
      // 探测：能否用 grabFrame+Canvas 编码（真机可，Web 模拟器不可）
      try {
        const url = await this.captureFrame();
        this.setData({ grabMode: true, frameSrc: url, status: '' });
        console.log('[vision] grab mode OK');
        await this.judge(url);
        this.loop();
      } catch (e) {
        console.log('[vision] grab unsupported, fallback to takePhoto:', String(e && e.message || e));
        this.setData({ grabMode: false, status: '点按镜腿(Enter)或点画面 拍照识别', error: '' });
      }
    } catch (error) {
      console.log('[vision] start failed:', String(error && error.message || error));
      this.setData({ status: '', error: `摄像头不可用：${error.message || error}` });
    }
  },

  stop() {
    if (this.loopTimer) clearTimeout(this.loopTimer);
    this.loopTimer = null;
    this.unloaded = true;
    if (this.stream && this.stream.getTracks) this.stream.getTracks().forEach((t) => t.stop());
    this.stream = null;
    this.imageCapture = null;
  },

  // 真机路径：grabFrame + Canvas 编码
  async captureFrame() {
    const frame = await this.imageCapture.grabFrame();
    try {
      const w = 384;
      const h = Math.max(120, Math.round((w * (frame.height || 216)) / (frame.width || 384)));
      const canvas = new Canvas(w, h);
      canvas.getContext('2d').drawImage(frame, 0, 0, w, h);
      const blob = await canvas.convertToBlob({ type: 'image/jpeg', quality: 0.72 });
      return await blobToDataUrl(blob);
    } finally {
      frame.close && frame.close();
    }
  },

  // 模拟器路径：takePhoto 直接给编码好的图片（会弹一次拍照确认层）
  async captureOnce() {
    if (!this.imageCapture) return;
    this.setData({ status: '拍照中…', error: '' });
    try {
      const photo = await this.imageCapture.takePhoto({ quality: 'normal', mode: 'telephoto', enableSystemPreview: false });
      const url = await blobToDataUrl(photo);
      console.log('[vision] takePhoto ok size=', photo && photo.size);
      this.setData({ frameSrc: url, status: '识别中…' });
      await this.judge(url);
    } catch (e) {
      const msg = String(e && e.message || e);
      console.log('[vision] takePhoto failed:', msg);
      this.setData({ status: '', error: `拍照失败：${msg}` });
    }
  },

  async loop() {
    if (this.unloaded || !this.data.grabMode) return;
    await this.tick();
    if (this.unloaded) return;
    this.loopTimer = setTimeout(() => this.loop(), INTERVAL);
  },

  async tick() {
    try {
      const dataUrl = await this.captureFrame();
      this.setData({ frameSrc: dataUrl });
      await this.judge(dataUrl);
    } catch (error) {
      const msg = String(error && error.message || error);
      console.log('[vision] tick error:', msg);
      this.setData({ debug: `抓帧异常: ${msg.slice(0, 40)}` });
    }
  },

  async judge(dataUrl) {
    let session;
    try {
      const availability = await timeout(LanguageModel.availability(), 4000, 'timeout');
      console.log('[vision] availability:', availability);
      if (availability !== 'available') {
        this.setData({ error: '内置模型不可用（请用真机调试）', status: '', debug: `模型:${availability}` });
        return;
      }
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
      const text = String(answer || '').trim();
      console.log('[vision] answer:', text);
      const compact = text.replace(/\s/g, '');
      const yes = (compact.includes('是') || /^y/i.test(compact)) && !compact.includes('否');
      this.setData({ status: '', error: '', debug: `模型:${availability} · 判定:${text.slice(0, 12) || '空'}` });
      if (yes) this.setData({ matched: true });
    } catch (error) {
      const msg = String(error && error.message || error);
      console.log('[vision] judge error:', msg);
      this.setData({ debug: `判定异常: ${msg.slice(0, 40)}` });
    } finally {
      if (session) session.destroy();
    }
  },

  onKeyUp(event) {
    if (event && (event.code === 'Enter' || event.code === 'GlobalHook')) {
      if (!this.data.grabMode) this.captureOnce();
    }
  },

  onTap() {
    if (!this.data.grabMode) this.captureOnce();
  }
};
</script>

<page>
  <view class="stage" bindtap="onTap">
    <image class="cam" src="{{ frameSrc }}" mode="aspectFill" ink:if="{{ frameSrc }}" />

    <view class="hit" ink:if="{{ matched }}">
      <text class="hit-mark">✓</text>
      <text class="hit-text">识别正确</text>
    </view>

    <text class="hint" ink:if="{{ error }}">{{ error }}</text>
    <text class="hint" ink:if="{{ status }}">{{ status }}</text>
    <text class="dbg" ink:if="{{ debug }}">{{ debug }}</text>
  </view>
</page>

<style>
.stage { position: relative; width: 100vw; height: 100vh; overflow: hidden; background: #000000; }
.cam { position: absolute; left: 0; top: 0; width: 100%; height: 100%; }
.hit {
  position: absolute; left: 0; right: 0; top: 0; bottom: 0;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
}
.hit-mark { color: #40FF5E; font-size: 72px; font-weight: 700; line-height: 80px; }
.hit-text { color: #40FF5E; font-size: 28px; margin-top: 4px; }
.hint { position: absolute; left: 0; right: 0; bottom: 22px; text-align: center; color: #9ad7a6; font-size: 13px; }
.dbg { position: absolute; left: 0; right: 0; bottom: 4px; text-align: center; color: #6f8f76; font-size: 11px; }
</style>
