import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Lists boards (and creates them). Tap to open a board.
class BoardsListScreen extends StatefulWidget {
  final AuthService auth;
  final ApiClient api;
  final void Function(String boardId, String boardName) onOpenBoard;

  const BoardsListScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.onOpenBoard,
  });

  @override
  State<BoardsListScreen> createState() => _BoardsListScreenState();
}

class _BoardsListScreenState extends State<BoardsListScreen> {
  List<Map<String, dynamic>>? _boards;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final boards = await widget.api.listBoards();
      if (!mounted) return;
      setState(() => _boards = boards);
    } on UnauthenticatedException {
      await widget.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _createBoard() async {
    final name = await _promptForText(
      context: context,
      title: 'New board',
      hint: 'Board name',
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.api.createBoard(name);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boards'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => widget.auth.signOut(),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createBoard,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Network error: $_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final boards = _boards;
    if (boards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (boards.isEmpty) {
      return const Center(
        child: Text('No boards yet — tap + to create one.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: boards.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final b = boards[i];
          return ListTile(
            title: Text(b['name'] as String? ?? '(unnamed)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.onOpenBoard(
              b['id'] as String,
              b['name'] as String? ?? '(unnamed)',
            ),
          );
        },
      ),
    );
  }
}

/// Tiny modal text-prompt helper. Returns null if cancelled.
Future<String?> _promptForText({
  required BuildContext context,
  required String title,
  required String hint,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
