import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

const green = Color(0xFF16734A);
const darkGreen = Color(0xFF123B2A);
final money = NumberFormat.currency(locale: 'pt_AO', symbol: 'Kz ', decimalDigits: 0);
final dateFmt = DateFormat('dd/MM/yyyy');
final timeFmt = DateFormat('HH:mm');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT');
  await AppDb.instance.database;
  runApp(const MotoGestApp());
}

class MotoGestApp extends StatelessWidget {
  const MotoGestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MotoGest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light),
          scaffoldBackgroundColor: const Color(0xFFF5F7F5),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F7F5), foregroundColor: darkGreen, elevation: 0),
          cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)), filled: true, fillColor: Colors.white),
        ),
        home: const MainShell(),
      );
}

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(p.join(dir, 'motogest.db'), version: 1, onCreate: (db, _) async {
      await db.execute('''CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('income','expense')),
        amount INTEGER NOT NULL CHECK(amount > 0),
        category TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''');
      await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    });
    return _db!;
  }
  Future<int> add(Map<String, Object?> row) async => (await database).insert('transactions', row);
  Future<int> updateRow(int id, Map<String, Object?> row) async => (await database).update('transactions', row, where: 'id = ?', whereArgs: [id]);
  Future<int> deleteRow(int id) async => (await database).delete('transactions', where: 'id = ?', whereArgs: [id]);
  Future<List<Map<String, Object?>>> all({String? type, DateTime? from, DateTime? to}) async {
    final clauses = <String>[]; final args = <Object>[];
    if (type != null) { clauses.add('type = ?'); args.add(type); }
    if (from != null) { clauses.add('date >= ?'); args.add(DateFormat('yyyy-MM-dd').format(from)); }
    if (to != null) { clauses.add('date <= ?'); args.add(DateFormat('yyyy-MM-dd').format(to)); }
    return (await database).query('transactions', where: clauses.isEmpty ? null : clauses.join(' AND '), whereArgs: args, orderBy: 'date DESC, created_at DESC');
  }
  Future<void> replaceAll(List<dynamic> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      for (final item in rows) {
        final r = Map<String, Object?>.from(item as Map);
        r.remove('id');
        await txn.insert('transactions', r);
      }
    });
  }
}

int sumType(List<Map<String, Object?>> rows, String type) => rows.where((r) => r['type'] == type).fold<int>(0, (s, r) => s + (r['amount'] as int));
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int index = 0;
  int refresh = 0;
  void changed() => setState(() => refresh++);
  @override
  Widget build(BuildContext context) {
    final pages = [HomePage(key: ValueKey('home$refresh'), onChanged: changed), HistoryPage(key: ValueKey('history$refresh'), onChanged: changed), ReportsPage(key: ValueKey('reports$refresh')), SettingsPage(key: ValueKey('settings$refresh'))];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      floatingActionButton: index == 0 || index == 1 ? FloatingActionButton.extended(onPressed: () async { await showTransactionForm(context, onSaved: changed); }, backgroundColor: green, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('Novo registo')) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Histórico'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Relatórios'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Definições'),
      ]),
    );
  }
}

class HomePage extends StatelessWidget {
  final VoidCallback onChanged;
  const HomePage({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
    future: AppDb.instance.all(from: dayOnly(DateTime.now()), to: dayOnly(DateTime.now())),
    builder: (context, snap) {
      final rows = snap.data ?? [];
      final income = sumType(rows, 'income'); final expense = sumType(rows, 'expense');
      return ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 100), children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.two_wheeler, color: Colors.white)),
          const SizedBox(width: 11), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MotoGest', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: darkGreen)), Text('O controlo do teu trabalho', style: TextStyle(color: Colors.black54))])),
          const Icon(Icons.wifi_off, color: green), const SizedBox(width: 5), const Text('Offline', style: TextStyle(color: green, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 24),
        Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_PT').format(DateTime.now()), style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [darkGreen, green]), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LUCRO DE HOJE', style: TextStyle(color: Colors.white70, letterSpacing: 1, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7), Text(money.format(income - expense), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14), Row(children: [Expanded(child: _whiteStat('Ganhos', income, Icons.trending_up)), Expanded(child: _whiteStat('Despesas', expense, Icons.trending_down))]),
        ])),
        const SizedBox(height: 20),
        const Text('Resumo de hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _statCard('Ganhos', income, green, Icons.arrow_downward)), const SizedBox(width: 10), Expanded(child: _statCard('Despesas', expense, Colors.redAccent, Icons.arrow_upward))]),
        const SizedBox(height: 22),
        const Text('Movimentos recentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (snap.connectionState == ConnectionState.waiting) const Center(child: CircularProgressIndicator())
        else if (rows.isEmpty) const EmptyState(text: 'Ainda não existem movimentos hoje. Adiciona o teu primeiro ganho ou despesa.')
        else ...rows.take(5).map((r) => TransactionTile(row: r, onChanged: onChanged)),
      ]);
    });
}

