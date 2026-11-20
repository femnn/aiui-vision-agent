<script def>
{
  "navigationBarTitleText": "图像判定助手"
}
</script>

<script setup>
const TARGET_DESC = '一面白墙，墙上有很大的黑色书法字「金」和「鹽（盐）」，上方横匾写着「金字號」，是夜晚的中式老商铺';
const MATCH_PROMPT = `这是眼镜摄像头拍到的画面。${TARGET_DESC}。请判断画面里是否出现上述目标。只要能看到「金」或「鹽」或「金字號」这类字，就回答「是」；完全看不到就回答「否」。只回答一个字：是 或 否。`;

// 与 museum-fieldnotes/lib/device.js 一致的拍照方式：宿主原生相机，直接返回已编码照片
function cameraOptions() {
  return { quality: 'low', mode: 'wide', enableSystemPreview: true };
}

async function capturePhoto() {
  // 1) AIUI 原生相机上下文（眼镜 / Studio 均支持，会弹拍照确认层）
  const camera = (typeof wx === 'undefined') ? null
    : (wx.media && typeof wx.media.createCameraContext === 'function' ? wx.media.createCameraContext() : null);
  if (camera) {
    const photo = await camera.takePhoto(cameraOptions());
    if (!photo || !photo.data || !photo.data.byteLength) throw new Error('相机未返回照片');
    return new Blob([photo.data], { type: photo.mimeType || 'image/jpeg' });
  }
  // 2) 兜底：浏览器相机
  if (typeof ImageCapture !== 'function' || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
    throw new Error('宿主没有相机接口');
  }
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: false,
    video: { facingMode: 'environment', width: { ideal: 640 }, height: { ideal: 480 } }
  });
  try {
    const track = stream.getVideoTracks()[0];
    if (!track) throw new Error('相机未返回画面');
    const blob = await new ImageCapture(track).takePhoto(cameraOptions());
    if (!blob || !blob.size) throw new Error('相机未返回照片');
    return blob;
  } finally {
    stream.getTracks().forEach((t) => t.stop());
  }
}

async function asDataUrl(blob) {
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
    status: '点按镜腿(Enter)或点画面 拍照识别',
    matched: false,
    error: '',
    debug: ''
  },

  onKeyUp(event) {
    if (event && (event.code === 'Enter' || event.code === 'GlobalHook')) this.capture();
  },

  onTap() {
    this.capture();
  },

  async capture() {
    if (this.busy) return;
    this.busy = true;
    this.setData({ status: '请把目标放进取景框并在宿主确认拍照…', error: '', matched: false });
    try {
      const blob = await capturePhoto();
      console.log('[vision] photo bytes=', blob.size, blob.type);
      const dataUrl = await asDataUrl(blob);
      this.setData({ status: '识别中…' });
      await this.judge(dataUrl);
    } catch (err) {
      const msg = String(err && err.message || err);
      console.log('[vision] capture error:', msg);
      this.setData({ status: '', error: `拍照失败：${msg}` });
    } finally {
      this.busy = false;
    }
  },

  async judge(dataUrl) {
    let session;
    try {
      const availability = await timeout(LanguageModel.availability(), 4000, 'timeout');
      console.log('[vision] availability:', availability);
      if (availability !== 'available') {
        this.setData({ status: '', error: '内置模型不可用（请用真机调试）', debug: `模型:${availability}` });
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
      this.setData({
        status: yes ? '识别正确' : '未匹配到目标（可再拍一次）',
        error: '',
        matched: yes,
        debug: `模型:${availability} · 判定:${text.slice(0, 10) || '空'}`
      });
    } catch (err) {
      const msg = String(err && err.message || err);
      console.log('[vision] judge error:', msg);
      this.setData({ status: '', debug: `判定异常: ${msg.slice(0, 40)}` });
    } finally {
      if (session) session.destroy();
    }
  }
};
</script>

<page>
  <view class="stage" bindtap="onTap">
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
.hit {
  position: absolute; left: 0; right: 0; top: 0; bottom: 0;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
}
.hit-mark { color: #40FF5E; font-size: 72px; font-weight: 700; line-height: 80px; }
.hit-text { color: #40FF5E; font-size: 28px; margin-top: 4px; }
.hint { position: absolute; left: 0; right: 0; bottom: 22px; text-align: center; color: #9ad7a6; font-size: 13px; }
.dbg { position: absolute; left: 0; right: 0; bottom: 4px; text-align: center; color: #6f8f76; font-size: 11px; }
</style>
