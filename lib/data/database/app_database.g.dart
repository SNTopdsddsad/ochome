// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RolesTable extends Roles with TableInfo<$RolesTable, Role> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<String> age = GeneratedColumn<String>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _birthdayMeta = const VerificationMeta(
    'birthday',
  );
  @override
  late final GeneratedColumn<String> birthday = GeneratedColumn<String>(
    'birthday',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _raceMeta = const VerificationMeta('race');
  @override
  late final GeneratedColumn<String> race = GeneratedColumn<String>(
    'race',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occupationMeta = const VerificationMeta(
    'occupation',
  );
  @override
  late final GeneratedColumn<String> occupation = GeneratedColumn<String>(
    'occupation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descMeta = const VerificationMeta('desc');
  @override
  late final GeneratedColumn<String> desc = GeneratedColumn<String>(
    'desc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverImgMeta = const VerificationMeta(
    'coverImg',
  );
  @override
  late final GeneratedColumn<String> coverImg = GeneratedColumn<String>(
    'coverimg',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customAttributesMeta = const VerificationMeta(
    'customAttributes',
  );
  @override
  late final GeneratedColumn<String> customAttributes = GeneratedColumn<String>(
    'custom_attributes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sex,
    age,
    birthday,
    race,
    occupation,
    desc,
    coverImg,
    customAttributes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'role';
  @override
  VerificationContext validateIntegrity(
    Insertable<Role> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    } else if (isInserting) {
      context.missing(_sexMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    } else if (isInserting) {
      context.missing(_ageMeta);
    }
    if (data.containsKey('birthday')) {
      context.handle(
        _birthdayMeta,
        birthday.isAcceptableOrUnknown(data['birthday']!, _birthdayMeta),
      );
    } else if (isInserting) {
      context.missing(_birthdayMeta);
    }
    if (data.containsKey('race')) {
      context.handle(
        _raceMeta,
        race.isAcceptableOrUnknown(data['race']!, _raceMeta),
      );
    } else if (isInserting) {
      context.missing(_raceMeta);
    }
    if (data.containsKey('occupation')) {
      context.handle(
        _occupationMeta,
        occupation.isAcceptableOrUnknown(data['occupation']!, _occupationMeta),
      );
    } else if (isInserting) {
      context.missing(_occupationMeta);
    }
    if (data.containsKey('desc')) {
      context.handle(
        _descMeta,
        desc.isAcceptableOrUnknown(data['desc']!, _descMeta),
      );
    } else if (isInserting) {
      context.missing(_descMeta);
    }
    if (data.containsKey('coverimg')) {
      context.handle(
        _coverImgMeta,
        coverImg.isAcceptableOrUnknown(data['coverimg']!, _coverImgMeta),
      );
    } else if (isInserting) {
      context.missing(_coverImgMeta);
    }
    if (data.containsKey('custom_attributes')) {
      context.handle(
        _customAttributesMeta,
        customAttributes.isAcceptableOrUnknown(
          data['custom_attributes']!,
          _customAttributesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Role map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Role(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sex'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age'],
      )!,
      birthday: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birthday'],
      )!,
      race: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}race'],
      )!,
      occupation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occupation'],
      )!,
      desc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}desc'],
      )!,
      coverImg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coverimg'],
      )!,
      customAttributes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_attributes'],
      )!,
    );
  }

  @override
  $RolesTable createAlias(String alias) {
    return $RolesTable(attachedDatabase, alias);
  }
}

class Role extends DataClass implements Insertable<Role> {
  final int id;
  final String name;
  final String sex;

  /// 年龄按原文存储，如「十七」「外表 20」。
  final String age;

  /// 生日按用户输入的原文存储，不做日期解析。
  final String birthday;

  /// 种族，如人类、兽人、吸血鬼。
  final String race;
  final String occupation;
  final String desc;

  /// 封面图路径或 URL，列名与需求一致为 coverimg。
  final String coverImg;