Widget _whiteStat(String label, int amount, IconData icon) => Row(children: [Icon(icon, color: Colors.white70, size: 18), const SizedBox(width: 7), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)), Text(money.format(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))]);
Widget _statCard(String label, int amount, Color color, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.black54)), const SizedBox(height: 3), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(money.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)))])));

class HistoryPage extends StatefulWidget {
  final VoidCallback onChanged;
  const HistoryPage({super.key, required this.onChanged});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}
class _HistoryPageState extends State<HistoryPage> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.fromLTRB(18, 18, 18, 12), child: Align(alignment: Alignment.centerLeft, child: Text('Histórico', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: darkGreen)))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'all', label: Text('Todos')), ButtonSegment(value: 'income', label: Text('Ganhos')), ButtonSegment(value: 'expense', label: Text('Despesas'))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first))),
    const SizedBox(height: 10),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: AppDb.instance.all(type: filter == 'all' ? null : filter), builder: (context, snap) {
      final rows = snap.data ?? [];
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (rows.isEmpty) return const EmptyState(text: 'Não há movimentos para apresentar.');
      return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), itemCount: rows.length, itemBuilder: (_, i) => TransactionTile(row: rows[i], onChanged: widget.onChanged));
    }))
  ]);
}

class TransactionTile extends StatelessWidget {
  final Map<String, Object?> row; final VoidCallback onChanged;
  const TransactionTile({super.key, required this.row, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final isIncome = row['type'] == 'income'; final date = DateTime.parse(row['date'] as String);
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: isIncome ? green.withValues(alpha: .12) : Colors.red.withValues(alpha: .10), child: Icon(isIncome ? Icons.add : Icons.remove, color: isIncome ? green : Colors.redAccent)),
      title: Text((row['description'] as String).isEmpty ? row['category'] as String : row['description'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${row['category']} • ${dateFmt.format(date)} • ${timeFmt.format(DateTime.parse(row['created_at'] as String))}'),
      trailing: Text('${isIncome ? '+' : '-'}${money.format(row['amount'])}', style: TextStyle(color: isIncome ? green : Colors.redAccent, fontWeight: FontWeight.bold)),
      onTap: () async { await showTransactionForm(context, existing: row, onSaved: onChanged); },
    ));
  }
}

