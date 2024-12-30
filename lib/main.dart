import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(TodoApp());
}

class TodoApp extends StatefulWidget {
  @override
  _TodoAppState createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;
      setState(() {
        _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      });
    } catch (e) {
      print('Failed to load theme preference: $e');
    }
  }

  Future<void> _toggleTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      });
      await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    } catch (e) {
      print('Failed to save theme preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      color: Colors.red,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: TodoListScreen(onToggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

final ThemeData lightTheme = ThemeData(
  primarySwatch: Colors.teal,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.blue,
    titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
    iconTheme: IconThemeData(color: Colors.black),
    centerTitle: true,
  ),
);

final ThemeData darkTheme = ThemeData(
  primarySwatch: Colors.teal,
  brightness: Brightness.dark,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.black,
    titleTextStyle: TextStyle(color: Colors.blue, fontSize: 20, fontWeight: FontWeight.bold),
    iconTheme: IconThemeData(color: Colors.blue),
    centerTitle: true,
  ),
);

class TodoListScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  TodoListScreen({required this.onToggleTheme, required this.themeMode});

  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<Map<String, dynamic>> _todos = [];
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _quote = 'Loading...';
  List<Map<String, dynamic>> _filteredTodos = [];

  @override
  void initState() {
    super.initState();
    _fetchQuote();
    _loadTodos();
  }

  Future<void> _fetchQuote() async {
    try {
      final response = await http.get(Uri.parse('https://cors-anywhere.herokuapp.com/https://zenquotes.io/api/quotes'));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _quote = data[0]['q'];
        });
      } else {
        setState(() {
          _quote = 'Failed to load quote: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _quote = 'Failed to load quote. Please check your connection.';
      });
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('todos', jsonEncode(_todos));
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosString = prefs.getString('todos');
    if (todosString != null) {
      setState(() {
        _todos.addAll(List<Map<String, dynamic>>.from(jsonDecode(todosString).map((todo) {
          return {
            'task': todo['task'],
            'completed': todo['completed'] ?? false,
            'important': todo['important'] ?? false,
          };
        })));
        _filteredTodos = List.from(_todos);
      });
    }
  }

  void _addTodoItem(String task) {
    if (task.isNotEmpty) {
      setState(() {
        _todos.add({'task': task, 'completed': false, 'important': false});
        _filteredTodos = List.from(_todos);
      });
      _saveTodos();
      _textController.clear();
    }
  }

  void _toggleTodoItem(int index) {
    int originalIndex = _todos.indexWhere((todo) => todo['task'] == _filteredTodos[index]['task']);
    if (originalIndex != -1) {
      setState(() {
        _todos[originalIndex]['completed'] = !_todos[originalIndex]['completed'];
        _filteredTodos = List.from(_todos);
      });
      _saveTodos();
    }
  }

  void _removeTodoItem(int index) {
    int originalIndex = _todos.indexWhere((todo) => todo['task'] == _filteredTodos[index]['task']);
    if (originalIndex != -1) {
      setState(() {
        _todos.removeAt(originalIndex);
        _filteredTodos = List.from(_todos);
      });
      _saveTodos();
    }
  }

  void _markImportant(int index) {
    int originalIndex = _todos.indexWhere((todo) => todo['task'] == _filteredTodos[index]['task']);
    if (originalIndex != -1) {
      setState(() {
        _todos[originalIndex]['important'] = !_todos[originalIndex]['important'];
        _sortTasks();
        _filteredTodos = List.from(_todos);
      });
      _saveTodos();
    }
  }

  void _sortTasks() {
    setState(() {
      _todos.sort((a, b) {
        if (a['important'] && !b['important']) return -1;
        if (!a['important'] && b['important']) return 1;
        return 0;
      });
    });
  }

  void _clearAllTasks() async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Tasks'),
        content: Text('Are you sure you want to clear all tasks?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Clear All'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _todos.clear();
        _filteredTodos.clear();
      });
      _saveTodos();
    }
  }

  void _markAllAsCompleted() {
    setState(() {
      _todos.forEach((todo) => todo['completed'] = true);
      _filteredTodos = List.from(_todos);
    });
    _saveTodos();
  }

  void _markAllAsIncomplete() {
    setState(() {
      _todos.forEach((todo) => todo['completed'] = false);
      _filteredTodos = List.from(_todos);
    });
    _saveTodos();
  }

  void _filterTodos(String query) {
    setState(() {
      _filteredTodos = _todos.where((todo) => todo['task'].toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  Widget _buildTodoItem(Map<String, dynamic> todo, int index) {
    bool isCompleted = todo['completed'] ?? false;
    bool isImportant = todo['important'] ?? false;

    return Dismissible(
      key: UniqueKey(),
      onDismissed: (direction) {
        _removeTodoItem(index);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task removed')),
        );
      },
      background: Container(color: Colors.red),
      child: ListTile(
        title: Text(
          todo['task'],
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // Important to make Row compact
          children: [
            IconButton(
              icon: Icon(
                isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
              ),
              onPressed: () => _toggleTodoItem(index),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red), // Delete icon
              onPressed: () => _removeTodoItem(index),
            ),

          ],
        ),
        leading: IconButton(
          icon: Icon(
            isImportant ? Icons.star : Icons.star_border,
            color: isImportant ? Colors.amber : null,
          ),
          onPressed: () => _markImportant(index),
        ),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
        actions: [
          IconButton(
            icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearAllTasks,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Enter a task',
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _addTodoItem(_textController.text),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterTodos,
            ),
          ),
          Card(
            elevation: 4,
            margin: EdgeInsets.all(8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                _quote,
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                child: Text('Mark All Completed'),
                onPressed: _markAllAsCompleted,
              ),
              TextButton(
                child: Text('Mark All Incomplete'),
                onPressed: _markAllAsIncomplete,
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTodos.length,
              itemBuilder: (context, index) {
                return _buildTodoItem(_filteredTodos[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }
}