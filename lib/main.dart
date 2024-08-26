import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_theme/system_theme.dart';

import 'data.dart';
import 'l10n.dart';
import 'pages/search_page.dart';
import 'pages/notifications_page.dart';
import 'widget/github_button.dart';
import 'widget/window_buttons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktop) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  SystemTheme.fallbackColor = Colors.blue;
  await SystemTheme.accentColor.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(Controller());
    return SystemThemeBuilder(builder: (context, accent) {
      return GetMaterialApp(
        title: 'Inter-Knot',
        onGenerateTitle: (context) => 'Inter-Knot'.tr,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: accent.accent),
        ).useSystemChineseFont(Brightness.light),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent.accent,
            brightness: Brightness.dark,
          ),
        ).useSystemChineseFont(Brightness.dark),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        translations: Messages(),
        locale: Get.deviceLocale,
        fallbackLocale: const Locale('en', 'US'),
        home: const MyHomePage(),
        debugShowCheckedModeBanner: false,
      );
    });
  }
}

final destinations = [
  NavigationRailDestination(
    icon: const Icon(Icons.publish_outlined),
    selectedIcon: const Icon(Icons.publish),
    label: Text('Notifications'.tr),
  ),
  NavigationRailDestination(
    icon: const Icon(Icons.search_outlined),
    selectedIcon: const Icon(Icons.search),
    label: Text('Search'.tr),
  ),
  NavigationRailDestination(
    icon: const Icon(Icons.list),
    label: Text('Partition'.tr),
  ),
  NavigationRailDestination(
    icon: const Icon(Icons.favorite_border),
    selectedIcon: const Icon(Icons.favorite),
    label: Text('Like'.tr),
  ),
  NavigationRailDestination(
    icon: const Icon(Icons.history_outlined),
    selectedIcon: const Icon(Icons.history),
    label: Text('History'.tr),
  ),
  NavigationRailDestination(
    icon: const Icon(Icons.settings_outlined),
    selectedIcon: const Icon(Icons.settings),
    label: Text('Settings'.tr),
  ),
  NavigationRailDestination(
    icon: const Icon(Icons.info_outline),
    selectedIcon: const Icon(Icons.info),
    label: Text('About'.tr),
  ),
];

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return Scaffold(
      appBar: AppBar(
        title: DragToMoveArea(child: Text('Inter-Knot'.tr)),
        flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
        actions: [
          const GithubButton(),
          const SizedBox(width: 8),
          if (isDesktop) const WindowButtons(),
        ],
        elevation: 4,
      ),
      body: SafeArea(
        child: Row(
          children: [
            LayoutBuilder(builder: (context, con) {
              return SingleChildScrollView(
                child: SizedBox(
                  height: max(con.maxHeight, 456),
                  child: Obx(() {
                    return NavigationRail(
                      destinations: destinations,
                      selectedIndex: c.selectedIndex(),
                      onDestinationSelected: (index) => c.animateToPage(index),
                      labelType: NavigationRailLabelType.all,
                    );
                  }),
                ),
              );
            }),
            Expanded(
              child: PageView(
                controller: c.pageController,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const NotificationsPage(),
                  const SearchPage(),
                  Center(child: Text('Partition'.tr)),
                  Center(child: Text('Like'.tr)),
                  Center(child: Text('History'.tr)),
                  Center(child: Text('Settings'.tr)),
                  Center(child: Text('About'.tr)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
