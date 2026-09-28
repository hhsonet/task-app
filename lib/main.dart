import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

class Meeting {
  Meeting({
    required this.id,
    required this.title,
    required this.date,
    this.description = '',
    this.startTime,
    this.endTime,
    this.location = '',
    this.link = '',
    this.notes = '',
  });
  final String id;
  String title, description, location, link, notes;
  DateTime date;
  TimeOfDay? startTime, endTime;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'date': date.toIso8601String(),
    'startHour': startTime?.hour,
    'startMinute': startTime?.minute,
    'endHour': endTime?.hour,
    'endMinute': endTime?.minute,
    'location': location,
    'link': link,
    'notes': notes,
  };
  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    startTime: json['startHour'] == null
        ? null
        : TimeOfDay(
            hour: json['startHour'] as int,
            minute: json['startMinute'] as int? ?? 0,
          ),
    endTime: json['endHour'] == null
        ? null
        : TimeOfDay(
            hour: json['endHour'] as int,
            minute: json['endMinute'] as int? ?? 0,
          ),
    location: json['location'] as String? ?? '',
    link: json['link'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
  );
}

class TaskStore extends ChangeNotifier {
  final tasks = <Task>[];
  final meetings = <Meeting>[];
  final categories = <String>[
    'Personal',
    'Work',
    'Shopping',
    'Errands',
    'Custom',
  ];
  SharedPreferences? _prefs;
  bool darkMode = false, remindersEnabled = true;
  String profileName = '';
  String? profilePhotoBase64;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    darkMode = _prefs?.getBool('darkMode') ?? false;
    remindersEnabled = _prefs?.getBool('reminders') ?? true;
    profileName = _prefs?.getString('profileName') ?? '';
    profilePhotoBase64 = _prefs?.getString('profilePhotoBase64');
    final savedCategories = _prefs?.getStringList('categories');
    if (savedCategories != null && savedCategories.isNotEmpty) {
      categories
        ..clear()
        ..addAll(savedCategories);
    }
    final raw = _prefs?.getString('tasks');
    final meetingRaw = _prefs?.getString('meetings');
    if (raw != null)
      tasks.addAll(
        (jsonDecode(raw) as List).map(
          (e) => Task.fromJson(e as Map<String, dynamic>),
        ),
      );
    if (meetingRaw != null)
      meetings.addAll(
        (jsonDecode(meetingRaw) as List).map(
          (e) => Meeting.fromJson(e as Map<String, dynamic>),
        ),
      );
    notifyListeners();
  }

  Future<void> _save() async => _prefs?.setString(
    'tasks',
    jsonEncode(tasks.map((t) => t.toJson()).toList()),
  );
  Future<void> _saveMeetings() async => _prefs?.setString(
    'meetings',
    jsonEncode(meetings.map((m) => m.toJson()).toList()),
  );
  Future<void> _saveCategories() async =>
      _prefs?.setStringList('categories', categories);
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

  void setProfileName(String value) {
    profileName = value.trim();
    _prefs?.setString('profileName', profileName);
    notifyListeners();
  }

  void setProfilePhoto(String? value) {
    profilePhotoBase64 = value;
    if (value == null) {
      _prefs?.remove('profilePhotoBase64');
    } else {
      _prefs?.setString('profilePhotoBase64', value);
    }
    notifyListeners();
  }

  void upsertMeeting(Meeting meeting) {
    final i = meetings.indexWhere((m) => m.id == meeting.id);
    if (i == -1)
      meetings.add(meeting);
    else
      meetings[i] = meeting;
    _saveMeetings();
    notifyListeners();
  }

  void deleteMeeting(Meeting meeting) {
    meetings.removeWhere((m) => m.id == meeting.id);
    _saveMeetings();
    notifyListeners();
  }

  void addCategory(String name) {
    final value = name.trim();
    if (value.isEmpty ||
        categories.any((item) => item.toLowerCase() == value.toLowerCase()))
      return;
    categories.add(value);
    _saveCategories();
    notifyListeners();
  }

  void deleteCategory(String name) {
    if (['Personal', 'Work', 'Shopping', 'Errands', 'Custom'].contains(name))
      return;
    categories.remove(name);
    _saveCategories();
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
          ? const CalendarScreen()
          : selectedIndex == 3
          ? const SettingsScreen()
          : const DashboardScreen(),
      floatingActionButton: selectedIndex == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => selectedIndex == 2
                      ? const MeetingEditor()
                      : const TaskEditor(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(selectedIndex == 2 ? 'New meeting' : 'New task'),
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
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
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
        Text(
          store.profileName.isEmpty
              ? 'Good morning'
              : 'Good morning, ${store.profileName}',
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
    items: context
        .read<TaskStore>()
        .categories
        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
        .toList(),
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

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDate = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final tasks = store.tasks
        .where(
          (task) =>
              task.dueDate != null &&
              DateUtils.isSameDay(task.dueDate, selectedDate),
        )
        .toList();
    final meetings = store.meetings
        .where((meeting) => DateUtils.isSameDay(meeting.date, selectedDate))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Calendar',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        Card(
          child: CalendarDatePicker(
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            initialDate: selectedDate,
            onDateChanged: (date) => setState(() => selectedDate = date),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
          child: Text(
            DateFormat('EEEE, d MMMM').format(selectedDate),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        if (meetings.isEmpty && tasks.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No tasks or meetings for this date.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...meetings.map((meeting) => MeetingTile(meeting: meeting)),
        ...tasks.map((task) => TaskTile(task: task)),
      ],
    );
  }
}

class MeetingTile extends StatelessWidget {
  const MeetingTile({super.key, required this.meeting});
  final Meeting meeting;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MeetingEditor(meeting: meeting)),
      ),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.video_call_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        meeting.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${meeting.startTime?.format(context) ?? 'All day'}${meeting.location.isEmpty ? '' : ' · ${meeting.location}'}',
      ),
      trailing: meeting.link.isEmpty
          ? const Icon(Icons.chevron_right)
          : IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'Meeting link',
              onPressed: () async {
                final uri = Uri.tryParse(meeting.link);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to open this meeting link'),
                    ),
                  );
                }
              },
            ),
    ),
  );
}

