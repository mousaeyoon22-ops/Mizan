import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'state/mizan_store.dart';
import 'theme/mizan_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MizanApp());
}

class MizanApp extends StatefulWidget {
  const MizanApp({super.key});

  @override
  State<MizanApp> createState() => _MizanAppState();
}

class _MizanAppState extends State<MizanApp> {
  final MizanStore _store = MizanStore();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return MaterialApp(
          title: 'ميزان v3.0 — Mizan',
          debugShowCheckedModeBanner: false,
          locale: _store.isEnglish ? const Locale('en') : const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: MizanTheme.light(),
          darkTheme: MizanTheme.dark(),
          themeMode: _store.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: _store.isAuthenticated
              ? HomeShell(store: _store)
              : LoginScreen(store: _store),
        );
      },
    );
  }
}
