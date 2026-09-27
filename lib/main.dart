import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = TaskStore();
  await store.load();
  runApp(
    ChangeNotifierProvider.value(value: store, child: const LocalTaskApp()),
  );
}

enum TaskStatus { pending, inProgress, completed }

enum TaskPriority { low, medium, high }

class Task {
  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Personal',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.dueDate,
    this.dueTime,
    this.notes = '',
    this.recurring = 'Never',
  });
  final String id;
  String title, description, category, notes, recurring;
  TaskPriority priority;
  TaskStatus status;
  DateTime? dueDate;
  TimeOfDay? dueTime;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority.name,
    'status': status.name,
    'dueDate': dueDate?.toIso8601String(),
    'dueHour': dueTime?.hour,
    'dueMinute': dueTime?.minute,
    'notes': notes,
    'recurring': recurring,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'Personal',
    priority: TaskPriority.values.byName(
      json['priority'] as String? ?? 'medium',
    ),
    status: TaskStatus.values.byName(json['status'] as String? ?? 'pending'),
    dueDate: json['dueDate'] == null
        ? null
        : DateTime.tryParse(json['dueDate'] as String),
    dueTime: json['dueHour'] == null
        ? null
        : TimeOfDay(
            hour: json['dueHour'] as int,
            minute: json['dueMinute'] as int? ?? 0,
          ),
    notes: json['notes'] as String? ?? '',
    recurring: json['recurring'] as String? ?? 'Never',
  );
}

class TaskStore extends ChangeNotifier {
  final tasks = <Task>[];
  SharedPreferences? _prefs;
  bool darkMode = false, remindersEnabled = true;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    darkMode = _prefs?.getBool('darkMode') ?? false;
    remindersEnabled = _prefs?.getBool('reminders') ?? true;
    final raw = _prefs?.getString('tasks');
    if (raw != null)
      tasks.addAll(
        (jsonDecode(raw) as List).map(
          (e) => Task.fromJson(e as Map<String, dynamic>),
        ),
      );
    notifyListeners();
  }

  Future<void> _save() async => _prefs?.setString(
    'tasks',
    jsonEncode(tasks.map((t) => t.toJson()).toList()),
  );
  void upsert(Task task) {
    final i = tasks.indexWhere((t) => t.id == task.id);
    if (i == -1)
      tasks.add(task);
    else
      tasks[i] = task;
    _save();
    notifyListeners();
  }

  void delete(Task task) {
    tasks.removeWhere((t) => t.id == task.id);
    _save();
    notifyListeners();
  }

  void toggle(Task task) {
    task.status = task.status == TaskStatus.completed
        ? TaskStatus.pending
        : TaskStatus.completed;
    _save();
    notifyListeners();
  }

  void setDark(bool value) {
    darkMode = value;
    _prefs?.setBool('darkMode', value);
    notifyListeners();
  }

  void setReminders(bool value) {
    remindersEnabled = value;
    _prefs?.setBool('reminders', value);
    notifyListeners();
  }
}