class MeetingEditor extends StatefulWidget {
  const MeetingEditor({super.key, this.meeting});
  final Meeting? meeting;
  @override
  State<MeetingEditor> createState() => _MeetingEditorState();
}

class _MeetingEditorState extends State<MeetingEditor> {
  late final TextEditingController title, description, location, link, notes;
  late DateTime date;
  TimeOfDay? startTime, endTime;
  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    title = TextEditingController(text: m?.title);
    description = TextEditingController(text: m?.description);
    location = TextEditingController(text: m?.location);
    link = TextEditingController(text: m?.link);
    notes = TextEditingController(text: m?.notes);
    date = m?.date ?? DateTime.now();
    startTime = m?.startTime;
    endTime = m?.endTime;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.meeting == null ? 'New meeting' : 'Edit meeting'),
      actions: [
        if (widget.meeting != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<TaskStore>().deleteMeeting(widget.meeting!);
              Navigator.pop(context);
            },
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _field(title, 'Meeting title', 'Team stand-up'),
        const SizedBox(height: 14),
        _field(description, 'Description', 'Agenda or context', lines: 3),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(DateFormat('EEEE, d MMM yyyy').format(date)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickStart,
                icon: const Icon(Icons.schedule),
                label: Text(startTime?.format(context) ?? 'Start time'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickEnd,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(endTime?.format(context) ?? 'End time'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _field(location, 'Location', 'Optional location'),
        const SizedBox(height: 14),
        _field(link, 'Meeting link', 'https://meet.google.com/...'),
        const SizedBox(height: 14),
        _field(notes, 'Notes', 'Optional notes', lines: 3),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Save meeting'),
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
    autofocus: label == 'Meeting title' && widget.meeting == null,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );
  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (value != null) setState(() => date = value);
  }

  Future<void> _pickStart() async {
    final value = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (value != null) setState(() => startTime = value);
  }

  Future<void> _pickEnd() async {
    final value = await showTimePicker(
      context: context,
      initialTime: endTime ?? startTime ?? TimeOfDay.now(),
    );
    if (value != null) setState(() => endTime = value);
  }

  void _save() {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a meeting title')),
      );
      return;
    }
    context.read<TaskStore>().upsertMeeting(
      Meeting(
        id:
            widget.meeting?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.text.trim(),
        description: description.text.trim(),
        date: date,
        startTime: startTime,
        endTime: endTime,
        location: location.text.trim(),
        link: link.text.trim(),
        notes: notes.text.trim(),
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
          child: ListTile(
            leading: ProfileAvatar(store: store),
            title: Text(
              store.profileName.isEmpty
                  ? 'Set up your profile'
                  : store.profileName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Add your name and profile photo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ),
        const SizedBox(height: 14),
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
            leading: const Icon(Icons.label_outline),
            title: const Text('Manage categories'),
            subtitle: Text(
              '${store.categories.length} categories available for tasks',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog(
              context: context,
              builder: (_) => const CategoryManagerDialog(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export tasks'),
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text: jsonEncode({
                  'tasks': store.tasks.map((t) => t.toJson()).toList(),
                  'meetings': store.meetings.map((m) => m.toJson()).toList(),
                }),
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

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.store, super.key, this.radius = 24});
  final TaskStore store;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = store.profilePhotoBase64;
    if (photo != null && photo.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(photo)),
        );
      } on FormatException {
        // Fall back to initials if an imported or older image is invalid.
      }
    }
    final name = store.profileName.trim();
    final initials = name.isEmpty
        ? null
        : name
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    return CircleAvatar(
      radius: radius,
      child: initials == null
          ? const Icon(Icons.person_outline)
          : Text(initials, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController nameController;
  bool pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: context.read<TaskStore>().profileName,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ProfileAvatar(store: store, radius: 58),
                IconButton.filled(
                  tooltip: 'Upload photo',
                  onPressed: pickingPhoto ? null : _pickPhoto,
                  icon: pickingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: pickingPhoto ? null : _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo'),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Your name',
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              store.setProfileName(nameController.text);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save profile'),
          ),
          if (store.profilePhotoBase64 != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => store.setProfilePhoto(null),
              child: const Text('Remove photo'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Your profile stays on this device and is not uploaded to an account or cloud service.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    setState(() => pickingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty) {
          context.read<TaskStore>().setProfilePhoto(base64Encode(bytes));
        }
      }
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }
}

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});
  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    return AlertDialog(
      title: const Text('Task categories'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      labelText: 'New category',
                      hintText: 'Fitness',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: store.categories
                    .map(
                      (category) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.label),
                        title: Text(category),
                        trailing:
                            [
                              'Personal',
                              'Work',
                              'Shopping',
                              'Errands',
                              'Custom',
                            ].contains(category)
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => store.deleteCategory(category),
                              ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  void _add() {
    context.read<TaskStore>().addCategory(controller.text);
    controller.clear();
    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
