# 图像判定助手

一个 Rokid 眼镜 AIUI 示例智能体：拍照或选择一张图片（非二维码），
把图像交给**设备内置多模态大模型**或**第三方视觉 API** 做内容判定。

## 能力

- 拍照：`getUserMedia` + `ImageCapture.takePhoto({ mode: 'telephoto' })`
- 图像编码：`Blob` → Data URL（base64）
- 判定：
  - 内置：`LanguageModel`（`image_url` 多模态输入）
  - 第三方：`fetch` 调用 OpenAI 兼容视觉接口

## 权限

- `CAMERA`（拍照）

## 接入第三方 API

修改 `pages/index/index.ink` 顶部的 `VISION_API_URL` / `VISION_API_KEY` / `VISION_MODEL`。
生产环境请求域名需在 Rokid 开发者后台报备。
