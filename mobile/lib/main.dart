import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'features/analytics/exam_analytics_page.dart';
import 'features/auth/login_page.dart';
import 'features/classes/classes_page.dart';
import 'features/dashboard/teacher_dashboard_page.dart';
import 'features/exams/exam_editor_page.dart';
import 'features/exams/exams_page.dart';
import 'features/review/review_page.dart';
import 'features/scanning/scan_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  await ApiClient.instance.loadToken();
  runApp(const VidyanetraApp());
}

class VidyanetraApp extends StatelessWidget {
  const VidyanetraApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryEmerald = Color(0xFF0F766E);
    const canvasColor = Color(0xFFF8FAFC);

    return MaterialApp(
      title: 'Vidyanetra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: canvasColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryEmerald,
          primary: primaryEmerald,
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
          surfaceTint: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryEmerald,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      initialRoute: ApiClient.instance.token == null ? '/login' : '/dashboard',
      routes: {
        '/login': (_) => const LoginPage(),
        '/dashboard': (_) => const TeacherDashboardPage(),
        '/classes': (_) => const ClassesPage(),
        '/exams': (ctx) => ExamsPage(classId: (ModalRoute.of(ctx)!.settings.arguments as int)),
        '/exam_editor': (ctx) => ExamEditorPage(examId: ModalRoute.of(ctx)?.settings.arguments as int?),
        '/exam-editor': (ctx) => ExamEditorPage(examId: ModalRoute.of(ctx)?.settings.arguments as int?),
        '/analytics': (ctx) => ExamAnalyticsPage(examId: (ModalRoute.of(ctx)!.settings.arguments as int)),
        '/scan': (ctx) => ScanPage(examId: (ModalRoute.of(ctx)!.settings.arguments as int)),
        '/review': (ctx) => ReviewPage(submissionId: (ModalRoute.of(ctx)!.settings.arguments as int)),
      },
    );
  }
}
