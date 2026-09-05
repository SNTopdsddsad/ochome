import '../../data/models/role.dart';
import '../../data/models/role_custom_attribute.dart';

enum RoleCardField {
  name('名字'),
  sex('性别'),
  age('年龄'),
  birthday('生日'),
  race('种族'),
  occupation('身份'),
  desc('角色设定'),
  cover('立绘');

  const RoleCardField(this.label);
  final String label;
}

/// A copy of the editor draft. No repository or controller survives this boundary.
class RoleCardSnapshot {
  RoleCardSnapshot({
    this.name = '',
    this.sex = '',
    this.age = '',
    this.birthday = '',
    this.race = '',
    this.occupation = '',
    this.desc = '',
    this.coverImg = '',
    List<RoleCustomAttribute> customAttributes = const [],
  }) : customAttributes = List.unmodifiable([
         for (final attribute in customAttributes)
           RoleCustomAttribute(
             name: attribute.name,
             content: attribute.content,
           ),
       ]);

  factory RoleCardSnapshot.fromRole(Role role) => RoleCardSnapshot(
    name: role.name,
    sex: role.sex,
    age: role.age,
    birthday: role.birthday,
    race: role.race,
    occupation: role.occupation,
    desc: role.desc,
    coverImg: role.coverImg,
    customAttributes: role.customAttributes,
  );

  final String name;
  final String sex;
  final String age;
  final String birthday;
  final String race;
  final String occupation;
  final String desc;
  final String coverImg;
  final List<RoleCustomAttribute> customAttributes;

  String valueFor(RoleCardField field) => switch (field) {
    RoleCardField.name => name,
    RoleCardField.sex => sex,
    RoleCardField.age => age,
    RoleCardField.birthday => birthday,
    RoleCardField.race => race,
    RoleCardField.occupation => occupation,
    RoleCardField.desc => desc,
    RoleCardField.cover => coverImg,
  };

  RoleCardContent select(RoleCardSelection selection) {
    String selected(RoleCardField field) {
      final value = valueFor(field);
      return selection.fields.contains(field) && value.trim().isNotEmpty
          ? value
          : '';
    }

    return RoleCardContent._(
      name: selected(RoleCardField.name),
      coverImg: selected(RoleCardField.cover),
      profile: [
        for (final field in const [
          RoleCardField.sex,
          RoleCardField.age,
          RoleCardField.birthday,
          RoleCardField.race,
          RoleCardField.occupation,
        ])
          if (selected(field).isNotEmpty)
            RoleCardText(
              id: 'field.${field.name}',
              label: field.label,
              value: selected(field),
            ),
      ],
      sections: [
        if (selected(RoleCardField.desc).isNotEmpty)
          RoleCardText(
            id: 'field.desc',
            label: RoleCardField.desc.label,
            value: selected(RoleCardField.desc),
          ),
        for (var index = 0; index < customAttributes.length; index++)
          if (selection.customAttributes.contains(index) &&
              customAttributes[index].content.trim().isNotEmpty)
            RoleCardText(
              id: 'custom.$index',
              label: customAttributes[index].name.trim().isEmpty
                  ? '未命名属性'
                  : customAttributes[index].name,
              value: customAttributes[index].content,
            ),
      ],
    );
  }
}

class RoleCardSelection {
  RoleCardSelection({
    required Set<RoleCardField> fields,
    required Set<int> customAttributes,
  }) : fields = Set.unmodifiable(fields),
       customAttributes = Set.unmodifiable(customAttributes);

  factory RoleCardSelection.defaults(RoleCardSnapshot snapshot) =>
      RoleCardSelection(
        fields: {
          for (final field in RoleCardField.values)
            if (field != RoleCardField.desc &&
                snapshot.valueFor(field).trim().isNotEmpty)
              field,
        },
        customAttributes: {},
      );

  final Set<RoleCardField> fields;
  final Set<int> customAttributes;
}

/// A selected text block retains its identity when custom labels are duplicated.
class RoleCardText {
  const RoleCardText({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}

/// Renderer input. Hidden values and the original snapshot are never retained.
class RoleCardContent {
  RoleCardContent._({
    required this.name,
    required this.coverImg,
    required List<RoleCardText> profile,
    required List<RoleCardText> sections,
  }) : profile = List.unmodifiable(profile),
       sections = List.unmodifiable(sections);

  final String name;
  final String coverImg;
  final List<RoleCardText> profile;
  final List<RoleCardText> sections;

  bool get isEmpty =>
      name.isEmpty && coverImg.isEmpty && profile.isEmpty && sections.isEmpty;
}
