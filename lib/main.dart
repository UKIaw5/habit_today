import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AdMob SDK 初期化
  await MobileAds.instance.initialize();

  runApp(const HabitTodayApp());
}

/// 1つのタスクのモデル
class HabitTask {
  final String title;
  final bool isDone;
  final DateTime? dueDate;

  HabitTask({
    required this.title,
    this.isDone = false,
    this.dueDate,
  });

  HabitTask copyWith({
    String? title,
    bool? isDone,
    DateTime? dueDate,
  }) {
    return HabitTask(
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isDone': isDone,
      'dueDate': dueDate?.toIso8601String(),
    };
  }

  factory HabitTask.fromJson(Map<String, dynamic> json) {
    return HabitTask(
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
    );
  }
}

class HabitTodayApp extends StatelessWidget {
  const HabitTodayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Today',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const HabitTodayHomePage(),
    );
  }
}

class HabitTodayHomePage extends StatefulWidget {
  const HabitTodayHomePage({super.key});

  @override
  State<HabitTodayHomePage> createState() => _HabitTodayHomePageState();
}

class _HabitTodayHomePageState extends State<HabitTodayHomePage> {
  final TextEditingController _textController = TextEditingController();
  DateTime? _selectedDueDate;

  List<HabitTask> _tasks = [];

  // --- AdMob バナー用 ---
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  static const String _tasksPrefsKey = 'habit_today_tasks';

  // あなたのバナー広告ユニット ID
  // （開発中は本当はテストID推奨だが、ここは実 ID をそのまま使用）
  static const String _bannerAdUnitId =
      'ca-app-pub-7982112708155827/3331806817';

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _textController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_tasksPrefsKey);
    if (jsonString == null) return;

    final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
    setState(() {
      _tasks = decoded
          .map((e) => HabitTask.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString =
        jsonEncode(_tasks.map((task) => task.toJson()).toList());
    await prefs.setString(_tasksPrefsKey, jsonString);
  }

  void _loadBannerAd() {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: _bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
      request: const AdRequest(),
    );

    ad.load();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _selectedDueDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _addTask() {
    final title = _textController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _tasks.add(HabitTask(
        title: title,
        dueDate: _selectedDueDate,
      ));
      _textController.clear();
      _selectedDueDate = null;
    });

    _saveTasks();
  }

  void _toggleTaskDone(int index, bool? value) {
    final task = _tasks[index];
    setState(() {
      _tasks[index] = task.copyWith(isDone: value ?? false);
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  String _formatDueDate(DateTime? date) {
    if (date == null) return '期限なし';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Today ✅'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 入力エリア
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          labelText: 'やることを入力',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addTask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.event),
                      tooltip: '期限を設定',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '期限: ${_formatDueDate(_selectedDueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // タスクリスト
          Expanded(
            child: _tasks.isEmpty
                ? const Center(
                    child: Text(
                      'まだタスクがありません。\n今日やることを追加してみよう！',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final isExpired = task.dueDate != null &&
                          !task.isDone &&
                          task.dueDate!
                              .isBefore(DateTime.now().subtract(
                            const Duration(days: 1),
                          ));

                      return Dismissible(
                        key: ValueKey(task.title + index.toString()),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteTask(index),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: task.isDone,
                            onChanged: (value) =>
                                _toggleTaskDone(index, value),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: task.isDone
                                  ? Colors.grey
                                  : (isExpired ? Colors.red : null),
                            ),
                          ),
                          subtitle: Text(
                            '期限: ${_formatDueDate(task.dueDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpired ? Colors.red : Colors.grey[700],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteTask(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),

        ],
      ),
      bottomNavigationBar: (_isBannerLoaded && _bannerAd != null)
          ? SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}

