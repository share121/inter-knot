import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/my_app_bar.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/android_input_lock.dart';
import 'package:inter_knot/l10n.dart';
import 'package:inter_knot/pages/home_page.dart';
import 'package:inter_knot/pages/search_page.dart';
import 'package:inter_knot/pages/toolkit_page.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  await GetStorage.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(LoginApi());
    Get.put(Api());
    Get.put(Controller());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return GetMaterialApp(
      title: 'Inter-Knot',
      onGenerateTitle: (context) => 'Inter-Knot'.tr,
      theme: ThemeData(
        brightness: Brightness.dark,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        dividerColor: const Color(0xff2D2D2D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffD7FF00),
          primary: const Color(0xffD7FF00),
          secondary: const Color(0xff00E5FF),
          surface: const Color(0xff121212),
          onSurface: Colors.white,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0A0A0A),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
          bodyMedium: TextStyle(fontSize: 15, color: Color(0xffE0E0E0)),
          labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xffD7FF00),
          ),
        ),
        fontFamilyFallback: const [
          'ZhCn',
          'sans-serif',
          'Segoe UI Emoji',
          'Segoe UI Symbol',
          'Apple Color Emoji',
          'Noto Color Emoji',
          'Noto Sans CJK SC',
          'PingFang SC',
          'Microsoft YaHei',
        ],
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
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (AndroidInputLock.isLocked) return;
            final focus = FocusManager.instance.primaryFocus;
            if (focus == null) return;
            final ctx = focus.context;
            if (ctx == null || !ctx.mounted) {
              focus.unfocus();
              return;
            }
            final canvas = ctx.findAncestorStateOfType<ChatMockupCanvasState>();
            if (canvas != null && canvas.isEditingText) return;
            focus.unfocus();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class MyHomePage extends GetView<Controller> {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xff121212),
      body: Column(
        children: [
          const MyAppBar(),
          Expanded(
            child: PageView(
              physics: isCompact
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              controller: controller.pageController,
              onPageChanged: (index) => controller.selectedIndex.value = index,
              children: const [
                SearchPage(),
                ToolkitPage(),
                HomePage(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isCompact
          ? Obx(
              () => Container(
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xff1A1A1A),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white12,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BottomNavItem(
                      isSelected: controller.selectedIndex.value == 0,
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore,
                      label: 'Discover'.tr,
                      onTap: () => controller.animateToPage(0),
                    ),
                    _BottomNavItem(
                      isSelected: controller.selectedIndex.value == 1,
                      icon: Icons.widgets_outlined,
                      activeIcon: Icons.widgets,
                      label: 'Toolkit'.tr,
                      onTap: () => controller.animateToPage(1),
                    ),
                    _BottomNavItem(
                      isSelected: controller.selectedIndex.value == 2,
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Home'.tr,
                      onTap: () => controller.animateToPage(2),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.isSelected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: isSelected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
