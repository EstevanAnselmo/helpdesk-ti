import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(HelpDeskApp(api: ApiService()));
}

final navigatorKey = GlobalKey<NavigatorState>();

class HelpDeskApp extends StatefulWidget {
  final ApiService api;
  const HelpDeskApp({super.key, required this.api});

  @override
  State<HelpDeskApp> createState() => _HelpDeskAppState();
}

class _HelpDeskAppState extends State<HelpDeskApp> {
  @override
  void initState() {
    super.initState();
    widget.api.onSessionExpired = () {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
        (route) => false,
      );
    };
    widget.api.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'HelpDesk TI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true, brightness: Brightness.dark),
      home: AnimatedBuilder(
        animation: widget.api,
        builder: (context, _) {
          if (widget.api.isRestoringSession) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return widget.api.isAuthenticated ? DashboardScreen(api: widget.api) : LoginScreen(api: widget.api);
        },
      ),
    );
  }
}
