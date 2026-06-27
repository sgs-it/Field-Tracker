import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tracker_state.dart';
import 'map_service.dart';
import 'dashboard_view.dart';
import 'worker_view.dart';
import 'simulator_panel.dart';
import 'login_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TrackerState()),
        ChangeNotifierProvider(create: (context) => MapService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SGS Field Tracker System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF13131A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
          primary: Colors.tealAccent,
          surface: const Color(0xFF1E1E26),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const MainNavigationController(),
    );
  }
}

class MainNavigationController extends StatefulWidget {
  const MainNavigationController({super.key});

  @override
  State<MainNavigationController> createState() => _MainNavigationControllerState();
}

class _MainNavigationControllerState extends State<MainNavigationController> {
  bool _isLoggedIn = false;
  bool _isDemoMode = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TrackerState>(context);

    // If not logged in and not in demo bypass, show Login Screen
    if (!_isLoggedIn && !_isDemoMode) {
      return LoginView(
        onLoginSuccess: () {
          setState(() {
            _isLoggedIn = true;
            _isDemoMode = false;
          });
        },
        onEnterDemoMode: () {
          setState(() {
            _isDemoMode = true;
            _isLoggedIn = false;
          });
        },
      );
    }

    // If in Demo Mode, display side-by-side view (Dashboard + Mobile Simulator + Simulator Panel)
    if (_isDemoMode) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E26),
          title: const Text('SGS Field Tracker - Presentation Demo Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          actions: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isDemoMode = false;
                  _isLoggedIn = false;
                });
              },
              icon: const Icon(Icons.logout, color: Colors.tealAccent, size: 16),
              label: const Text('Return to Login', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Row(
          children: [
            // Left: Web Dashboard
            const Expanded(
              flex: 5,
              child: DashboardView(),
            ),
            
            // Middle: Phone frame wrapper (Mobile Client)
            Container(
              width: 380,
              color: const Color(0xFF13131A),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'WORKER MOBILE CLIENT',
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: const Color(0xFF2D2D38), width: 8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: const WorkerView(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Right: Simulation controls
            const SimulatorPanel(),
          ],
        ),
      );
    }

    // Standard Login Routing: Full screen layout according to Role
    if (state.activeRoleId == 'Worker') {
      // Worker App Fullscreen with a tiny logout overlay at the top left
      return Scaffold(
        body: Stack(
          children: [
            const WorkerView(),
            Positioned(
              top: 42,
              right: 16,
              child: SafeArea(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black.withOpacity(0.6),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.tealAccent, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _isLoggedIn = false;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Supervisor, Engineer, Admin Dashboard Fullscreen
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header showing role, logout button
              Container(
                height: 38, // Sleek, decreased height
                color: const Color(0xFF13131A),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Logged In: ${state.activeRoleId}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoggedIn = false;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.logout, size: 12, color: Colors.tealAccent),
                      label: const Text('LOGOUT', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const Expanded(child: DashboardView()),
            ],
          ),
        ),
      );
    }
  }
}
