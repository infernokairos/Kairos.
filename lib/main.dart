import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/tasks_screen.dart';
import 'services/task_storage.dart';

export 'models/tier_task.dart';
export 'services/task_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskPlannerApp());
}

class TaskPlannerApp extends StatefulWidget {
  const TaskPlannerApp({super.key});

  @override
  State<TaskPlannerApp> createState() => _TaskPlannerAppState();
}

class _TaskPlannerAppState extends State<TaskPlannerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await TaskStorage.loadIsDarkTheme();
    if (mounted) {
      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      TaskStorage.saveThemeMode(_themeMode == ThemeMode.dark);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightBaseTheme = ThemeData(
      colorSchemeSeed: Colors.green,
      brightness: Brightness.light,
      useMaterial3: true,
    );

    final darkBaseTheme = ThemeData(
      colorSchemeSeed: Colors.green,
      brightness: Brightness.dark,
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Kairos',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: lightBaseTheme.copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(lightBaseTheme.textTheme),
      ),
      darkTheme: darkBaseTheme.copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(darkBaseTheme.textTheme),
      ),
      home: TasksScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}
