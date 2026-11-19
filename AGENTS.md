# 图像判定助手

Rokid 眼镜 AIUI 智能体：全屏显示摄像头实时画面；当镜头捕捉到指定目标时，画面叠加「识别正确 ✓」。

## 行为

- 正常：只显示镜头实时画面，不显示静态照片。
- 判定：每 3 秒抓一帧（grabFrame → Canvas → DataURL），交内置多模态模型判断是否命中目标。
- 命中：叠加绿色「✓ 识别正确」。

## 关键实现

- 实时预览：`getUserMedia` → `URL.createObjectURL(stream)` → `<video>`
- 抓帧：`ImageCapture.grabFrame()` → `new Canvas(...)` → `convertToBlob()`
- 判定：`LanguageModel.create()` + `prompt([{type:'image_url',...}])`
- 目标描述：`pages/index/index.ink` 顶部 `TARGET_DESC`

## 权限

- `CAMERA`