const incomeCategories = ['Entrega', 'Corrida', 'Serviço', 'Outro'];
const expenseCategories = ['Combustível', 'Alimentação', 'Manutenção', 'Óleo', 'Pneus', 'Estacionamento', 'Outros'];
Future<void> showTransactionForm(BuildContext context, {Map<String, Object?>? existing, required VoidCallback onSaved}) async {
  final formKey = GlobalKey<FormState>();
  String type = (existing?['type'] as String?) ?? 'income';
  String category = (existing?['category'] as String?) ?? incomeCategories.first;
  DateTime date = existing == null ? DateTime.now() : DateTime.parse(existing['date'] as String);
  final amount = TextEditingController(text: existing == null ? '' : (existing['amount'] as int).toString());
  final description = TextEditingController(text: existing?['description'] as String? ?? '');
  final notes = TextEditingController(text: existing?['notes'] as String? ?? '');
  await showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (sheetContext) => StatefulBuilder(builder: (context, setModal) {
    final categories = type == 'income' ? incomeCategories : expenseCategories;
    if (!categories.contains(category)) category = categories.first;
    return Container(padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(context).viewInsets.bottom + 20), decoration: const BoxDecoration(color: Color(0xFFF5F7F5), borderRadius: BorderRadius.vertical(top: Radius.circular(25))), child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(existing == null ? 'Novo movimento' : 'Editar movimento', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: darkGreen))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'income', label: Text('Ganho'), icon: Icon(Icons.add_circle_outline)), ButtonSegment(value: 'expense', label: Text('Despesa'), icon: Icon(Icons.remove_circle_outline))], selected: {type}, onSelectionChanged: (v) => setModal(() { type = v.first; category = type == 'income' ? incomeCategories.first : expenseCategories.first; })),
      const SizedBox(height: 14),
      TextFormField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor (Kz)', prefixIcon: Icon(Icons.payments_outlined)), validator: (v) { final n = int.tryParse((v ?? '').replaceAll('.', '').replaceAll(',', '')); return n == null || n <= 0 ? 'Introduz um valor válido maior que zero.' : null; }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined)), items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setModal(() => category = v ?? categories.first)),
      const SizedBox(height: 12),
      TextFormField(controller: description, decoration: const InputDecoration(labelText: 'Descrição (opcional)', prefixIcon: Icon(Icons.edit_note))),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () async { final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (picked != null) setModal(() => date = picked); }, icon: const Icon(Icons.calendar_today), label: Text('Data: ${dateFmt.format(date)}')),
      const SizedBox(height: 12),
      TextFormField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações (opcional)', prefixIcon: Icon(Icons.notes))),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async {
        if (!formKey.currentState!.validate()) return;
        final raw = amount.text.replaceAll('.', '').replaceAll(',', '');
        final row = {'type': type, 'amount': int.parse(raw), 'category': category, 'description': description.text.trim(), 'notes': notes.text.trim(), 'date': DateFormat('yyyy-MM-dd').format(date), 'created_at': DateTime.now().toIso8601String()};
        if (existing == null) { await AppDb.instance.add(row); } else { await AppDb.instance.updateRow(existing['id'] as int, row); }
        if (context.mounted) Navigator.pop(context);
        onSaved();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimento guardado com sucesso.')));
      }, icon: const Icon(Icons.save), label: const Text('Guardar movimento'))),
      if (existing != null) TextButton.icon(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Eliminar movimento?'), content: const Text('Esta ação não pode ser desfeita.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar'))])); if (ok == true) { await AppDb.instance.deleteRow(existing['id'] as int); if (context.mounted) Navigator.pop(context); onSaved(); } }, icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text('Eliminar movimento', style: TextStyle(color: Colors.red))),
    ]))));
  }));
}

