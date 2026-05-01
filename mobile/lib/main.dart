import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/board_screen.dart';
import 'screens/boards_list_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  runApp(const FamiliarsApp());
}

/// Root widget. Routes auth-gated traffic to the boards list / board screen.
class FamiliarsApp extends StatelessWidget {
  const FamiliarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Familiars',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final AuthService _auth = AuthService();
  late final ApiClient _api = ApiClient(auth: _auth);

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) {
          return LoginScreen(auth: _auth);
        }
        return BoardsListScreen(
          auth: _auth,
          api: _api,
          onOpenBoard: (boardId, boardName) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BoardScreen(
                  api: _api,
                  auth: _auth,
                  boardId: boardId,
                  boardName: boardName,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
