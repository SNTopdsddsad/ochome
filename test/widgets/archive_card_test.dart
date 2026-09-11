import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/theme/zaidang_theme.dart';
import 'package:ochome/theme/zaidang_tokens.dart';
import 'package:ochome/widgets/archive_editor/archive_card.dart';

void main() {
  testWidgets('card header shows tinted icon, title, caption and trailing', (
    tester,
  ) async {
    await _pump(
      tester,
      const ArchiveCardHeader(
        icon: Icons.description_outlined,
        title: '基础设定',
        caption: '关于这个角色',
        trailing: Icon(Icons.more_horiz),
      ),
    );

    expect(find.text('基础设定'), findsOneWidget);
    expect(find.text('关于这个角色'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    final icon = tester.widget<Icon>(find.byIcon(Icons.description_outlined));
    expect(icon.color, ZaidangTokens.light.accent);
    final tint = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byIcon(Icons.description_outlined),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = tint.decoration as BoxDecoration;
    expect(decoration.color!.a, closeTo(0.1, 0.01));
  });

  testWidgets('caption hugs the right edge and title keeps its width', (
    tester,
  ) async {
    await _pump(
      tester,
      const ArchiveCardHeader(
        icon: Icons.description_outlined,
        title: '基础设定',
        caption: '关于这个角色',
      ),
    );
    final header = tester.getRect(find.byType(ArchiveCardHeader));
    final caption = tester.getRect(find.text('关于这个角色'));
    final title = tester.getRect(find.text('基础设定'));
    expect(caption.right, closeTo(header.right, 0.5));
    // 标题按自身宽度排，不被平分掉一半行宽。
    expect(title.width, lessThan(header.width / 3));
    expect(caption.left, greaterThan(title.right));
  });

  testWidgets('field cell paints an accent border only while focused', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      Builder(
        builder: (context) => ArchiveFieldCell(
          icon: Icons.person_outline,
          label: '名字',
          child: TextFormField(
            key: const Key('cell-input'),
            controller: controller,
            decoration: archiveCellInputDecoration(context, hint: '角色怎么称呼'),
          ),
        ),
      ),
    );

    BoxDecoration cell() =>
        tester
                .widget<DecoratedBox>(
                  find
                      .ancestor(
                        of: find.text('名字'),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;

    expect(find.text('名字'), findsOneWidget);
    expect(find.text('角色怎么称呼'), findsOneWidget);
    expect(cell().color, ZaidangTokens.light.bg);
    expect(cell().border!.top.color, ZaidangTokens.light.bg);
    expect(cell().border!.top.width, 1);

    await tester.tap(find.byKey(const Key('cell-input')));
    await tester.pump();
    expect(cell().border!.top.color, ZaidangTokens.light.accent);
    expect(cell().border!.top.width, 1);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(cell().border!.top.color, ZaidangTokens.light.bg);
  });

  testWidgets('cell input decoration hides borders until validation fails', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await _pump(
      tester,
      Form(
        key: formKey,
        child: Builder(
          builder: (context) => ArchiveFieldCell(
            icon: Icons.person_outline,
            label: '名字',
            child: TextFormField(
              decoration: archiveCellInputDecoration(context, hint: '提示'),
              validator: (value) =>
                  value == null || value.isEmpty ? '请填写名字' : null,
            ),
          ),
        ),
      ),
    );

    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.filled, isFalse);
    expect(decoration.enabledBorder!.borderSide, BorderSide.none);
    expect(decoration.errorBorder!.borderSide.color, ZaidangTokens.light.ink);

    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('请填写名字'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: zaidangLightTheme(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 350, child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
