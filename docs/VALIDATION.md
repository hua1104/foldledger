# 本地验证记录

## 2026-10-05：修复新版工具链兼容性

在项目 `_build/toolchain-new/runtime` 中隔离安装 MoonBit，未覆盖全局工具链。
用 `moon 0.1.20260920 (914d7da)`、`moonc v0.10.14+7d59c7ec9`
实际执行 `node scripts/verify.mjs`：格式、零警告检查、7 个核心测试、JS 构建、
9 个 CLI 测试全部通过。随后在原有 `moon 0.1.20260713` 上完整复测也通过。

修复：Binding/Duplex 显式提供 equal/not_equal，保留 Eq 派生并消除隐式方法提升；
黑盒测试显式使用 `@foldledger` 限定 API，消除新版隐式测试导入警告。
生成接口已按新版工具链更新。未禁用警告检查。以上为 Windows 实测，
GitHub Linux runner 仍需推送后重新运行确认。

## 初次验证

日期：2026-10-05，Windows PowerShell。

- MoonBit：moon 0.1.20260713 (75c7e1f 2026-07-13)。
- Node.js：v24.18.0。
- `moon info`：成功；检查生成接口，包名为 hua1104/foldledger，仅包含拼版 API。
- `moon fmt` / `moon fmt --check`：成功。
- `moon check --deny-warn`：成功。
- `moon test --deny-warn`：7/7 通过，包括 2,580 组守恒/配对组合。
- `moon build --target js cmd/main`：成功。
- `node --test tests/cli.integration.test.mjs`：9/9 通过。
- `node scripts/verify.mjs`：整条流水线成功，非零返回码会停止。
- examples/booklet-20.json：20 页、2 册、5 张纸、0 补白。
- examples/booklet-18.json：18 页、2 册、5 张纸、2 补白。
- examples/booklet-20.svg：通过 Sharp 渲染成 PNG 后实际查看，标题、正反页码和 5 张纸布局均清晰，无遮挡/截断。

未通过或未执行的范围：

- WASM-GC 尝试失败，本机缺少 `.moon/lib/core/_build/wasm-gc/release/bundle/prelude/prelude.mi`。当前不承诺该后端可复现；已验证发布路径为 JS。
- 未实施实体打印、PDF 页面合成、GitHub 远端 CI 和赛事申报。
- GitHub 查重仅覆盖公开仓库搜索，不涵盖全部报名材料；不能保证主办方认定完全不重复或审核通过。

运行新环境时重新执行验证脚本，不以这份静态记录替代实际结果。
