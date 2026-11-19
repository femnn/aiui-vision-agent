# 图像判定助手 (AIUI / Rokid Glasses)

运行在 Rokid 带屏 AI 眼镜上的 AIUI 智能体：**平视时看到的就是镜头实时画面**；当镜头捕捉到指定目标图像（例：夜景「金字號」传统商铺）时，画面才叠加 **「识别正确 ✓」**。

## 交互设计

- 正常状态：全屏显示摄像头实时画面（`<video>` + `MediaStream`），**不显示任何静态照片**。
- 判定：每 3 秒用 `ImageCapture.grabFrame()` 抓一帧，缩到 320 宽后交给**设备内置多模态模型**判断是否出现目标。
- 命中：画面中央叠加绿色「✓ 识别正确」；未命中则继续只显示镜头画面。

## 能力

- 实时预览：`getUserMedia({ video: { facingMode: 'environment' } })` → `URL.createObjectURL(stream)` → `<video>`
- 抓帧：`ImageCapture.grabFrame()` → 离屏 `Canvas` → `convertToBlob()` → Data URL
- 判定：内置 `LanguageModel`（`image_url` 多模态，需真机）
- 权限：`CAMERA`

## 目录

```
.
├── AGENTS.md             智能体身份与说明
├── app.json              页面 / 权限
├── app.js                应用级逻辑
├── assets/scan.jpg       目标参考图（仅参考，不在界面显示）
└── pages/index/index.ink  页面：实时预览 + 抓帧判定 + 识别正确提示
```

## 换成你自己的识别目标

修改 `pages/index/index.ink` 顶部的 `TARGET_DESC`（目标描述），内置模型会据此判断镜头画面是否命中。

## 在 AIUI Studio 导入

在「导入项目 → GitHub 子目录导入」粘贴仓库根地址：

```
https://github.com/femnn/aiui-vision-agent
```

导入后进入「真机模拟 / 效果预览」：站点模拟了摄像头输入，画面即镜头视角。

## 真机调试

```bash
npm i -g @yodaos-pkg/aix-cli
aix install ./
aix launch-page ./
```

## 说明

- 内置模型只在真机运行时可用，浏览器静态预览可能提示「内置模型不可用」。
- 若改用第三方视觉 API（`fetch` OpenAI 兼容接口），需在 `pages/index/index.ink` 配置地址与密钥，并在 Rokid 开发者后台报备请求域名。
