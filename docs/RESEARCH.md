# FoldLedger 规则与查重记录

核对日期：2026-10-05。官方页面：https://moonbitlang.github.io/Hackathon2026/
官方章程入口：https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd
报名入口：https://bxup9uklfcb.feishu.cn/share/base/form/shrcnWUMlgpbwHaXgzV7HmNhNhg

## 官方网站当次展示规则

- 十月报名及验收截止 2026-10-31；十月最多提交 3 次。
- 通过审核前最后一次有效提交或修改的时间为准；未通过可修改。
- 月度支持：150 元启动支持，申报审核通过后发放；350 元完成支持，完成开发并通过本期审核后发放。
- 以 MoonBit 为主要实现语言；README、示例、必要测试、认可的开源许可证、移植/参考来源说明。
- 开发过程公开持续提交，保留 commits、Issues、PR 与更新记录；不可编造或补造过去的开发记录。
- 必须加入赛事交流群，群昵称改成 GitHub ID，否则影响奖金发放。
- 重复提交、拆分项目和简单修改不计入验收与奖励。AI 可使用，参赛者应理解并负责成果。
- 当季度通过验收的新项目进入季度评选；季度与其他周期奖金另行评定。

上述内容读取自官网实际部署的页面脚本 `assets/index-Cb3Bwakq.js`。飞书章程和报名表未登录审阅/提交；规则变化、参赛资格及支出安排以主办方最新通知为准。

## 查重方法和结果

使用公开 GitHub REST 仓库搜索，记录当次 total_count，不将零搜索结果当成绝对唯一性证明。

| 查询 | 结果数 | 结论 |
| --- | ---: | --- |
| `moonbit booklet` | 0 | 未检出 MoonBit 小册子项目 |
| `moonbit imposition` | 0 | 未检出 MoonBit 拼版项目 |
| `moonbit signature printing` | 0 | 未检出相关仓库 |
| `moonbit 拼版` | 0 | 未检出相关仓库 |
| `foldledger` | 0 | 未检出同名仓库 |

例如可复查：https://github.com/search?q=moonbit+imposition&type=repositories

公开参赛完整清单未能取得，后续 GitHub API 出现未认证速率限制，因此不声称已穷尽全部参赛项目。提交前仍须请主办方确认是否有未公开/未检出的同方向报名。

## 为什么不交付最初的脱敏方向

补查 `moonbit redaction` 得到 5 个结果，包括：

- https://github.com/yyqdbngt/moon-scrub — 离线敏感信息检测/脱敏。
- https://github.com/chenliyi-cly/moonredact — 确定性敏感文本检测及策略脱敏。
- https://github.com/wangjiale6036-dotcom/moonveil — JSON/JSONL 脱敏，甚至与初选名称相同。

因此取消该方向，最终仓库不包含该扫描器，不以更名规避功能重复。以上只作为否决选题的证据，不是本项目上游代码。

## 相邻产品与边界

| 参考 | 已有能力 | FoldLedger 的交付边界 |
| --- | --- | --- |
| Adobe Acrobat booklet printing（https://helpx.adobe.com/acrobat/using/print-booklets-pdf-portfolios.html） | PDF 阅读器中的小册子打印 | 不复制阅读器或驱动；提供嵌入 MoonBit 程序的纯规划 API |
| pdfbook2（https://ctan.org/pkg/pdfbook2） | 基于 TeX 工具链的 PDF 小册子处理 | 不调用 TeX，不转换 PDF；输出可验证页序和补白/分册信息 |
| MoonLayout Audit（用户参考目录 Desktop/3） | 图坐标、节点/边布局质量审计 | 本项目处理有序页码与物理纸面，未复用其业务代码 |

上述是产品定位参考链接，未审计或复制这些产品的源码/规则文件，也不在本仓库分发这些产品；因此无上游代码许可证继承关系。FoldLedger 自身使用 MIT。
