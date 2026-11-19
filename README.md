# 图像判定助手 (AIUI / Rokid Glasses)

一个运行在 Rokid 带屏 AI 眼镜上的 AIUI 智能体：**扫描一张图像（非二维码）→ 画面显示「扫描成功」→ 用设备内置多模态模型判定图像内容**。

## 能力

- 拍照采集：`getUserMedia` + `ImageCapture.takePhoto({ mode: 'telephoto' })`（适合 AI 识图）
- 图像编码：`Blob` → Data URL（base64）
- 判定引擎：
  - 内置：`LanguageModel`（`image_url` 多模态输入，需真机）
  - 可选第三方：`fetch` 调用 OpenAI 兼容视觉接口（需在 `pages/index/index.ink` 顶部配置）
- 交互：扫描到图像后显示绿色「扫描成功 ✓」徽标并展示照片

## 目录

```
.
├── AGENTS.md            智能体身份与说明
├── app.json             页面 / 权限（CAMERA、INTERNET）
├── app.js               应用级逻辑
├── assets/scan.jpg      示例扫描图
└── pages/index/index.ink 页面：配置 + 逻辑 + 结构 + 样式
```

## 在 AIUI Studio 导入

在 AIUI Studio「导入项目 → GitHub 子目录导入」粘贴仓库根地址：

```
https://github.com/femnn/aiui-vision-agent
```

导入后可直接在网页端「真机模拟 / 效果预览」运行调试。

## 真机调试

```bash
npm i -g @yodaos-pkg/aix-cli
aix install ./            # 安装到已连接的 Rokid 眼镜
aix launch-page ./        # 打开页面
```

## 说明

- 内置模型只在真机运行时可用，浏览器预览可能显示「内置模型仅在真机可用」。
- 接第三方视觉 API：修改 `pages/index/index.ink` 顶部的 `VISION_API_URL / VISION_API_KEY / VISION_MODEL`；生产环境请求域名需在 Rokid 开发者后台报备。
