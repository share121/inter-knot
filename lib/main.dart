import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/pages/history_page.dart';
import 'package:inter_knot/pages/liked_page.dart';
import 'package:inter_knot/pages/partition_page.dart';
import 'package:inter_knot/widget/discord_button.dart';
import 'package:inter_knot/widget/doc_button.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import 'data.dart';
import 'l10n.dart';
import 'pages/about_page.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(Controller());
    return GetMaterialApp(
      title: 'Inter-Knot',
      onGenerateTitle: (context) => 'Inter-Knot'.tr,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
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

    return LayoutBuilder(builder: (context, con) {
      return Scaffold(
        appBar: AppBar(
          title: DragToMoveArea(child: Text('Inter-Knot'.tr)),
          flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
          actions: [
            if (con.maxWidth > 410) const DocButton(),
            if (con.maxWidth > 370) const DiscordButton(),
            if (con.maxWidth > 330) const GithubButton(),
            if (con.maxWidth > 322) const SizedBox(width: 8),
            if (isDesktop) const WindowButtons(),
          ],
          elevation: 4,
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: Assets.images.drawerCover.provider(),
                  ),
                ),
                child: Text(
                  'Inter-Knot'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              ...destinations.indexed.map((e) => Obx(() => ListTile(
                    title: e.$2.label,
                    leading: c.selectedIndex() == e.$1
                        ? e.$2.selectedIcon
                        : e.$2.icon,
                    selected: c.selectedIndex() == e.$1,
                    onTap: () {
                      c.animateToPage(e.$1);
                      Get.back();
                    },
                  ))),
              const Divider(),
              ListTile(
                title: const Text('Github'),
                leading: SvgPicture.asset(
                  Assets.images.github,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                ),
                onTap: () => launchUrlString(githubLink),
              ),
              ListTile(
                title: const Text('Discord'),
                leading: const Icon(Icons.discord_outlined),
                onTap: () => launchUrlString('githubLink'),
              ),
              ListTile(
                title: Text('Documentation'.tr),
                leading: const Icon(Icons.book_outlined),
                onTap: () => launchUrlString(docLink),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Row(
            children: [
              if (con.maxWidth > 600)
                LayoutBuilder(builder: (context, con) {
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: max(con.maxHeight, 336),
                      child: Obx(() {
                        return NavigationRail(
                          destinations: destinations,
                          selectedIndex: c.selectedIndex(),
                          onDestinationSelected: (index) =>
                              c.animateToPage(index),
                          labelType: con.maxHeight < 456
                              ? NavigationRailLabelType.selected
                              : NavigationRailLabelType.all,
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
                    const PartitionPage(),
                    const LikedPage(),
                    const HistoryPage(),
                    Center(child: Text('Settings'.tr)),
                    const AboutPage(),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    });
  }
}
