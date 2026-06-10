import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/push_notification_service.dart';
import 'config/database_helper.dart';
import 'services/network_status_service.dart';
import 'services/offline_queue_service.dart';

/// Punto de entrada de la aplicación
/// Patrón: Single Root App - Configuración centralizada
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  // Inicializar base de datos local y servicios offline
  await DatabaseHelper.instance.database;
  NetworkStatusService(); // Inicializa listener de conectividad
  OfflineQueueService(); // Inicializa procesador de colas offline

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
  const MyApp({super.key});

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

      // Global Builder para inyectar el Banner Offline
      builder: (context, child) {
        return Material(
          child: Stack(
            children: [
              if (child != null) child,
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: StreamBuilder(
                  stream: NetworkStatusService().onConnectivityChanged,
                  builder: (context, snapshot) {
                    if (!NetworkStatusService().isOnline) {
                      return Container(
                        color: Colors.redAccent.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Text(
                          'Modo Sin Conexión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },

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
