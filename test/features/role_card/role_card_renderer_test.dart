import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/features/role_card/role_card_content.dart';
import 'package:ochome/features/role_card/role_card_renderer.dart';

RoleCardContent selectAll(RoleCardSnapshot snapshot) => snapshot.select(
  RoleCardSelection(
    fields: RoleCardField.values.toSet(),
    customAttributes: {
      for (var i = 0; i < snapshot.customAttributes.length; i++) i,
    },
  ),
);

void expectCompleteCoverage(RoleCardDocument document) {
  for (final coverage in document.textCoverage) {
    expect(coverage.fragments, isNotEmpty, reason: coverage.id);
    var nextLine = 0;
    for (final fragment in coverage.fragments) {
      expect(fragment.firstLine, nextLine, reason: coverage.id);
      expect(
        fragment.endLine,
        greaterThan(fragment.firstLine),
        reason: coverage.id,
      );
      expect(fragment.page, inInclusiveRange(0, document.pageCount - 1));
      expect(fragment.bounds.left, greaterThanOrEqualTo(0));
      expect(fragment.bounds.top, greaterThanOrEqualTo(0));
      expect(fragment.bounds.right, lessThanOrEqualTo(480));
      expect(fragment.bounds.bottom, lessThanOrEqualTo(600));
      nextLine = fragment.endLine;
    }
    expect(nextLine, coverage.lineCount, reason: coverage.id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const renderer = RoleCardRenderer();
  late Directory fixtureDirectory;
  late File artwork;

  setUpAll(() async {
    fixtureDirectory = await Directory.systemTemp.createTemp('role-card-test-');
    artwork = File('${fixtureDirectory.path}/portrait.png');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 80, 60),
      Paint()..color = const Color(0xFFFF0000),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 60, 80, 60),
      Paint()..color = const Color(0xFF0000FF),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(80, 120);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await artwork.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });

  tearDownAll(() async {
    await fixtureDirectory.delete(recursive: true);
  });

  test('empty selection fails deliberately, and hidden artwork never resolves a path', () async {
    final snapshot = RoleCardSnapshot(
      name: '仅名字',
      coverImg: 'covers/missing.png',
    );
    var supportLookups = 0;
    final document = await renderer.prepare(
      snapshot.select(
        RoleCardSelection(fields: {RoleCardField.name}, customAttributes: {}),
      ),
      supportDirectory: () async {
        supportLookups++;
        throw StateError('hidden images must not load');
      },
    );
    expect(supportLookups, 0);
    expect(document.pageCount, 1);
    expect(document.semanticsForPage(0), contains('仅名字'));
    expect(document.semanticsForPage(0), isNot(contains('missing.png')));
    document.dispose();
    await expectLater(
      renderer.prepare(selectAll(RoleCardSnapshot())),
      throwsA(
        isA<RoleCardRenderException>().having(
          (error) => error.code,
          'code',
          RoleCardRenderFailure.emptyContent,
        ),
      ),
    );
  });

  test(
    'selected missing and corrupt artwork block successful export',
    () async {
      final corrupt = File('${fixtureDirectory.path}/corrupt.png');
      await corrupt.writeAsString('not an image');
      for (final file in [
        File('${fixtureDirectory.path}/missing.png'),
        corrupt,
      ]) {
        await expectLater(
          renderer.prepare(
            selectAll(RoleCardSnapshot(name: '名字', coverImg: file.path)),
          ),
          throwsA(
            isA<RoleCardRenderException>().having(
              (error) => error.code,
              'code',
              RoleCardRenderFailure.imageUnavailable,
            ),
          ),
        );
      }
    },
  );

  test('filled setting sheet keeps paired short blocks and resolves relative cover once', () async {
    var lookups = 0;
    final document = await renderer.prepare(
      selectAll(
        RoleCardSnapshot(
          name: '模板测试',
          sex: '女',
          age: '二十岁',
          birthday: '一月一日',
          race: '人类',
          occupation: '旅行者',
          coverImg: 'portrait.png',
          desc: '一段公开设定。',
          customAttributes: [
            const RoleCustomAttribute(name: '喜好', content: '晴天和远行。'),
          ],
        ),
      ),
      supportDirectory: () async {
        lookups++;
        return fixtureDirectory;
      },
    );
    addTearDown(document.dispose);
    expect(lookups, 1);
    expect(document.pageCount, 1);
    expectCompleteCoverage(document);
    expect(document.textCoverage.length, 8);
    final description = document.textCoverage.singleWhere(
      (value) => value.id == 'field.desc',
    );
    final custom = document.textCoverage.singleWhere(
      (value) => value.id == 'custom.0',
    );
    expect(description.fragments.single.bounds.left, 28);
    expect(custom.fragments.single.bounds.left, 250);
    expect(
      description.fragments.single.bounds.top,
      custom.fragments.single.bounds.top,
    );
    final png = await document.renderPng(0);
    expect(ByteData.sublistView(png).getUint32(16), 1440);
  });

  test(
    'overflowing basic field keeps its complete value on later pages',
    () async {
      final longValue = List.filled(80, '这一段身份说明应该完整保留。').join('\n');
      final document = await renderer.prepare(
        selectAll(
          RoleCardSnapshot(
            name: '测试',
            coverImg: artwork.path,
            occupation: longValue,
            sex: '自由填写',
            age: '很长很长的年龄自由文本',
            birthday: '十一月十七日',
            race: '多种族混合设定',
            desc: '短设定',
          ),
        ),
      );
      addTearDown(document.dispose);
      expect(document.pageCount, greaterThan(1));
      expectCompleteCoverage(document);
      final coverage = document.textCoverage.singleWhere(
        (entry) => entry.id == 'field.occupation',
      );
      expect(coverage.value, longValue);
      expect(coverage.fragments.last.page, greaterThan(0));
      final png = await document.renderPng(document.pageCount - 1);
      expect(ByteData.sublistView(png).getUint32(20), 1920);
    },
  );

  test(
    'long CJK, emoji, newlines and duplicate custom labels retain every line',
    () async {
      final name = List.filled(18, '非常非常长的角色名字𠮷').join();
      final profession = List.filled(25, '旅行者，记录群星与海的故事。').join();
      final description = List.generate(
        140,
        (i) => '$i 夜里看星，晨起听雨。🧑🏽‍🎨 家人👨‍👩‍👧‍👦，e\u0301。',
      ).join('\n');
      final snapshot = RoleCardSnapshot(
        name: name,
        occupation: profession,
        desc: description,
        customAttributes: [
          const RoleCustomAttribute(name: '关系', content: '第一位旅伴'),
          RoleCustomAttribute(
            name: List.filled(40, '很长的属性名称').join(),
            content: '最后一行的完整内容🌙',
          ),
          const RoleCustomAttribute(name: '关系', content: '另一位旅伴'),
        ],
      );
      final document = await renderer.prepare(selectAll(snapshot));
      addTearDown(document.dispose);
      expect(document.pageCount, greaterThan(3));
      expectCompleteCoverage(document);
      final values = {
        for (final entry in document.textCoverage) entry.id: entry.value,
      };
      expect(values, {
        'field.name': name,
        'field.occupation': profession,
        'field.desc': description,
        'custom.0': '第一位旅伴',
        'custom.1': '最后一行的完整内容🌙',
        'custom.2': '另一位旅伴',
      });
      final semantics = List.generate(
        document.pageCount,
        document.semanticsForPage,
      ).join('\n');
      for (final value in values.values) {
        expect(semantics, contains(value));
      }
    },
  );

  test('many short sections progress through pages without orphaning or truncation', () async {
    final attributes = List.generate(
      180,
      (i) => RoleCustomAttribute(name: '属性 $i', content: '这条内容属于第 $i 个属性。'),
    );
    final document = await renderer.prepare(
      selectAll(RoleCardSnapshot(customAttributes: attributes)),
    );
    addTearDown(document.dispose);
    expect(document.textCoverage.length, 180);
    expectCompleteCoverage(document);
    for (final block in document.textCoverage) {
      expect(
        block.fragments.first.endLine - block.fragments.first.firstLine,
        greaterThanOrEqualTo(2),
      );
    }
  });

  test('all pages omit hidden identity and private values while selected cover remains', () async {
    final snapshot = RoleCardSnapshot(
      name: 'TOP_SECRET_NAME',
      sex: 'TOP_SECRET_SEX',
      coverImg: artwork.path,
      desc: List.filled(100, '这段可以分享的角色设定会进入续页。').join('\n'),
      customAttributes: [
        const RoleCustomAttribute(name: '私密标题', content: 'TOP_SECRET_VALUE'),
      ],
    );
    final document = await renderer.prepare(
      snapshot.select(
        RoleCardSelection(
          fields: {RoleCardField.cover, RoleCardField.desc},
          customAttributes: {},
        ),
      ),
    );
    addTearDown(document.dispose);
    final semantics = List.generate(
      document.pageCount,
      document.semanticsForPage,
    ).join('\n');
    expect(semantics, isNot(contains('TOP_SECRET')));
    expect(semantics, isNot(contains('私密标题')));
    expect(semantics, isNot(contains(artwork.path)));
    expect(document.textCoverage.map((value) => value.id), ['field.desc']);
    expectCompleteCoverage(document);
  });

  test(
    'actual sparse PNG is 1440 × 1920 and preserves both image edges',
    () async {
      var supportLookups = 0;
      final document = await renderer.prepare(
        selectAll(RoleCardSnapshot(name: '度漪', coverImg: artwork.path)),
        supportDirectory: () async {
          supportLookups++;
          return fixtureDirectory;
        },
      );
      addTearDown(document.dispose);
      expect(
        supportLookups,
        0,
        reason: 'absolute artwork does not need a support lookup',
      );
      expect(document.pageCount, 1);
      expectCompleteCoverage(document);
      final bytes = await document.renderPng(0);
      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final header = ByteData.sublistView(bytes);
      expect(header.getUint32(16), 1440);
      expect(header.getUint32(20), 1920);
      final codec = await ui.instantiateImageCodec(bytes);
      final raster = (await codec.getNextFrame()).image;
      final pixels = (await raster.toByteData())!.buffer.asUint8List();
      // Portrait 80:120 fits within 344×568 at (20,20), giving 344×516,
      // centered at y=46. Both outer edges survive the contain-fit transform.
      List<int> rgb(int x, int y) =>
          pixels.sublist((y * 1440 + x) * 4, (y * 1440 + x) * 4 + 3);
      expect(rgb(70, 150), [255, 0, 0]);
      expect(rgb(1080, 1670), [0, 0, 255]);
      expect(rgb(45, 150), [244, 241, 233]);
      raster.dispose();
      codec.dispose();
      expect(
        await document.renderPng(0),
        bytes,
        reason: 'same document paints deterministic output',
      );
    },
  );

  test(
    'a tall joined name moves out of the vertical rail without clipping',
    () async {
      final name = '👨\u200d' * 30 + '👨';
      final document = await renderer.prepare(
        selectAll(RoleCardSnapshot(name: name, coverImg: artwork.path)),
      );
      addTearDown(document.dispose);
      expect(document.pageCount, greaterThan(1));
      expectCompleteCoverage(document);
      expect(document.textCoverage.single.value, name);
    },
  );

  test('resource limit reports failure instead of silently cutting selected content', () async {
    await expectLater(
      renderer.prepare(selectAll(RoleCardSnapshot(desc: '字' * 120001))),
      throwsA(
        isA<RoleCardRenderException>().having(
          (error) => error.code,
          'code',
          RoleCardRenderFailure.contentTooLarge,
        ),
      ),
    );
  });

  test('disposed documents cannot paint or encode', () async {
    final document = await renderer.prepare(
      selectAll(RoleCardSnapshot(name: '短名字')),
    );
    document.dispose();
    document.dispose();
    expect(() => document.semanticsForPage(0), throwsStateError);
    await expectLater(document.renderPng(0), throwsStateError);
  });
}
