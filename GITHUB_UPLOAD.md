# 上传 GitHub 与参赛

以下默认使用参考项目中的 GitHub 用户名 `hua1104`、新仓库名 `foldledger`。若不是你的账号，先修改 moon.mod 的 name / repository 和 cmd/main/moon.pkg 的导入路径，再运行验收。当前没有发布、创建远端仓库或提交报名。

## 推荐：GitHub CLI

先安装 Git 与 GitHub CLI（gh），在 PowerShell 执行。不要把账号密码/令牌写入仓库。

```powershell
Set-Location 'C:\Users\jin\Desktop\2'
node scripts/verify.mjs
if ($LASTEXITCODE -ne 0) { throw '验证失败，停止上传' }
gh auth login
if ($LASTEXITCODE -ne 0) { throw 'GitHub 登录失败' }
git add .
git diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    git commit -m 'feat: add FoldLedger booklet imposition planner'
    if ($LASTEXITCODE -ne 0) { throw '提交失败，请检查 Git 用户配置' }
}
git branch -M main
gh repo create hua1104/foldledger --public --source . --remote origin --push
if ($LASTEXITCODE -ne 0) { throw '创建或上传失败，请检查已有仓库和 origin' }
gh browse
```

若仓库已存在，不要再次运行 repo create。确认它是正确目标后：

```powershell
git remote -v
# 仅在还没有 origin 时执行这一行：
git remote add origin https://github.com/hua1104/foldledger.git
git push -u origin main
```

若远端有其他提交，先检查/合并，不使用强制推送。

## 不安装 gh

在 https://github.com/new 新建 PUBLIC 仓库 foldledger，不勾选自动 README、LICENSE、gitignore。随后：

```powershell
Set-Location 'C:\Users\jin\Desktop\2'
node scripts/verify.mjs
if ($LASTEXITCODE -ne 0) { throw '验证失败' }
git add .
git commit -m 'feat: add FoldLedger booklet imposition planner'
git branch -M main
git remote add origin https://github.com/hua1104/foldledger.git
git push -u origin main
```

已存在本地提交且无修改时可跳过 commit。首次 Git 提交要求用户身份时，用自己的姓名/邮箱配置，不伪造身份。

## 申请步骤

1. 上传后查看 GitHub Actions 全绿；打开 README 图、样例 JSON 和 APPLICATION.md。
2. 加入官网赛事交流群，昵称改为 GitHub ID。
3. 在官网报名表提交真实信息、公开仓库链接和 APPLICATION.md 一页说明；说明是本月新项目并请主办方确认查重。
4. 150 元是申报审核通过后的启动支持，350 元是开发完成并通过本期审核后的完成支持；不是上传即发 500 元，也未保证先开发后报名一定符合启动支持流程。
5. 后续持续公开真实修改记录。不要补造历史 commit、Issue 或 PR；当前在本地开发的历史不能冒充公开持续开发记录。向主办方如实说明，并继续提交实体打印反馈等实际贡献。
6. 报名与验收均在 2026-10-31 截止；十月最多提交 3 次，以官网最新规则为准。

官网：https://moonbitlang.github.io/Hackathon2026/
报名：https://bxup9uklfcb.feishu.cn/share/base/form/shrcnWUMlgpbwHaXgzV7HmNhNhg
