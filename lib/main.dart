import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:get/get.dart';

import 'common.dart';
import 'data.dart';
import 'l10n.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/toolkit_page.dart';
import 'widget/my_app_bar.dart';

const maxRadius = 100.0;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(Controller());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    return GetMaterialApp(
      title: 'Inter-Knot',
      onGenerateTitle: (context) => 'Inter-Knot'.tr,
      theme: ThemeData(
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
        Locale('zh', 'TC'),
        Locale('en'),
      ],
      translations: Messages(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en'),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      body: Column(
        children: [
          const MyAppBar(),
          const SizedBox(height: 16),
          Expanded(
            child: PageView(
              controller: c.pageController,
              children: const [
                SearchPage(),
                ToolkitPage(),
                HomePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
