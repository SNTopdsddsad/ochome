import 'package:flutter_test/flutter_test.dart';
import 'package:ochome/data/models/role.dart';
import 'package:ochome/data/models/role_custom_attribute.dart';
import 'package:ochome/features/role_card/role_card_content.dart';

void main() {
  test(
    'snapshots copy mutable draft lists and expose immutable selections',
    () {
      final attributes = [const RoleCustomAttribute(name: '关系', content: '好友')];
      final snapshot = RoleCardSnapshot(
        name: '度漪',
        customAttributes: attributes,
      );
      attributes.clear();
      expect(snapshot.customAttributes.single.content, '好友');
      expect(() => snapshot.customAttributes.clear(), throwsUnsupportedError);

      final selectedFields = {RoleCardField.name};
      final selectedAttributes = {0};
      final selection = RoleCardSelection(
        fields: selectedFields,
        customAttributes: selectedAttributes,
      );
      selectedFields.clear();
      selectedAttributes.clear();
      expect(selection.fields, {RoleCardField.name});
      expect(selection.customAttributes, {0});
      expect(() => selection.fields.clear(), throwsUnsupportedError);
      expect(() => selection.customAttributes.clear(), throwsUnsupportedError);
    },
  );

  test(
    'defaults select populated basics while long and custom text stay private',
    () {
      final snapshot = RoleCardSnapshot(
        name: '度漪',
        sex: '女',
        age: '  ',
        coverImg: 'covers/art.png',
        desc: '私密长设定',
        customAttributes: [
          const RoleCustomAttribute(name: '秘密', content: '密文'),
        ],
      );
      final selected = RoleCardSelection.defaults(snapshot);
      expect(selected.fields, {
        RoleCardField.name,
        RoleCardField.sex,
        RoleCardField.cover,
      });
      expect(selected.customAttributes, isEmpty);
      final content = snapshot.select(selected);
      expect(content.name, '度漪');
      expect(content.coverImg, 'covers/art.png');
      expect(content.profile.single.value, '女');
      expect(content.sections, isEmpty);
    },
  );

  test('projection preserves duplicate labels by index and hides unselected values', () {
    final snapshot = RoleCardSnapshot(
      name: '隐藏名字',
      desc: '隐藏设定',
      coverImg: '隐藏图片',
      customAttributes: [
        const RoleCustomAttribute(name: '关系', content: '第一段'),
        const RoleCustomAttribute(name: '关系', content: '第二段\n原样保留'),
        const RoleCustomAttribute(name: '', content: '未起标题的草稿'),
        const RoleCustomAttribute(name: '空字段', content: '   '),
      ],
    );
    final content = snapshot.select(
      RoleCardSelection(fields: {}, customAttributes: {1, 2, 3, 999}),
    );
    expect(content.name, isEmpty);
    expect(content.coverImg, isEmpty);
    expect(content.sections.map((entry) => entry.id), ['custom.1', 'custom.2']);
    expect(content.sections.map((entry) => entry.label), ['关系', '未命名属性']);
    expect(content.sections.first.value, '第二段\n原样保留');
    expect(() => content.sections.clear(), throwsUnsupportedError);
  });

  test(
    'fromRole copies every field without retaining the database identity',
    () {
      const role = Role(
        id: 98,
        name: '名字',
        sex: '性别',
        age: '年龄',
        birthday: '生日',
        race: '种族',
        occupation: '身份',
        desc: '设定',
        coverImg: 'covers/x.png',
        customAttributes: [RoleCustomAttribute(name: '标签', content: '内容')],
      );
      final snapshot = RoleCardSnapshot.fromRole(role);
      expect(RoleCardField.values.map(snapshot.valueFor), [
        '名字',
        '性别',
        '年龄',
        '生日',
        '种族',
        '身份',
        '设定',
        'covers/x.png',
      ]);
      expect(snapshot.customAttributes, role.customAttributes);
      expect(
        identical(snapshot.customAttributes, role.customAttributes),
        isFalse,
      );
      expect(
        identical(snapshot.customAttributes.first, role.customAttributes.first),
        isFalse,
      );
    },
  );
}