class ReportsPage extends StatefulWidget { const ReportsPage({super.key}); @override State<ReportsPage> createState() => _ReportsPageState(); }
class _ReportsPageState extends State<ReportsPage> {
  String period = 'day';
  DateTime get start { final now = DateTime.now(); if (period == 'day') return dayOnly(now); if (period == 'week') return dayOnly(now).subtract(Duration(days: now.weekday - 1)); return DateTime(now.year, now.month); }
  DateTime get end { final now = DateTime.now(); if (period == 'day') return dayOnly(now); if (period == 'week') return start.add(const Duration(days: 6)); return DateTime(now.year, now.month + 1, 0); }
  String get label => period == 'day' ? 'Hoje' : period == 'week' ? 'Esta semana' : 'Este mês';
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(future: AppDb.instance.all(from: start, to: end), builder: (context, snap) {
    final rows = snap.data ?? []; final income = sumType(rows, 'income'); final expense = sumType(rows, 'expense');
    final days = period == 'day' ? 1 : period == 'week' ? 7 : DateTime.now().day;
    final bars = List.generate(days, (i) { final d = start.add(Duration(days: i)); final dayRows = rows.where((r) => r['date'] == DateFormat('yyyy-MM-dd').format(d)).toList(); return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: sumType(dayRows, 'income').toDouble(), color: green, width: 7, borderRadius: BorderRadius.circular(3)), BarChartRodData(toY: sumType(dayRows, 'expense').toDouble(), color: Colors.orange, width: 7, borderRadius: BorderRadius.circular(3))]); });
    return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
      const Text('Relatórios', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: darkGreen)), const SizedBox(height: 14),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'day', label: Text('Diário')), ButtonSegment(value: 'week', label: Text('Semanal')), ButtonSegment(value: 'month', label: Text('Mensal'))], selected: {period}, onSelectionChanged: (v) => setState(() => period = v.first)),
      const SizedBox(height: 16), Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _statCard('Ganhos', income, green, Icons.trending_up)), const SizedBox(width: 8), Expanded(child: _statCard('Despesas', expense, Colors.redAccent, Icons.trending_down))]),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Lucro líquido', style: TextStyle(color: Colors.black54)), const SizedBox(height: 5), Text(money.format(income - expense), style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: income - expense >= 0 ? green : Colors.redAccent))]))),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ganhos e despesas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 210,
                child: rows.isEmpty
                    ? const Center(child: Text('Sem dados neste período'))
                    : BarChart(
                        BarChartData(
                          barGroups: bars,
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (v, meta) {
                                  String title = 'Hoje';
                                  if (period == 'month') {
                                    title = '${v.toInt() + 1}';
                                  } else if (period == 'week') {
                                    const days = [
                                      'S', 'T', 'Q', 'Q', 'S', 'S', 'D'
                                    ];
                                    final index = v.toInt().clamp(0, 6);
                                    title = days[index];
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      title,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, color: green, size: 9),
                  SizedBox(width: 5),
                  Text('Ganhos', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 15),
                  Icon(Icons.circle, color: Colors.orange, size: 9),
                  SizedBox(width: 5),
                  Text('Despesas', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8), Text('Movimentos: ${rows.length}', style: const TextStyle(color: Colors.black54)),
    ]);
  });
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  Future<void> exportBackup(BuildContext context) async {
    final rows = await AppDb.instance.all();
    final payload = {'app': 'MotoGest', 'format_version': 1, 'exported_at': DateTime.now().toIso8601String(), 'transactions': rows};
    final dir = await getTemporaryDirectory(); final file = File(p.join(dir.path, 'motogest_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
    await Share.shareXFiles([XFile(file.path)], text: 'Cópia de segurança MotoGest');
  }
  Future<void> importBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) return;
    try {
      final data = jsonDecode(await File(result.files.single.path!).readAsString()) as Map<String, dynamic>;
      if (data['app'] != 'MotoGest' || data['format_version'] != 1 || data['transactions'] is! List) throw const FormatException('Ficheiro não reconhecido.');
      final rows = data['transactions'] as List;
      for (final item in rows) { final r = Map<String, dynamic>.from(item as Map); if (!['income', 'expense'].contains(r['type']) || r['amount'] is! int || (r['amount'] as int) <= 0 || r['date'] is! String) throw const FormatException('Dados inválidos na cópia.'); }
      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Restaurar cópia?'), content: const Text('Os movimentos atuais serão substituídos pelos movimentos da cópia selecionada.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restaurar'))]));
      if (confirm == true) { await AppDb.instance.replaceAll(rows); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cópia restaurada com sucesso.'))); }
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível restaurar: $e'))); }
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
    const Text('Definições', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: darkGreen)), const SizedBox(height: 18),
    Card(child: Column(children: [ListTile(leading: const Icon(Icons.file_upload_outlined, color: green), title: const Text('Exportar cópia de segurança'), subtitle: const Text('Guardar os movimentos num ficheiro JSON'), onTap: () => exportBackup(context)), const Divider(height: 1), ListTile(leading: const Icon(Icons.file_download_outlined, color: green), title: const Text('Restaurar cópia de segurança'), subtitle: const Text('Importar um ficheiro JSON do MotoGest'), onTap: () => importBackup(context))])),
    const SizedBox(height: 12), const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sobre o MotoGest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), SizedBox(height: 8), Text('Versão 1.0.0'), Text('Gestão simples de ganhos e despesas para motoboys.'), SizedBox(height: 8), Row(children: [Icon(Icons.wifi_off, color: green), SizedBox(width: 7), Text('Os dados ficam guardados no teu telefone.', style: TextStyle(color: green, fontWeight: FontWeight.w600))])]))),
    const Padding(padding: EdgeInsets.only(top: 14), child: Text('Atenção: desinstalar a aplicação ou limpar os dados do telefone pode apagar os registos. Exporta cópias de segurança regularmente.', style: TextStyle(color: Colors.black54, fontSize: 12))),
  ]);
}

class EmptyState extends StatelessWidget {
  final String text; const EmptyState({super.key, required this.text});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.receipt_long_outlined, size: 42, color: Colors.grey.shade400), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))])));
}
