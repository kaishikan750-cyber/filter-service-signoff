import 'dart:convert';
import 'package:filter_service_signoff/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('空签被拦截，费用核对后签收，重开同一工单还原签收快照', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.view.resetPhysicalSizeForTestIfNeeded();
    Future<void> press(String text) async {
      final item = find.text(text);
      await t.ensureVisible(item);
      await t.tap(item);
      await t.pumpAndSettle();
    }
    await t.pumpWidget(const ServiceApp());
    await press('净水器 · 上门换芯');
    await press('确认完工');
    expect(find.text('尚未手写签名，工单仍在服务中。'), findsOneWidget);
    final store = await SharedPreferences.getInstance();
    expect(store.getString(storageKey), isNull);
    final pad = find.byKey(const Key('signature'));
    await t.ensureVisible(pad);
    final origin = t.getCenter(pad) - const Offset(60, 0);
    final pen = await t.startGesture(origin);
    for (final point in [const Offset(28,-18), const Offset(44,16), const Offset(76,-10), const Offset(104,4)]) {
      await pen.moveTo(origin + point); await t.pump();
    }
    await pen.up(); await t.pump();
    await press('确认完工');
    expect(find.text('请先核对并确认费用。'), findsOneWidget);
    expect(store.getString(storageKey), isNull);
    await press('我已核对费用明细与合计');
    await press('确认完工');
    final record = jsonDecode(store.getString(storageKey)!);
    expect(record['order'], orderId);
    expect([record['visit'], record['part'], record['total']], [6000,12800,18800]);
    expect(record['lines'][0].length, greaterThan(1));
    expect(DateTime.tryParse(record['time']), isNotNull);
    await press('返回工单列表');
    await press('净水器 · 上门换芯');
    expect(find.text('签收时合计'), findsOneWidget);
    expect(find.text('¥188.00'), findsOneWidget);
    expect(find.text('已完成 · 签收回执'), findsOneWidget);
    expect(find.text('确认完工'), findsNothing);
    final painter = t.widgetList<CustomPaint>(find.byType(CustomPaint)).map((w) => w.painter).whereType<Pen>().single;
    expect([for (final line in painter.lines) [for (final p in line) [p.dx,p.dy]]], record['lines']);
  });
}
extension on TestFlutterView {
  Future<void> resetPhysicalSizeForTestIfNeeded() async {
    physicalSize = const Size(800,1100); devicePixelRatio = 1;
    addTearDown(resetPhysicalSize); addTearDown(resetDevicePixelRatio);
  }
}