  /// 按展示顺序存储名称和内容，由仓库负责 JSON 编解码。
  final String customAttributes;
  const Role({
    required this.id,
    required this.name,
    required this.sex,
    required this.age,
    required this.birthday,
    required this.race,
    required this.occupation,
    required this.desc,
    required this.coverImg,
    required this.customAttributes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sex'] = Variable<String>(sex);
    map['age'] = Variable<String>(age);
    map['birthday'] = Variable<String>(birthday);
    map['race'] = Variable<String>(race);
    map['occupation'] = Variable<String>(occupation);
    map['desc'] = Variable<String>(desc);
    map['coverimg'] = Variable<String>(coverImg);
    map['custom_attributes'] = Variable<String>(customAttributes);
    return map;
  }

  RolesCompanion toCompanion(bool nullToAbsent) {
    return RolesCompanion(
      id: Value(id),
      name: Value(name),
      sex: Value(sex),
      age: Value(age),
      birthday: Value(birthday),
      race: Value(race),
      occupation: Value(occupation),
      desc: Value(desc),
      coverImg: Value(coverImg),
      customAttributes: Value(customAttributes),
    );
  }

  factory Role.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Role(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sex: serializer.fromJson<String>(json['sex']),
      age: serializer.fromJson<String>(json['age']),
      birthday: serializer.fromJson<String>(json['birthday']),
      race: serializer.fromJson<String>(json['race']),
      occupation: serializer.fromJson<String>(json['occupation']),
      desc: serializer.fromJson<String>(json['desc']),
      coverImg: serializer.fromJson<String>(json['coverImg']),
      customAttributes: serializer.fromJson<String>(json['customAttributes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sex': serializer.toJson<String>(sex),
      'age': serializer.toJson<String>(age),
      'birthday': serializer.toJson<String>(birthday),
      'race': serializer.toJson<String>(race),
      'occupation': serializer.toJson<String>(occupation),
      'desc': serializer.toJson<String>(desc),
      'coverImg': serializer.toJson<String>(coverImg),
      'customAttributes': serializer.toJson<String>(customAttributes),
    };
  }

  Role copyWith({
    int? id,
    String? name,
    String? sex,
    String? age,
    String? birthday,
    String? race,
    String? occupation,
    String? desc,
    String? coverImg,
    String? customAttributes,
  }) => Role(
    id: id ?? this.id,
    name: name ?? this.name,
    sex: sex ?? this.sex,
    age: age ?? this.age,
    birthday: birthday ?? this.birthday,
    race: race ?? this.race,
    occupation: occupation ?? this.occupation,
    desc: desc ?? this.desc,
    coverImg: coverImg ?? this.coverImg,
    customAttributes: customAttributes ?? this.customAttributes,
  );
  Role copyWithCompanion(RolesCompanion data) {
    return Role(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sex: data.sex.present ? data.sex.value : this.sex,
      age: data.age.present ? data.age.value : this.age,
      birthday: data.birthday.present ? data.birthday.value : this.birthday,
      race: data.race.present ? data.race.value : this.race,
      occupation: data.occupation.present
          ? data.occupation.value
          : this.occupation,
      desc: data.desc.present ? data.desc.value : this.desc,
      coverImg: data.coverImg.present ? data.coverImg.value : this.coverImg,
      customAttributes: data.customAttributes.present
          ? data.customAttributes.value
          : this.customAttributes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Role(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sex: $sex, ')
          ..write('age: $age, ')
          ..write('birthday: $birthday, ')
          ..write('race: $race, ')
          ..write('occupation: $occupation, ')
          ..write('desc: $desc, ')
          ..write('coverImg: $coverImg, ')
          ..write('customAttributes: $customAttributes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sex,
    age,
    birthday,
    race,
    occupation,
    desc,
    coverImg,
    customAttributes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Role &&
          other.id == this.id &&
          other.name == this.name &&
          other.sex == this.sex &&
          other.age == this.age &&
          other.birthday == this.birthday &&
          other.race == this.race &&
          other.occupation == this.occupation &&
          other.desc == this.desc &&
          other.coverImg == this.coverImg &&
          other.customAttributes == this.customAttributes);
}

class RolesCompanion extends UpdateCompanion<Role> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> sex;
  final Value<String> age;
  final Value<String> birthday;
  final Value<String> race;
  final Value<String> occupation;
  final Value<String> desc;
  final Value<String> coverImg;
  final Value<String> customAttributes;
  const RolesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sex = const Value.absent(),
    this.age = const Value.absent(),
    this.birthday = const Value.absent(),
    this.race = const Value.absent(),
    this.occupation = const Value.absent(),
    this.desc = const Value.absent(),
    this.coverImg = const Value.absent(),
    this.customAttributes = const Value.absent(),
  });
  RolesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String sex,
    required String age,
    required String birthday,
    required String race,
    required String occupation,
    required String desc,
    required String coverImg,
    this.customAttributes = const Value.absent(),
  }) : name = Value(name),
       sex = Value(sex),
       age = Value(age),
       birthday = Value(birthday),
       race = Value(race),
       occupation = Value(occupation),
       desc = Value(desc),
       coverImg = Value(coverImg);
  static Insertable<Role> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? sex,
    Expression<String>? age,
    Expression<String>? birthday,
    Expression<String>? race,
    Expression<String>? occupation,
    Expression<String>? desc,
    Expression<String>? coverImg,
    Expression<String>? customAttributes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sex != null) 'sex': sex,
      if (age != null) 'age': age,
      if (birthday != null) 'birthday': birthday,
      if (race != null) 'race': race,
      if (occupation != null) 'occupation': occupation,
      if (desc != null) 'desc': desc,
      if (coverImg != null) 'coverimg': coverImg,
      if (customAttributes != null) 'custom_attributes': customAttributes,
    });
  }

  RolesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? sex,
    Value<String>? age,
    Value<String>? birthday,
    Value<String>? race,
    Value<String>? occupation,
    Value<String>? desc,
    Value<String>? coverImg,
    Value<String>? customAttributes,
  }) {
    return RolesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      birthday: birthday ?? this.birthday,
      race: race ?? this.race,
      occupation: occupation ?? this.occupation,
      desc: desc ?? this.desc,
      coverImg: coverImg ?? this.coverImg,
      customAttributes: customAttributes ?? this.customAttributes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (age.present) {
      map['age'] = Variable<String>(age.value);
    }
    if (birthday.present) {
      map['birthday'] = Variable<String>(birthday.value);
    }
    if (race.present) {
      map['race'] = Variable<String>(race.value);
    }
    if (occupation.present) {
      map['occupation'] = Variable<String>(occupation.value);
    }
    if (desc.present) {
      map['desc'] = Variable<String>(desc.value);
    }
    if (coverImg.present) {
      map['coverimg'] = Variable<String>(coverImg.value);
    }
    if (customAttributes.present) {
      map['custom_attributes'] = Variable<String>(customAttributes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sex: $sex, ')
          ..write('age: $age, ')
          ..write('birthday: $birthday, ')
          ..write('race: $race, ')
          ..write('occupation: $occupation, ')
          ..write('desc: $desc, ')
          ..write('coverImg: $coverImg, ')
          ..write('customAttributes: $customAttributes')
          ..write(')'))
        .toString();
  }
}

