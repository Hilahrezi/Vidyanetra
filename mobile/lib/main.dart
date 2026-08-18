import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'features/auth/login_page.dart';
import 'features/classes/classes_page.dart';
import 'features/exams/exams_page.dart';
import 'features/review/review_page.dart';
import 'features/scanning/scan_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.loadToken();
  runApp(const AutoGradingApp());
}

class AutoGradingApp extends StatelessWidget {
  const AutoGradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoGrading',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: ApiClient.instance.token == null ? '/login' : '/classes',
      routes: {
        '/login': (_) => const LoginPage(),
        '/classes': (_) => const ClassesPage(),
        '/exams': (ctx) => ExamsPage(classId: (ModalRoute.of(ctx)!.settings.arguments as int)),
        '/scan': (ctx) => ScanPage(examId: (ModalRoute.of(ctx)!.settings.arguments as int)),
        '/review': (ctx) => ReviewPage(submissionId: (ModalRoute.of(ctx)!.settings.arguments as int)),
      },
    );
  }
}
