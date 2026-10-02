import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const ExpenseOcrApp());
}

class ExpenseOcrApp extends StatelessWidget {
  const ExpenseOcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Expense OCR',

      theme: AppTheme.light,

      home: const HomeScreen(),
    );
  }
}
