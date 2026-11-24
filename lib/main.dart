import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const orderId = 'WX-26031';
const storageKey = 'field.receipt.v1.$orderId';
const ink = Color(0xff163b38);
const paper = Color(0xfff7f5ec);
const visit = 6000, part = 12800; // 金额使用整数分
String money(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';
void main() => runApp(const ServiceApp());

class ServiceApp extends StatelessWidget {
  const ServiceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '换芯服务单', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: ink), scaffoldBackgroundColor: paper, useMaterial3: true),
    home: const Orders(),
  );
}

class Orders extends StatelessWidget {
  const Orders({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('外勤工单簿'), backgroundColor: paper),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Padding(
      padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('我的工单', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: ink)),
        const SizedBox(height: 18), Card(child: ListTile(contentPadding: const EdgeInsets.all(18),
          title: const Text('净水器 · 上门换芯'), subtitle: const Text('工单 $orderId'), trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Ticket())))),
        const Text('演示工单仅保存在本设备。试签请使用虚构笔迹。'),
      ])))));
}

class Ticket extends StatefulWidget {
  const Ticket({super.key});
  @override
  State<Ticket> createState() => _TicketState();
}
class _TicketState extends State<Ticket> {
  final strokes = <List<Offset>>[];
  Map<String, dynamic>? receipt;
  bool checked = false, loading = true, busy = false, readFailed = false;
  String message = '';
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final pref = await SharedPreferences.getInstance();
      await pref.reload();
      final raw = pref.getString(storageKey);
      final saved = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
      if (saved != null) {
        if (saved['order'] != orderId) throw const FormatException();
        for (final line in saved['lines'] as List) {
          strokes.add([for (final p in line) Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())]);
        }
      }
      receipt = saved;
    } catch (_) { readFailed = true; message = '无法读取签收记录，请返回工单重试。'; }
    if (mounted) setState(() => loading = false);
  }
  bool get hasInk => strokes.any((line) => line.length > 1 && line.any((p) => (p - line.first).distance > .012));
  Future<void> finish() async {
    if (busy || receipt != null) return;
    if (!hasInk || !checked) {
      setState(() => message = !hasInk ? '尚未手写签名，工单仍在服务中。' : '请先核对并确认费用。'); return;
    }
    setState(() => busy = true);
    final snapshot = {'order': orderId, 'visit': visit, 'part': part, 'total': visit + part,
      'time': DateTime.now().toUtc().toIso8601String(), 'lines': [for (final s in strokes) [for (final p in s) [p.dx, p.dy]]]};
    try {
      final pref = await SharedPreferences.getInstance();
      if (!await pref.setString(storageKey, jsonEncode(snapshot))) throw StateError('write');
      if (mounted) setState(() { receipt = snapshot; message = ''; });
    } catch (_) { if (mounted) setState(() => message = '保存失败，请重试完工。'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Widget fee(String label, int value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(money(value))]));
  @override
  Widget build(BuildContext context) {
    final saved = receipt, locked = saved != null || busy;
    return Scaffold(appBar: AppBar(title: const Text('工单 $orderId'), backgroundColor: paper),
      body: loading ? const Center(child: CircularProgressIndicator()) : readFailed ? Center(child: Text(message)) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 32), children: [
        Text(saved == null ? '服务中' : '已完成 · 签收回执', style: const TextStyle(color: ink, fontWeight: FontWeight.bold)),
        const Text('净水器换芯服务单', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 30, color: ink)),
        const Divider(height: 24), fee('上门服务费', saved?['visit'] ?? visit), fee('复合滤芯 × 1', saved?['part'] ?? part),
        fee(saved == null ? '待确认合计' : '签收时合计', saved?['total'] ?? visit + part), const Divider(height: 24),
        if (saved == null) CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('我已核对费用明细与合计'), value: checked,
          onChanged: busy ? null : (v) => setState(() { checked = v == true; message = ''; })),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('客户手写签名', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          if (!locked) TextButton(onPressed: () => setState(() { strokes.clear(); message = ''; }), child: const Text('清空重签'))]),
        Container(height: 150, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xff809c94)), borderRadius: BorderRadius.circular(6)),
          child: LayoutBuilder(builder: (_, box) {
            Offset normal(Offset p) => Offset((p.dx / box.maxWidth).clamp(0.0, 1.0).toDouble(), (p.dy / box.maxHeight).clamp(0.0, 1.0).toDouble());
            return GestureDetector(key: const Key('signature'), behavior: HitTestBehavior.opaque,
              onPanStart: locked ? null : (d) => setState(() { strokes.add([normal(d.localPosition)]); message = ''; }),
              onPanUpdate: locked ? null : (d) => setState(() { if (strokes.isNotEmpty) strokes.last.add(normal(d.localPosition)); }),
              child: ClipRect(child: CustomPaint(painter: Pen(strokes), child: Center(child: strokes.isEmpty ? const Text('请在此处试签', style: TextStyle(color: Colors.black45)) : null))));
          })),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(message, style: const TextStyle(color: Color(0xff9c331c)))),
        const SizedBox(height: 14),
        if (saved == null) FilledButton(onPressed: busy ? null : finish, child: const Text('确认完工')) else ...[
          Text('签收时间  ${DateTime.parse(saved['time']).toLocal().toString().split('.').first}'),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('返回工单列表'))],
      ]))));
  }
}
class Pen extends CustomPainter {
  final List<List<Offset>> lines;
  Pen(this.lines);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ink..strokeWidth = 2.6..strokeCap = StrokeCap.round;
    Offset project(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    for (final line in lines) {
      for (var i = 1; i < line.length; i++) { canvas.drawLine(project(line[i-1]), project(line[i]), paint); }
    }
  }
  @override
  bool shouldRepaint(Pen oldDelegate) => true;
}
