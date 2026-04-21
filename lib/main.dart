import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';
import 'routes/app_routes.dart';

/// Punto de entrada de la aplicación
/// Patrón: Single Root App - Configuración centralizada
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase API no inicializado o faltan google-services.json: $e");
  }

  runApp(const MyApp());
}

/// Widget raíz de la aplicación
/// Configura temas, rutas y otros servicios globales
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      // Configuración básica
      title: 'Movil Workflow',
      debugShowCheckedModeBanner: false,

      // Tema (Dark Mode Glassmorphism)
      theme: AppTheme.theme,

      // Rutas con GoRouter
      routerConfig: AppRoutes.router,

      // Localizaciones
      supportedLocales: const [Locale('es', ''), Locale('en', '')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('es', ''),
    );
  }
}
