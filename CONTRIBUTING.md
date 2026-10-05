# 贡献指南

核心逻辑放在 foldledger.mbt；不在 JS FFI 中实现页码算法。业务改变需补充可说明用户行为的测试，并记录公开 API 的变化。

提交前：

```powershell
moon info
moon fmt
node scripts/verify.mjs
```

检查 pkg.generated.mbti 的变化。报告错误时提供原稿页数、页选择、分册容量、装订/双面参数及实际结果；不要上传受版权或隐私限制的原稿。仅提供页码通常足以复现。
