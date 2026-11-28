import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/mizan_l10n.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/mizan_store.dart';
import 'theme/mizan_theme.dart';

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
        final lang = MizanL10n.byCode(_store.languageCode);
        return MaterialApp(
          title: _store.t('app_title'),
          debugShowCheckedModeBanner: false,
          theme: MizanTheme.light(),
          darkTheme: MizanTheme.dark(),
          themeMode: _store.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(lang.code),
          supportedLocales: MizanL10n.supported.map((l) => Locale(l.code)).toList(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: lang.direction,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: !_store.isLoaded
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _store.isAuthenticated
                  ? HomeShell(store: _store)
                  : LoginScreen(store: _store),
        );
      },
    );
  }
}
