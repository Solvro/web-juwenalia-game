import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/main_shell.dart';
import 'services/bundled_photos.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  await BundledPhotos.load();
  runApp(const JuwenaliaApp());
}

class JuwenaliaApp extends StatelessWidget {
  const JuwenaliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juwenalia #WrocławRazem',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}
