import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:tofu_expressive/tofu_expressive.dart';
import 'package:m3e_design/m3e_design.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize native systems-optimized notification manager
  await NotificationService.instance.init();
  
  // Set system overlays for a beautiful immersive UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Lock orientation to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // CURATED SEED COLORS aligned with Material 3 Expressive guidelines
        const Color focusSeedColor = Color(0xFF1E5631); // Mint Green
        const Color darkFocusSeedColor = Color(0xFF8FBC8F); // Soft Green

        // Create standard Tofu Expressive themes and inject M3ETheme design extension
        final lightTheme = withM3ETheme(
          TofuTheme.light(
            seedColor: lightDynamic?.primary ?? focusSeedColor,
            fontFamily: 'Roboto',
          ),
        );

        final darkTheme = withM3ETheme(
          TofuTheme.dark(
            seedColor: darkDynamic?.primary ?? darkFocusSeedColor,
            fontFamily: 'Roboto',
          ),
        );

        return MaterialApp(
          title: 'Yet Another Pomodoro 2.0',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system, // Adapt to system light/dark
          theme: lightTheme,
          darkTheme: darkTheme,
          home: const HomeScreen(),
        );
      },
    );
  }
}
