import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/helpers/iframe_policy.dart';
import 'package:inter_knot/helpers/snack.dart';
import 'package:inter_knot/models/release.dart';
import 'package:inter_knot/pages/history_page.dart';
import 'package:inter_knot/pages/liked_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Controller get c => Get.find<Controller>();
  Api get api => Get.find<Api>();

  late final Future<PackageInfo> _packageInfoFuture;
  late final Future getNewVersionFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    getNewVersionFuture = api.getNewVersion();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    if (!isCompact) {
      return Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/pc-page-bg.png',
              fit: BoxFit.cover,
            ),
          ),
          MyPageDesktop(
            packageInfoFuture: _packageInfoFuture,
            getNewVersionFuture: getNewVersionFuture,
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(),
          const SizedBox(height: 12),
          _buildStatsCard(),
          const SizedBox(height: 12),
          _buildQuickActionsCard(),
          const SizedBox(height: 12),
          _buildVersionCard(),
          const SizedBox(height: 12),
          _buildApiModeCard(),
          const SizedBox(height: 12),
          _buildIframePolicyCard(),
          const SizedBox(height: 12),
          _buildLinksCard(),
          const SizedBox(height: 12),
          _buildLogoutCard(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Obx(() {
      final user = c.user();
      final isLogin = c.isLogin();
      return _SectionCard(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xffD7FF00), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Avatar(user?.avatar, size: 54),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'Not logged in'.tr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.login ?? '—',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff808080),
                    ),
                  ),
                  if (isLogin && user != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoPill(
                          label: '贡献',
                          value: user.contributions.toString(),
                        ),
                        _InfoPill(
                          label: '等级',
                          value: 'Lv.${user.level}',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatsCard() {
    return _SectionCard(
      child: Obx(() {
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                title: 'Like'.tr,
                value: c.bookmarks.length.toString(),
                icon: Icons.favorite_rounded,
                onTap: () => Get.to(() => const LikedPage()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                title: 'History'.tr,
                value: c.history.length.toString(),
                icon: Icons.history_rounded,
                onTap: () => Get.to(() => const HistoryPage()),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildQuickActionsCard() {
    return _SectionCard(
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.favorite_rounded,
            title: 'Like'.tr,
            subtitle: Obx(() => Text(
                  'A total of @count items'
                      .trParams({'count': c.bookmarks.length.toString()}),
                  style:
                      const TextStyle(color: Color(0xff808080), fontSize: 12),
                )),
            onTap: () => Get.to(() => const LikedPage()),
          ),
          const Divider(height: 1, color: Color(0xff2A2A2A)),
          _MenuItem(
            icon: Icons.history_rounded,
            title: 'History'.tr,
            subtitle: Obx(() => Text(
                  'A total of @count items'
                      .trParams({'count': c.history.length.toString()}),
                  style:
                      const TextStyle(color: Color(0xff808080), fontSize: 12),
                )),
            onTap: () => Get.to(() => const HistoryPage()),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '版本信息',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (!kIsWeb)
            FutureBuilder(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final fullVer = 'v${snapshot.data!.version}';
                  return _InfoRow(
                    title: 'Current version'.tr,
                    value: fullVer,
                    onTap: () => copyText(fullVer),
                  );
                }
                if (snapshot.hasError) {
                  return _InfoRow(
                    title: 'Current version'.tr,
                    value: snapshot.error.toString(),
                  );
                }
                return _InfoRow(
                  title: 'Current version'.tr,
                  trailing: const SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          FutureBuilder(
            future: getNewVersionFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data is ReleaseModel) {
                final fullVer = 'v${(snapshot.data as ReleaseModel).version}';
                return _InfoRow(
                  title: 'Latest version'.tr,
                  value: fullVer,
                  onTap: () => launchUrlString(releasesLink),
                );
              }
              if (snapshot.hasError) {
                return _InfoRow(
                  title: 'Latest version'.tr,
                  value: snapshot.error.toString(),
                  onTap: () => launchUrlString(releasesLink),
                );
              }
              return _InfoRow(
                title: 'Latest version'.tr,
                trailing: const SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                onTap: () => launchUrlString(releasesLink),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApiModeCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '接口模式',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            return RadioGroup<bool>(
              groupValue: c.isLogin(),
              onChanged: (value) {
                if (value == null) return;
                c.isLogin(value);
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: Text('User Api'.tr),
                    dense: true,
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: Text('Common Api'.tr),
                    dense: true,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLinksCard() {
    return _SectionCard(
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.code_rounded,
            title: 'Github',
            subtitle: const Text(githubLink,
                style: TextStyle(color: Color(0xff808080), fontSize: 12)),
            onTap: () => launchUrlString(githubLink),
          ),
          const Divider(height: 1, color: Color(0xff2A2A2A)),
          _MenuItem(
            icon: Icons.discord,
            title: 'Discord',
            subtitle: const Text(discordLink,
                style: TextStyle(color: Color(0xff808080), fontSize: 12)),
            onTap: () => launchUrlString(discordLink),
          ),
          const Divider(height: 1, color: Color(0xff2A2A2A)),
          _MenuItem(
            icon: Icons.book,
            title: 'Documentation'.tr,
            subtitle: const Text(docLink,
                style: TextStyle(color: Color(0xff808080), fontSize: 12)),
            onTap: () => launchUrlString(docLink),
          ),
          const Divider(height: 1, color: Color(0xff2A2A2A)),
          _MenuItem(
            icon: Icons.search,
            title: 'Advanced Search Tips'.tr,
            subtitle: const Text(advancedSearchTipsLink,
                style: TextStyle(color: Color(0xff808080), fontSize: 12)),
            onTap: () => launchUrlString(advancedSearchTipsLink),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildIframePolicyCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Iframe load policy'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            return RadioGroup<IframeLoadPolicy>(
              groupValue: c.iframeLoadPolicy(),
              onChanged: (value) {
                if (value == null) return;
                c.iframeLoadPolicy(value);
              },
              child: Column(
                children: [
                  RadioListTile<IframeLoadPolicy>(
                    value: IframeLoadPolicy.denyAll,
                    title: Text('Do not load external iframes'.tr),
                    dense: true,
                  ),
                  RadioListTile<IframeLoadPolicy>(
                    value: IframeLoadPolicy.allowBilibiliStrict,
                    title: Text(
                      'Only allow bilibili player standard params'.tr,
                    ),
                    dense: true,
                  ),
                  RadioListTile<IframeLoadPolicy>(
                    value: IframeLoadPolicy.allowAllRisky,
                    title: Text(
                      'Allow all https iframes (risky)'.tr,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    dense: true,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return _SectionCard(
      child: _MenuItem(
        icon: Icons.logout_rounded,
        title: 'Login out'.tr,
        onTap: () async {
          await c.pref.remove('root_token');
          await c.pref.remove('access_token');
          showSnack('Login out successfully'.tr);
        },
        isFirst: true,
        isLast: true,
      ),
    );
  }
}

class MyPageDesktop extends StatelessWidget {
  const MyPageDesktop({
    super.key,
    required this.packageInfoFuture,
    required this.getNewVersionFuture,
  });

  final Future<PackageInfo> packageInfoFuture;
  final Future getNewVersionFuture;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _SectionCard(
                      child: Obx(() {
                        final user = c.user();
                        final isLogin = c.isLogin();
                        return Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xffD7FF00),
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Avatar(user?.avatar, size: 64),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName ?? 'Not logged in'.tr,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.login ?? '—',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff808080),
                                    ),
                                  ),
                                  if (isLogin && user != null) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _InfoPill(
                                          label: '贡献',
                                          value: user.contributions.toString(),
                                        ),
                                        _InfoPill(
                                          label: '等级',
                                          value: 'Lv.${user.level}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: Icons.favorite_rounded,
                            title: 'Like'.tr,
                            subtitle: Obx(() => Text(
                                  'A total of @count items'.trParams({
                                    'count': c.bookmarks.length.toString(),
                                  }),
                                  style: const TextStyle(
                                      color: Color(0xff808080), fontSize: 12),
                                )),
                            onTap: () => Get.to(() => const LikedPage()),
                          ),
                          const Divider(height: 1, color: Color(0xff2A2A2A)),
                          _MenuItem(
                            icon: Icons.history_rounded,
                            title: 'History'.tr,
                            subtitle: Obx(() => Text(
                                  'A total of @count items'.trParams({
                                    'count': c.history.length.toString(),
                                  }),
                                  style: const TextStyle(
                                      color: Color(0xff808080), fontSize: 12),
                                )),
                            onTap: () => Get.to(() => const HistoryPage()),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '版本信息',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!kIsWeb)
                            FutureBuilder(
                              future: packageInfoFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final fullVer = 'v${snapshot.data!.version}';
                                  return _InfoRow(
                                    title: 'Current version'.tr,
                                    value: fullVer,
                                    onTap: () => copyText(fullVer),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return _InfoRow(
                                    title: 'Current version'.tr,
                                    value: snapshot.error.toString(),
                                  );
                                }
                                return _InfoRow(
                                  title: 'Current version'.tr,
                                  trailing: const SizedBox(
                                    height: 12,
                                    width: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              },
                            ),
                          FutureBuilder(
                            future: getNewVersionFuture,
                            builder: (context, snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data is ReleaseModel) {
                                final fullVer =
                                    'v${(snapshot.data as ReleaseModel).version}';
                                return _InfoRow(
                                  title: 'Latest version'.tr,
                                  value: fullVer,
                                  onTap: () => launchUrlString(releasesLink),
                                );
                              }
                              if (snapshot.hasError) {
                                return _InfoRow(
                                  title: 'Latest version'.tr,
                                  value: snapshot.error.toString(),
                                  onTap: () => launchUrlString(releasesLink),
                                );
                              }
                              return _InfoRow(
                                title: 'Latest version'.tr,
                                trailing: const SizedBox(
                                  height: 12,
                                  width: 12,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                onTap: () => launchUrlString(releasesLink),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      child: MyPageIframePolicyCard(controller: c),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      child: Column(
                        children: [
                          _MenuItem(
                            icon: Icons.code_rounded,
                            title: 'Github',
                            subtitle: const Text(githubLink,
                                style: TextStyle(
                                    color: Color(0xff808080), fontSize: 12)),
                            onTap: () => launchUrlString(githubLink),
                          ),
                          const Divider(height: 1, color: Color(0xff2A2A2A)),
                          _MenuItem(
                            icon: Icons.discord,
                            title: 'Discord',
                            subtitle: const Text(discordLink,
                                style: TextStyle(
                                    color: Color(0xff808080), fontSize: 12)),
                            onTap: () => launchUrlString(discordLink),
                          ),
                          const Divider(height: 1, color: Color(0xff2A2A2A)),
                          _MenuItem(
                            icon: Icons.book,
                            title: 'Documentation'.tr,
                            subtitle: const Text(docLink,
                                style: TextStyle(
                                    color: Color(0xff808080), fontSize: 12)),
                            onTap: () => launchUrlString(docLink),
                          ),
                          const Divider(height: 1, color: Color(0xff2A2A2A)),
                          _MenuItem(
                            icon: Icons.search,
                            title: 'Advanced Search Tips'.tr,
                            subtitle: const Text(advancedSearchTipsLink,
                                style: TextStyle(
                                    color: Color(0xff808080), fontSize: 12)),
                            onTap: () =>
                                launchUrlString(advancedSearchTipsLink),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff2A2A2A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class MyPageIframePolicyCard extends StatelessWidget {
  const MyPageIframePolicyCard({
    super.key,
    required this.controller,
  });

  final Controller controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Iframe load policy'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          return RadioGroup<IframeLoadPolicy>(
            groupValue: controller.iframeLoadPolicy(),
            onChanged: (value) {
              if (value == null) return;
              controller.iframeLoadPolicy(value);
            },
            child: Column(
              children: [
                RadioListTile<IframeLoadPolicy>(
                  value: IframeLoadPolicy.denyAll,
                  title: Text('Do not load external iframes'.tr),
                  dense: true,
                ),
                RadioListTile<IframeLoadPolicy>(
                  value: IframeLoadPolicy.allowBilibiliStrict,
                  title: Text(
                    'Only allow bilibili player standard params'.tr,
                  ),
                  dense: true,
                ),
                RadioListTile<IframeLoadPolicy>(
                  value: IframeLoadPolicy.allowAllRisky,
                  title: Text(
                    'Allow all https iframes (risky)'.tr,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  dense: true,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffD7FF00).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xffD7FF00).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        '$label · $value',
        style: const TextStyle(
          color: Color(0xffD7FF00),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xff151515),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xff2A2A2A)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xffD7FF00), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xff808080),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xff2A2A2A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xff444444), size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              )
            else if (trailing != null)
              trailing!,
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: Color(0xff404040)),
            ],
          ],
        ),
      ),
    );
  }
}