class $RoleDescRevisionsTable extends RoleDescRevisions
    with TableInfo<$RoleDescRevisionsTable, RoleDescRevision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoleDescRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<int> roleId = GeneratedColumn<int>(
    'role_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES role (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, roleId, content, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'role_desc_revision';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoleDescRevision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_roleIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoleDescRevision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoleDescRevision(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}role_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RoleDescRevisionsTable createAlias(String alias) {
    return $RoleDescRevisionsTable(attachedDatabase, alias);
  }
}

class RoleDescRevision extends DataClass
    implements Insertable<RoleDescRevision> {
  final int id;
  final int roleId;
  final String content;
  final DateTime createdAt;
  const RoleDescRevision({
    required this.id,
    required this.roleId,
    required this.content,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['role_id'] = Variable<int>(roleId);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RoleDescRevisionsCompanion toCompanion(bool nullToAbsent) {
    return RoleDescRevisionsCompanion(
      id: Value(id),
      roleId: Value(roleId),
      content: Value(content),
      createdAt: Value(createdAt),
    );
  }

  factory RoleDescRevision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoleDescRevision(
      id: serializer.fromJson<int>(json['id']),
      roleId: serializer.fromJson<int>(json['roleId']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'roleId': serializer.toJson<int>(roleId),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RoleDescRevision copyWith({
    int? id,
    int? roleId,
    String? content,
    DateTime? createdAt,
  }) => RoleDescRevision(
    id: id ?? this.id,
    roleId: roleId ?? this.roleId,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
  );
  RoleDescRevision copyWithCompanion(RoleDescRevisionsCompanion data) {
    return RoleDescRevision(
      id: data.id.present ? data.id.value : this.id,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoleDescRevision(')
          ..write('id: $id, ')
          ..write('roleId: $roleId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, roleId, content, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoleDescRevision &&
          other.id == this.id &&
          other.roleId == this.roleId &&
          other.content == this.content &&
          other.createdAt == this.createdAt);
}

class RoleDescRevisionsCompanion extends UpdateCompanion<RoleDescRevision> {
  final Value<int> id;
  final Value<int> roleId;
  final Value<String> content;
  final Value<DateTime> createdAt;
  const RoleDescRevisionsCompanion({
    this.id = const Value.absent(),
    this.roleId = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RoleDescRevisionsCompanion.insert({
    this.id = const Value.absent(),
    required int roleId,
    required String content,
    required DateTime createdAt,
  }) : roleId = Value(roleId),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<RoleDescRevision> custom({
    Expression<int>? id,
    Expression<int>? roleId,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roleId != null) 'role_id': roleId,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RoleDescRevisionsCompanion copyWith({
    Value<int>? id,
    Value<int>? roleId,
    Value<String>? content,
    Value<DateTime>? createdAt,
  }) {
    return RoleDescRevisionsCompanion(
      id: id ?? this.id,
      roleId: roleId ?? this.roleId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<int>(roleId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoleDescRevisionsCompanion(')
          ..write('id: $id, ')
          ..write('roleId: $roleId, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RolesTable roles = $RolesTable(this);
  late final $RoleDescRevisionsTable roleDescRevisions =
      $RoleDescRevisionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    roles,
    roleDescRevisions,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'role',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('role_desc_revision', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RolesTableCreateCompanionBuilder = RolesCompanion Function({
  Value<int> id,
  required String name,
  required String sex,
  required String age,
  required String birthday,
  required String race,
  required String occupation,
  required String desc,
  required String coverImg,
  Value<String> customAttributes,
});
typedef $$RolesTableUpdateCompanionBuilder = RolesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> sex,
  Value<String> age,
  Value<String> birthday,
  Value<String> race,
  Value<String> occupation,
  Value<String> desc,
  Value<String> coverImg,
  Value<String> customAttributes,
});

final class $$RolesTableReferences
    extends BaseReferences<_$AppDatabase, $RolesTable, Role> {
  $$RolesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoleDescRevisionsTable, List<RoleDescRevision>>
  _roleDescRevisionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.roleDescRevisions,
        aliasName: 'role__id__role_desc_revision__role_id',
      );

  $$RoleDescRevisionsTableProcessedTableManager get roleDescRevisionsRefs {
    final manager = $$RoleDescRevisionsTableTableManager(
      $_db,
      $_db.roleDescRevisions,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _roleDescRevisionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RolesTableFilterComposer extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthday => $composableBuilder(
    column: $table.birthday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get race => $composableBuilder(
    column: $table.race,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occupation => $composableBuilder(
    column: $table.occupation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get desc => $composableBuilder(
    column: $table.desc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImg => $composableBuilder(
    column: $table.coverImg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customAttributes => $composableBuilder(
    column: $table.customAttributes,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> roleDescRevisionsRefs(
    Expression<bool> Function($$RoleDescRevisionsTableFilterComposer f) f,
  ) {
    final $$RoleDescRevisionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roleDescRevisions,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoleDescRevisionsTableFilterComposer(
            $db: $db,
            $table: $db.roleDescRevisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableOrderingComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthday => $composableBuilder(
    column: $table.birthday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get race => $composableBuilder(
    column: $table.race,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occupation => $composableBuilder(
    column: $table.occupation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get desc => $composableBuilder(
    column: $table.desc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImg => $composableBuilder(
    column: $table.coverImg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customAttributes => $composableBuilder(
    column: $table.customAttributes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RolesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get birthday =>
      $composableBuilder(column: $table.birthday, builder: (column) => column);

  GeneratedColumn<String> get race =>
      $composableBuilder(column: $table.race, builder: (column) => column);

  GeneratedColumn<String> get occupation => $composableBuilder(
    column: $table.occupation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get desc =>
      $composableBuilder(column: $table.desc, builder: (column) => column);

  GeneratedColumn<String> get coverImg =>
      $composableBuilder(column: $table.coverImg, builder: (column) => column);

  GeneratedColumn<String> get customAttributes => $composableBuilder(
    column: $table.customAttributes,
    builder: (column) => column,
  );

  Expression<T> roleDescRevisionsRefs<T extends Object>(
    Expression<T> Function($$RoleDescRevisionsTableAnnotationComposer a) f,
  ) {
    final $$RoleDescRevisionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.roleDescRevisions,
          getReferencedColumn: (t) => t.roleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoleDescRevisionsTableAnnotationComposer(
                $db: $db,
                $table: $db.roleDescRevisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RolesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RolesTable,
          Role,
          $$RolesTableFilterComposer,
          $$RolesTableOrderingComposer,
          $$RolesTableAnnotationComposer,
          $$RolesTableCreateCompanionBuilder,
          $$RolesTableUpdateCompanionBuilder,
          (Role, $$RolesTableReferences),
          Role,
          PrefetchHooks Function({bool roleDescRevisionsRefs})
        > {
  $$RolesTableTableManager(_$AppDatabase db, $RolesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sex = const Value.absent(),
                Value<String> age = const Value.absent(),
                Value<String> birthday = const Value.absent(),
                Value<String> race = const Value.absent(),
                Value<String> occupation = const Value.absent(),
                Value<String> desc = const Value.absent(),
                Value<String> coverImg = const Value.absent(),
                Value<String> customAttributes = const Value.absent(),
              }) => RolesCompanion(
                id: id,
                name: name,
                sex: sex,
                age: age,
                birthday: birthday,
                race: race,
                occupation: occupation,
                desc: desc,
                coverImg: coverImg,
                customAttributes: customAttributes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String sex,
                required String age,
                required String birthday,
                required String race,
                required String occupation,
                required String desc,
                required String coverImg,
                Value<String> customAttributes = const Value.absent(),
              }) => RolesCompanion.insert(
                id: id,
                name: name,
                sex: sex,
                age: age,
                birthday: birthday,
                race: race,
                occupation: occupation,
                desc: desc,
                coverImg: coverImg,
                customAttributes: customAttributes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RolesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({roleDescRevisionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (roleDescRevisionsRefs) db.roleDescRevisions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (roleDescRevisionsRefs)
                    await $_getPrefetchedData<
                      Role,
                      $RolesTable,
                      RoleDescRevision
                    >(
                      currentTable: table,
                      referencedTable: $$RolesTableReferences
                          ._roleDescRevisionsRefsTable(db),
                      managerFromTypedResult: (p0) => $$RolesTableReferences(
                        db,
                        table,
                        p0,
                      ).roleDescRevisionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.roleId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RolesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RolesTable,
      Role,
      $$RolesTableFilterComposer,
      $$RolesTableOrderingComposer,
      $$RolesTableAnnotationComposer,
      $$RolesTableCreateCompanionBuilder,
      $$RolesTableUpdateCompanionBuilder,
      (Role, $$RolesTableReferences),
      Role,
      PrefetchHooks Function({bool roleDescRevisionsRefs})
    >;
typedef $$RoleDescRevisionsTableCreateCompanionBuilder =
    RoleDescRevisionsCompanion Function({
      Value<int> id,
      required int roleId,
      required String content,
      required DateTime createdAt,
    });
typedef $$RoleDescRevisionsTableUpdateCompanionBuilder =
    RoleDescRevisionsCompanion Function({
      Value<int> id,
      Value<int> roleId,
      Value<String> content,
      Value<DateTime> createdAt,
    });

final class $$RoleDescRevisionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RoleDescRevisionsTable,
          RoleDescRevision
        > {
  $$RoleDescRevisionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RolesTable _roleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('role_desc_revision__role_id__role__id');

  $$RolesTableProcessedTableManager get roleId {
    final $_column = $_itemColumn<int>('role_id')!;

    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoleDescRevisionsTableFilterComposer
    extends Composer<_$AppDatabase, $RoleDescRevisionsTable> {
  $$RoleDescRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RolesTableFilterComposer get roleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoleDescRevisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoleDescRevisionsTable> {
  $$RoleDescRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RolesTableOrderingComposer get roleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableOrderingComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoleDescRevisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoleDescRevisionsTable> {
  $$RoleDescRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RolesTableAnnotationComposer get roleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoleDescRevisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoleDescRevisionsTable,
          RoleDescRevision,
          $$RoleDescRevisionsTableFilterComposer,
          $$RoleDescRevisionsTableOrderingComposer,
          $$RoleDescRevisionsTableAnnotationComposer,
          $$RoleDescRevisionsTableCreateCompanionBuilder,
          $$RoleDescRevisionsTableUpdateCompanionBuilder,
          (RoleDescRevision, $$RoleDescRevisionsTableReferences),
          RoleDescRevision,
          PrefetchHooks Function({bool roleId})
        > {
  $$RoleDescRevisionsTableTableManager(
    _$AppDatabase db,
    $RoleDescRevisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoleDescRevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoleDescRevisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoleDescRevisionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> roleId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RoleDescRevisionsCompanion(
                id: id,
                roleId: roleId,
                content: content,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int roleId,
                required String content,
                required DateTime createdAt,
              }) => RoleDescRevisionsCompanion.insert(
                id: id,
                roleId: roleId,
                content: content,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoleDescRevisionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({roleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (roleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.roleId,
                        referencedTable: $$RoleDescRevisionsTableReferences
                            ._roleIdTable(db),
                        referencedColumn: $$RoleDescRevisionsTableReferences
                            ._roleIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RoleDescRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoleDescRevisionsTable,
      RoleDescRevision,
      $$RoleDescRevisionsTableFilterComposer,
      $$RoleDescRevisionsTableOrderingComposer,
      $$RoleDescRevisionsTableAnnotationComposer,
      $$RoleDescRevisionsTableCreateCompanionBuilder,
      $$RoleDescRevisionsTableUpdateCompanionBuilder,
      (RoleDescRevision, $$RoleDescRevisionsTableReferences),
      RoleDescRevision,
      PrefetchHooks Function({bool roleId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db, _db.roles);
  $$RoleDescRevisionsTableTableManager get roleDescRevisions =>
      $$RoleDescRevisionsTableTableManager(_db, _db.roleDescRevisions);
}
