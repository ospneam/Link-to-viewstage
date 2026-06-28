import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/connection_manager.dart';
import 'screens/connect_screen.dart';
import 'screens/remote_screen.dart';
import 'screens/upload_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConnectionManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ViewStage 遥控器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF111111),
          onPrimary: const Color(0xFFFFFFFF),
          primaryContainer: const Color(0xFFE5E7EB),
          onPrimaryContainer: const Color(0xFF111111),
          secondary: const Color(0xFF374151),
          onSecondary: const Color(0xFFFFFFFF),
          secondaryContainer: const Color(0xFFF5F5F5),
          onSecondaryContainer: const Color(0xFF111111),
          tertiary: const Color(0xFF6B7280),
          onTertiary: const Color(0xFFFFFFFF),
          tertiaryContainer: const Color(0xFFF3F4F6),
          onTertiaryContainer: const Color(0xFF111111),
          error: const Color(0xFFEF4444),
          onError: const Color(0xFFFFFFFF),
          errorContainer: const Color(0xFFFEE2E2),
          onErrorContainer: const Color(0xFF111111),
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF111111),
          surfaceContainerHighest: const Color(0xFFF5F5F5),
          onSurfaceVariant: const Color(0xFF374151),
          outline: const Color(0xFFE5E7EB),
          outlineVariant: const Color(0xFFF3F4F6),
          shadow: const Color(0xFF000000),
          scrim: const Color(0xFF000000),
          inverseSurface: const Color(0xFF101010),
          onInverseSurface: const Color(0xFFFFFFFF),
          inversePrimary: const Color(0xFFE5E7EB),
          surfaceTint: const Color(0xFF111111),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter', fontSize: 64, fontWeight: FontWeight.w600, height: 1.05, letterSpacing: -2),
          displayMedium: TextStyle(fontFamily: 'Inter', fontSize: 48, fontWeight: FontWeight.w600, height: 1.1, letterSpacing: -1.5),
          displaySmall: TextStyle(fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w600, height: 1.15, letterSpacing: -1),
          headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.3),
          headlineSmall: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
          titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
          titleMedium: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
          titleSmall: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
          bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
          bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
          bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
          labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, height: 1),
          labelMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
          labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFF5F5F5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xFF111111),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111111)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: const Color(0xFFFFFFFF),
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            minimumSize: const Size(0, 40),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111111),
            textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            minimumSize: const Size(0, 40),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF111111), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF111111),
          linearTrackColor: Color(0xFFE5E7EB),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE5E7EB),
          thickness: 0.5,
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<ConnectionManager>().isConnected;

    if (!isConnected) {
      return const ConnectScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          RemoteScreen(),
          UploadPage(),
          _PlaceholderPage(label: '摄像头', icon: Icons.videocam_outlined),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(0, 8, 0, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: Row(
        children: [
          _buildTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: '首页', index: 0),
          _buildTab(icon: Icons.folder_outlined, activeIcon: Icons.folder, label: '文件', index: 1),
          _buildTab(icon: Icons.videocam_outlined, activeIcon: Icons.videocam, label: '摄像头', index: 2),
        ],
      ),
    );
  }

  Widget _buildTab({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFF111111) : const Color(0xFF9CA3AF);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontFamily: 'Inter',
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PlaceholderPage({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF9CA3AF),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