class LocalTaskApp extends StatelessWidget {
  const LocalTaskApp({super.key});
  @override
  Widget build(BuildContext context) => Consumer<TaskStore>(
    builder: (_, store, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LocalTask',
      themeMode: store.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2e7d32)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff8f8fc),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff81c784),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LocalTask',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                showSearch(context: context, delegate: TaskSearch(store)),
          ),
        ],
      ),
      body: selectedIndex == 1
          ? const AllTasksScreen()
          : selectedIndex == 2
          ? const SettingsScreen()
          : const DashboardScreen(),
      floatingActionButton: selectedIndex == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskEditor()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => setState(() => selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final today = DateTime.now();
    final todayCount = store.tasks
        .where(
          (t) =>
              t.dueDate != null &&
              DateUtils.isSameDay(t.dueDate, today) &&
              t.status != TaskStatus.completed,
        )
        .length;
    final completed = store.tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final openTasks = store.tasks
        .where((t) => t.status != TaskStatus.completed)
        .take(5)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(today),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Good morning',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _stat(context, 'Today', '$todayCount', Icons.today_rounded),
            _stat(context, 'Completed', '$completed', Icons.verified_rounded),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'Your tasks',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (openTasks.isEmpty)
          _empty(context)
        else
          ...openTasks.map((task) => TaskTile(task: task)),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          const Text(
            'All clear for now',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Add a task to get your day moving.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class AllTasksScreen extends StatelessWidget {
  const AllTasksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskStore>().tasks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
      children: [
        const Text(
          'All tasks',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        if (tasks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: Text('No tasks yet.'),
            ),
          )
        else
          ...tasks.map((task) => TaskTile(task: task)),
      ],
    );
  }
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task});
  final Task task;
  @override
  Widget build(BuildContext context) {
    final store = context.read<TaskStore>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskEditor(task: task)),
        ),
        leading: Checkbox(
          value: task.status == TaskStatus.completed,
          onChanged: (_) => store.toggle(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: task.status == TaskStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Text(
          '${task.category} - ${task.priority.name[0].toUpperCase()}${task.priority.name.substring(1)}${task.dueDate == null ? '' : ' - ${DateFormat('d MMM').format(task.dueDate!)}'}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({super.key, this.task});
  final Task? task;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final TextEditingController title, description, notes;
  late String category, recurring;
  late TaskPriority priority;
  late TaskStatus status;
  DateTime? dueDate;
  TimeOfDay? dueTime;
  @override
  void initState() {
    super.initState();
    final t = widget.task;
    title = TextEditingController(text: t?.title);
    description = TextEditingController(text: t?.description);
    notes = TextEditingController(text: t?.notes);
    category = t?.category ?? 'Personal';
    recurring = t?.recurring ?? 'Never';
    priority = t?.priority ?? TaskPriority.medium;
    status = t?.status ?? TaskStatus.pending;
    dueDate = t?.dueDate;
    dueTime = t?.dueTime;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
      actions: [
        if (widget.task != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<TaskStore>().delete(widget.task!);
              Navigator.pop(context);
            },
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _field(title, 'Task title', 'What needs to be done?'),
        const SizedBox(height: 14),
        _field(description, 'Description', 'Add context', lines: 3),
        const SizedBox(height: 18),
        _category(),
        const SizedBox(height: 14),
        _priority(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  dueDate == null
                      ? 'Due date'
                      : DateFormat('d MMM yyyy').format(dueDate!),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  dueTime == null ? 'Time' : dueTime!.format(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _repeat(),
        const SizedBox(height: 14),
        _status(),
        const SizedBox(height: 14),
        _field(notes, 'Notes', 'Optional notes', lines: 3),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Save task'),
          ),
        ),
      ],
    ),
  );
  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    int lines = 1,
  }) => TextField(
    controller: c,
    autofocus: label == 'Task title' && widget.task == null,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );
  Widget _category() => DropdownButtonFormField<String>(
    initialValue: category,
    decoration: const InputDecoration(
      labelText: 'Category',
      border: OutlineInputBorder(),
    ),
    items: [
      'Personal',
      'Work',
      'Shopping',
      'Errands',
      'Custom',
    ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
    onChanged: (v) => setState(() => category = v!),
  );
  Widget _priority() => DropdownButtonFormField<TaskPriority>(
    initialValue: priority,
    decoration: const InputDecoration(
      labelText: 'Priority',
      border: OutlineInputBorder(),
    ),
    items: TaskPriority.values
        .map(
          (e) => DropdownMenuItem(
            value: e,
            child: Text(e.name[0].toUpperCase() + e.name.substring(1)),
          ),
        )
        .toList(),
    onChanged: (v) => setState(() => priority = v!),
  );
  Widget _repeat() => DropdownButtonFormField<String>(
    initialValue: recurring,
    decoration: const InputDecoration(
      labelText: 'Repeat',
      border: OutlineInputBorder(),
    ),
    items: [
      'Never',
      'Daily',
      'Weekly',
      'Monthly',
    ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
    onChanged: (v) => setState(() => recurring = v!),
  );
  Widget _status() => DropdownButtonFormField<TaskStatus>(
    initialValue: status,
    decoration: const InputDecoration(
      labelText: 'Status',
      border: OutlineInputBorder(),
    ),
    items: TaskStatus.values
        .map(
          (e) => DropdownMenuItem(
            value: e,
            child: Text(
              e == TaskStatus.inProgress
                  ? 'In Progress'
                  : e.name[0].toUpperCase() + e.name.substring(1),
            ),
          ),
        )
        .toList(),
    onChanged: (v) => setState(() => status = v!),
  );
  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: dueDate ?? DateTime.now(),
    );
    if (value != null) setState(() => dueDate = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: dueTime ?? TimeOfDay.now(),
    );
    if (value != null) setState(() => dueTime = value);
  }

  void _save() {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add a task title')));
      return;
    }
    context.read<TaskStore>().upsert(
      Task(
        id: widget.task?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.text.trim(),
        description: description.text.trim(),
        category: category,
        priority: priority,
        status: status,
        dueDate: dueDate,
        dueTime: dueTime,
        notes: notes.text.trim(),
        recurring: recurring,
      ),
    );
    Navigator.pop(context);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Dark mode'),
                subtitle: const Text('Use a darker color palette'),
                value: store.darkMode,
                onChanged: store.setDark,
              ),
              SwitchListTile(
                title: const Text('Reminders'),
                subtitle: const Text('Enable local task reminders'),
                value: store.remindersEnabled,
                onChanged: store.setReminders,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export tasks'),
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text: jsonEncode(store.tasks.map((t) => t.toJson()).toList()),
                subject: 'LocalTask backup',
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Center(
          child: Text(
            'LocalTask - daccadelight.com',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class TaskSearch extends SearchDelegate {
  TaskSearch(this.store);
  final TaskStore store;
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => _results();
  @override
  Widget buildSuggestions(BuildContext context) => _results();
  Widget _results() {
    final matches = store.tasks
        .where((t) => t.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView(
      children: matches.map((task) => TaskTile(task: task)).toList(),
    );
  }
}
