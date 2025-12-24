import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:app_lh_tarja/pages/login_page.dart';
import 'package:app_lh_tarja/pages/home_page.dart';
import 'package:app_lh_tarja/theme/app_theme.dart';
import 'package:app_lh_tarja/providers/theme_provider.dart';
import 'package:app_lh_tarja/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    
    Widget startPage = token != null ? HomePage() : LoginPage();

    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MyApp(startPage: startPage),
      ),
    );
  } catch (e) {
    // Si hay error al inicializar, ir directo al login
    print("Error al inicializar app: $e");
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MyApp(startPage: LoginPage()),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final Widget startPage;

  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'LH Tarjas',
      debugShowCheckedModeBanner: false,
      navigatorKey: ApiService.navigatorKey,
      theme: themeProvider.currentTheme,
      home: startPage,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés
      ],
      locale: Locale('es', 'ES'),
    );
  }
} 