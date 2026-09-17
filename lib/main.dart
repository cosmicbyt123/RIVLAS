import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'theme/rivals_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait by default
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RIVALS',
      debugShowCheckedModeBanner: false,
      theme: RivalsTheme.darkTheme,
      home: const App(),
    );
  }
}