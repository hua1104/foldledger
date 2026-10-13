# 分三次上传 GitHub

数字 MVP 已包含 MoonBit 拼版核心、CLI、PDF 适配器，以及可重复生成的 PDF、JSON、SVG 和 PNG 示例。本次剩余改动分成三个独立提交，每次提交后执行一次推送。以下命令由你在同一个 PowerShell 窗口中依次执行，目标是已有仓库 `hua1104/foldledger` 的 `main` 分支。

## 准备与验收

```powershell
Set-Location 'C:\Users\jin\Desktop\2'
git status --short
git remote -v
if ((git branch --show-current) -ne 'main') { throw '请先确认当前分支为 main' }
if ((git remote get-url origin) -ne 'https://github.com/hua1104/foldledger.git') {
    throw 'origin 与目标仓库不一致，请先核对'
}
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) { throw '暂存区已有改动，请先处理，再按以下分组上传' }
npm ci
if ($LASTEXITCODE -ne 0) { throw '依赖安装失败' }
node scripts/verify.mjs
if ($LASTEXITCODE -ne 0) { throw '验收失败，停止上传' }
```

MoonBit 当前已验证稳定版为 `0.1.20261012`；CI 使用官方 `latest` 稳定通道并记录实际版本，Node.js 使用 24。历史版本 `0.1.20260920` 的 Linux 下载地址返回 403，因此不再用于 CI 安装。准备完成后再依次执行下面三个命令块。任何一块失败均先处理失败原因，再继续下一块。

## 第一次：配置 CI 工具链

本次改动配置 MoonBit 官方稳定通道，并在 CI 日志中输出工具链版本。

```powershell
git add -- .github/workflows/ci.yml
if ($LASTEXITCODE -ne 0) { throw '暂存失败' }
git diff --cached --quiet
if ($LASTEXITCODE -ne 1) { throw '没有待提交改动或检查失败，请核对' }
git commit -m 'ci: pin verified MoonBit toolchain'
if ($LASTEXITCODE -ne 0) { throw '提交失败' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw '推送失败，处理后重试 git push origin main' }
```

上传后在 [GitHub Actions](https://github.com/hua1104/foldledger/actions) 查看这个提交的运行结果。远端 CI 需实际运行成功后才能确认通过。

## 第二次：统一数字化范围与验收说明

本次改动统一 README、申请说明、算法说明和验证记录，说明 PDF、JSON、SVG、PNG 的用途与已验证范围。

```powershell
git add -- README.md APPLICATION.md ROADMAP.md docs/ALGORITHM.md docs/RESEARCH.md docs/VALIDATION.md
if ($LASTEXITCODE -ne 0) { throw '暂存失败' }
git diff --cached --quiet
if ($LASTEXITCODE -ne 1) { throw '没有待提交改动或检查失败，请核对' }
git commit -m 'docs: define digital MVP validation scope'
if ($LASTEXITCODE -ne 0) { throw '提交失败' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw '推送失败，处理后重试 git push origin main' }
```

## 第三次：更新上传指令

本次改动把已有仓库的上传过程改为三次真实增量上传，附带验收和失败停止检查。

```powershell
git add -- GITHUB_UPLOAD.md
if ($LASTEXITCODE -ne 0) { throw '暂存失败' }
git diff --cached --quiet
if ($LASTEXITCODE -ne 1) { throw '没有待提交改动或检查失败，请核对' }
git commit -m 'docs: add staged upload instructions'
if ($LASTEXITCODE -ne 0) { throw '提交失败' }
git push origin main
if ($LASTEXITCODE -ne 0) { throw '推送失败，处理后重试 git push origin main' }
```

## 上传后确认

```powershell
git status --short
git log -3 --oneline
git ls-remote origin refs/heads/main
git rev-parse HEAD
```

确认最后两条命令显示的提交哈希一致，并检查 Actions。三次上传分别对应工具链配置、数字化说明和上传流程的实际文件改动；执行完后不要重复制造空提交。若某次提交成功而推送失败，只需重试该次 `git push origin main`；若远端有新提交，先核对并合并后再正常推送。

重新申报时，使用公开仓库链接、`APPLICATION.md` 和示例产物说明当前 MVP。GitHub 推送次数与赛事报名次数是不同概念；是否满足赛期提交要求、是否通过审核，以主办方规则和审核结果为准。
