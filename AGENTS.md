# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: Main Flutter/Dart source. Features are organized by layer: `api/`, `controllers/`, `pages/`, `components/`, `models/`, `helpers/`, `constants/`.
- `assets/`: App assets (images, etc.), referenced via `pubspec.yaml`.
- `web/`, `android/`, `ios/`, `macos/`, `linux/`, `windows/`: Platform runners and configs.
- `worker/`: Cloudflare Worker used for GitHub OAuth proxy.
- `tools/`: Utility scripts (e.g., OAuth proxy test).

## Build, Test, and Development Commands
- `flutter pub get` — install dependencies.
- `dart gen_secrets.dart` — generates `lib/secret.dart` from `CLIENT_ID` (env var).
- `flutter run` — run locally (choose device/platform as needed).
- `flutter build web` / `flutter build windows` / `flutter build apk` / `flutter build ios` / `flutter build macos` / `flutter build linux` — platform builds.
- `flutter analyze` — static analysis (CI uses this).
- 敲敲预览「音乐」在 **Windows / Linux** 桌面端通过 `just_audio_media_kit` 播放；依赖 `media_kit_libs_windows_audio` / `media_kit_libs_linux` 随构建带上原生解码库，**不要求终端用户单独安装 mpv**。
- **验收建议**：① 在未额外安装 mpv 的干净 Linux 上 `flutter run -d linux` 播放 HTTPS `.mp3`/`.m4a`。② Web 端保存音乐 URL 须能通过与服务端同源的 **CORS + HTTP 预检**（与移动端/桌面导入同一套校验）；再用 Windows/macOS/Android/iOS 导入同一份 JSON 验证播放。
- On this Windows workspace, Flutter SDK is available at `F:\flutter_windows_3.38.7-stable\flutter\bin\flutter.bat`; use it for `analyze`, `pub get`, and builds when `flutter` is not on PATH.

## Coding Style & Naming Conventions
- Lints: `analysis_options.yaml` includes `package:lint/strict.yaml` and sets `prefer_single_quotes: true`.
- Dart/Flutter conventions apply: lowerCamelCase for variables/methods, UpperCamelCase for types, `snake_case.dart` file names.
- Keep imports ordered and group by package (see recent `style:` commit).

## Testing Guidelines
- No `test/` directory is present and CI tests are commented out. If adding tests, use `flutter test` and place them under `test/`.

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits style (examples: `feat(讨论分类): ...`, `fix(搜索页): ...`, `style: ...`, `refactor(搜索): ...`). Use `type(scope): short description`.
- PRs should describe the change, mention related issues, and include screenshots for UI changes.

## Security & Configuration Tips
- `gen_secrets.dart` writes `lib/secret.dart` from `CLIENT_ID`; do not hardcode secrets in source.
- OAuth web login relies on the Worker in `worker/` and its `ALLOWED_ORIGIN` env; ensure the deployed origin is allowed.
