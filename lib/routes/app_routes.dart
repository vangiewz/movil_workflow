import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/item_model.dart';
import '../screens/home_screen.dart';
import '../screens/details_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/workflows/tramites_screen.dart';
import '../screens/workflows/tramite_list_screen.dart';
import '../screens/workflows/active_tramites_screen.dart';
import '../screens/workflows/tramite_detail_screen.dart';
import '../screens/workflows/payment_screen.dart';
import '../screens/workflows/form_screen.dart';
import '../screens/chat/chat_enrutamiento_screen.dart';
import '../models/tramite_model.dart';
import '../widgets/main_scaffold.dart';
import '../services/auth_service.dart';
import '../models/plantilla_workflow.dart';

/// Configuración de rutas de la aplicación usando GoRouter
/// Patrón: Declarative Navigation - Centraliza toda la navegación
class AppRoutes {
  AppRoutes._(); // Constructor privado

  // Nombres de rutas
  static const String initial = '/'; // Decide si ir a Home o Login
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String perfil = '/perfil';
  static const String tramites = '/tramites';
  static const String details = 'details/:id';
  static const String payment = '/payment';
  static const String form = '/form';

  /// Router configurado con todas las rutas de la aplicación
  static final GoRouter router = GoRouter(
    initialLocation: initial,
    redirect: (context, state) async {
      final isLoggedIn = await AuthService.isLoggedIn();
      final isGoingToAuth = state.matchedLocation == login || state.matchedLocation == register;
      
      // Lógica de Splash Inicial (Redirección inicial)
      if (state.matchedLocation == initial) {
        return isLoggedIn ? home : login;
      }

      // Proteger rutas (si no está logueado y no va a Auth)
      if (!isLoggedIn && !isGoingToAuth) {
        return login;
      }

      // Si está logueado pero trata de ir al login, enviarlo a home
      if (isLoggedIn && isGoingToAuth) {
        return home;
      }

      return null;
    },
    routes: <RouteBase>[
      // Ruta Raíz Virtual (para trigger el redirect)
      GoRoute(
        path: initial,
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      // Auth Routes
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Rutas FullScreen que tapan el Bottom Nav (Ej: Pagos, Formularios)
      GoRoute(
        path: payment,
        name: 'payment',
        builder: (context, state) {
          final tramite = state.extra as Tramite;
          return PaymentScreen(tramite: tramite);
        },
      ),
      GoRoute(
        path: form,
        name: 'form',
        builder: (context, state) {
          final wf = state.extra as PlantillaWorkflow;
          return FormScreen(workflow: wf);
        },
      ),
      GoRoute(
        path: '/tramites/list',
        builder: (context, state) => const TramiteListScreen(),
      ),
      GoRoute(
        path: '/tramites/active',
        builder: (context, state) => const ActiveTramitesScreen(),
      ),
      GoRoute(
        path: '/tramites/detail',
        builder: (context, state) {
          final tramite = state.extra as Tramite;
          return TramiteDetailScreen(tramite: tramite);
        },
      ),
      GoRoute(
        path: '/chat-enrutamiento',
        builder: (context, state) => const ChatEnrutamientoScreen(),
      ),
      // ShellRoute: Envuelve las rutas con el BottomNavigationBar
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          // Ruta Home
          GoRoute(
            path: home,
            name: 'home',
            builder: (BuildContext context, GoRouterState state) {
              return const HomeScreen();
            },
            routes: <GoRoute>[
              // Ruta Details (subruta de home)
              GoRoute(
                path: details,
                name: 'details',
                builder: (BuildContext context, GoRouterState state) {
                  final id = int.parse(state.pathParameters['id']!);
                  final item = state.extra as ItemModel?;
                  return DetailsScreen(itemId: id, item: item);
                },
              ),
            ],
          ),
          // Ruta Tramites
          GoRoute(
            path: tramites,
            name: 'tramites',
            builder: (context, state) => const TramitesScreen(),
          ),
          // Ruta Perfil
          GoRoute(
            path: perfil,
            name: 'perfil',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Página no encontrada'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(home),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// Método helper para navegar a details
  /// Patrón: Navigation Helper - Centraliza la lógica de navegación
  static void goToDetails(
    BuildContext context, {
    required int itemId,
    ItemModel? item,
  }) {
    context.pushNamed(
      'details',
      pathParameters: {'id': itemId.toString()},
      extra: item,
    );
  }

  /// Método helper para volver al home
  static void goToHome(BuildContext context) {
    context.go(home);
  }
}
