# 验收

在仓库根目录：

```powershell
node scripts/verify.mjs
```

当前应为：7 个 MoonBit 测试通过，9 个 CLI 集成测试通过；格式检查和 --deny-warn 均通过。

示例命令（输出文件必须尚不存在）：

```powershell
moon run cmd/main -- --pages 20 --out plan.json --svg preview.svg
```

预期 20 个原页、0 补白、2 册、5 张纸。第一张正面 [16,1]、背面 [2,15]；最后一张正面 [20,17]、背面 [18,19]。已保存的复核产物位于 examples/booklet-20.json 与 examples/booklet-20.svg。

实际测试记录见 docs/VALIDATION.md。CI 需上传后查看 GitHub Actions 状态；本地通过不能代替远端结果。
