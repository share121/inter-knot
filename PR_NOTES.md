## PR 说明

本次改动旨在将 Discussions 相关配置集中化、移除客户端 refresh token 逻辑、修复分析/构建问题，并更新 GitHub Actions 构建流程以适配当前 Flutter/Gradle 版本。

## 关键变更

### 1) Discussions 链接与仓库配置集中化
- 将仓库 owner/repo 改为 `HKLHaoBin/inter-knot`
- 统一 discussions/new discussions 链接，避免硬编码

相关文件：
- `lib/constants/globals.dart`
- `lib/components/report_discussion_comment.dart`
- `lib/pages/discussion_page.dart`
- `lib/pages/search_page.dart`
- `lib/models/discussion.dart`
- `lib/models/h_data.dart`

### 2) 移除 refresh token（过期即重新登录）
- 去掉刷新 token 的逻辑与存储
- 过期时提示用户重新登录
- Secrets 仅保留 `CLIENT_ID`（不再需要 `CLIENT_SECRET`/`PEM`）

相关文件：
- `lib/api/api.dart`
- `lib/pages/login_page.dart`
- `lib/controllers/data.dart`
- `lib/pages/home_page.dart`
- `lib/l10n.dart`
- `gen_secrets.dart`
- `.github/workflows/main.yml`
- `.github/workflows/flutter_analysis.yml`

### 3) 修复编译/分析问题
主要修复：缺失导入、类型错误、空安全、分页加载、helper 结构等。

相关文件：
- `lib/components/*`
- `lib/pages/*`
- `lib/controllers/data.dart`
- `lib/models/*`
- `lib/helpers/*`
- `pubspec.yaml`

### 4) GitHub Actions 构建调整
- `flutter_analysis.yml` 移除 `flutter pub publish --dry-run`
- Web 构建移除已废弃的 `--web-renderer`
- Android 构建升级 Gradle/AGP/Kotlin 版本以修复 Kotlin 编译失败

相关文件：
- `.github/workflows/flutter_analysis.yml`
- `.github/workflows/main.yml`
- `android/settings.gradle`
- `android/gradle/wrapper/gradle-wrapper.properties`

## 变更文件清单（摘要）
- `.github/workflows/main.yml`
- `.github/workflows/flutter_analysis.yml`
- `android/settings.gradle`
- `android/gradle/wrapper/gradle-wrapper.properties`
- `gen_secrets.dart`
- `pubspec.yaml`
- `lib/constants/globals.dart`
- `lib/api/api.dart`
- `lib/controllers/data.dart`
- `lib/models/discussion.dart`
- `lib/models/h_data.dart`
- `lib/helpers/discussion_actions.dart`
- `lib/components/report_discussion_comment.dart`
- `lib/components/discussion_card.dart`
- `lib/components/discussions_grid.dart`
- `lib/components/comment.dart`
- `lib/components/replies.dart`
- `lib/components/my_app_bar.dart`
- `lib/components/my_tab.dart`
- `lib/components/updata.dart`
- `lib/pages/discussion_page.dart`
- `lib/pages/search_page.dart`
- `lib/pages/home_page.dart`
- `lib/pages/history_page.dart`
- `lib/pages/liked_page.dart`
- `lib/l10n.dart`

## 备注
- 该 PR 不包含功能性 UI 改动，只是兼容性/构建与配置调整。
- 如果原仓库需要保持原 `owner/repo`，可将 `owner`/`repo` 改回原值。
