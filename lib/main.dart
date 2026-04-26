import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/push_notification_service.dart';

/// Punto de entrada de la aplicación
/// Patrón: Single Root App - Configuración centralizada
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase inicializado correctamente");
    
    // Inicializar manejadores de notificaciones Push (background/foreground)
    await PushNotificationService.init();
    
  } catch (e) {
    debugPrint("Error inicializando Firebase: $e");
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
