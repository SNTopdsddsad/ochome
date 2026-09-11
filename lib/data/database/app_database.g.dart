// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WorldsTable extends Worlds with TableInfo<$WorldsTable, World> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorldsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
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
  static const VerificationMeta _entriesMeta = const VerificationMeta(
    'entries',
  );
  @override
  late final GeneratedColumn<String> entries = GeneratedColumn<String>(
    'entries',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, summary, coverImg, entries];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'world';
  @override
  VerificationContext validateIntegrity(
    Insertable<World> instance, {
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
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('coverimg')) {
      context.handle(
        _coverImgMeta,
        coverImg.isAcceptableOrUnknown(data['coverimg']!, _coverImgMeta),
      );
    } else if (isInserting) {
      context.missing(_coverImgMeta);
    }
    if (data.containsKey('entries')) {
      context.handle(
        _entriesMeta,
        entries.isAcceptableOrUnknown(data['entries']!, _entriesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  World map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return World(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      coverImg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coverimg'],
      )!,
      entries: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entries'],
      )!,
    );
  }

  @override
  $WorldsTable createAlias(String alias) {
    return $WorldsTable(attachedDatabase, alias);
  }
}

class World extends DataClass implements Insertable<World> {
  final int id;
  final String name;

  /// 简介，允许空字符串。
  final String summary;

  /// 封面相对路径 `covers/<file>`，空字符串表示没有封面；列名与 role 表一致。
  final String coverImg;

  /// 有序词条 JSON `[{"title","content"}]`，由仓库负责编解码。
  final String entries;
  const World({
    required this.id,
    required this.name,
    required this.summary,
    required this.coverImg,
    required this.entries,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['summary'] = Variable<String>(summary);
    map['coverimg'] = Variable<String>(coverImg);
    map['entries'] = Variable<String>(entries);
    return map;
  }

  WorldsCompanion toCompanion(bool nullToAbsent) {
    return WorldsCompanion(
      id: Value(id),
      name: Value(name),
      summary: Value(summary),
      coverImg: Value(coverImg),
      entries: Value(entries),
    );
  }

  factory World.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return World(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      summary: serializer.fromJson<String>(json['summary']),
      coverImg: serializer.fromJson<String>(json['coverImg']),
      entries: serializer.fromJson<String>(json['entries']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'summary': serializer.toJson<String>(summary),
      'coverImg': serializer.toJson<String>(coverImg),
      'entries': serializer.toJson<String>(entries),
    };
  }

  World copyWith({
    int? id,
    String? name,
    String? summary,
    String? coverImg,
    String? entries,
  }) => World(
    id: id ?? this.id,
    name: name ?? this.name,
    summary: summary ?? this.summary,
    coverImg: coverImg ?? this.coverImg,
    entries: entries ?? this.entries,
  );
  World copyWithCompanion(WorldsCompanion data) {
    return World(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      summary: data.summary.present ? data.summary.value : this.summary,
      coverImg: data.coverImg.present ? data.coverImg.value : this.coverImg,
      entries: data.entries.present ? data.entries.value : this.entries,
    );
  }

  @override
  String toString() {
    return (StringBuffer('World(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('summary: $summary, ')
          ..write('coverImg: $coverImg, ')
          ..write('entries: $entries')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, summary, coverImg, entries);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is World &&
          other.id == this.id &&
          other.name == this.name &&
          other.summary == this.summary &&
          other.coverImg == this.coverImg &&
          other.entries == this.entries);
}

class WorldsCompanion extends UpdateCompanion<World> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> summary;
  final Value<String> coverImg;
  final Value<String> entries;
  const WorldsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.summary = const Value.absent(),
    this.coverImg = const Value.absent(),
    this.entries = const Value.absent(),
  });
  WorldsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String summary,
    required String coverImg,
    this.entries = const Value.absent(),
  }) : name = Value(name),
       summary = Value(summary),
       coverImg = Value(coverImg);
  static Insertable<World> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? summary,
    Expression<String>? coverImg,
    Expression<String>? entries,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (summary != null) 'summary': summary,
      if (coverImg != null) 'coverimg': coverImg,
      if (entries != null) 'entries': entries,
    });
  }

  WorldsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? summary,
    Value<String>? coverImg,
    Value<String>? entries,
  }) {
    return WorldsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      coverImg: coverImg ?? this.coverImg,
      entries: entries ?? this.entries,
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
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (coverImg.present) {
      map['coverimg'] = Variable<String>(coverImg.value);
    }
    if (entries.present) {
      map['entries'] = Variable<String>(entries.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorldsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('summary: $summary, ')
          ..write('coverImg: $coverImg, ')
          ..write('entries: $entries')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _worldIdMeta = const VerificationMeta(
    'worldId',
  );
  @override
  late final GeneratedColumn<int> worldId = GeneratedColumn<int>(
    'world_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES world (id) ON DELETE SET NULL',
    ),
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
    worldId,
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
    if (data.containsKey('world_id')) {
      context.handle(
        _worldIdMeta,
        worldId.isAcceptableOrUnknown(data['world_id']!, _worldIdMeta),
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
      worldId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}world_id'],
      ),
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

  /// 所属世界观；删除世界观时由数据库置空，角色本身保留。
  final int? worldId;
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
    this.worldId,
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
    if (!nullToAbsent || worldId != null) {
      map['world_id'] = Variable<int>(worldId);
    }
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
      worldId: worldId == null && nullToAbsent
          ? const Value.absent()
          : Value(worldId),
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
      worldId: serializer.fromJson<int?>(json['worldId']),
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
      'worldId': serializer.toJson<int?>(worldId),
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
    Value<int?> worldId = const Value.absent(),
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
    worldId: worldId.present ? worldId.value : this.worldId,
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
      worldId: data.worldId.present ? data.worldId.value : this.worldId,
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
          ..write('customAttributes: $customAttributes, ')
          ..write('worldId: $worldId')
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
    worldId,
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
          other.customAttributes == this.customAttributes &&
          other.worldId == this.worldId);
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
  final Value<int?> worldId;
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
    this.worldId = const Value.absent(),
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
    this.worldId = const Value.absent(),
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
    Expression<int>? worldId,
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
      if (worldId != null) 'world_id': worldId,
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
    Value<int?>? worldId,
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
      worldId: worldId ?? this.worldId,
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
    if (worldId.present) {
      map['world_id'] = Variable<int>(worldId.value);
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
          ..write('customAttributes: $customAttributes, ')
          ..write('worldId: $worldId')
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

class $RoleAssetsTable extends RoleAssets
    with TableInfo<$RoleAssetsTable, RoleAsset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoleAssetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  List<GeneratedColumn> get $columns => [
    id,
    roleId,
    name,
    kind,
    relativePath,
    bytes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'role_asset';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoleAsset> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
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
  RoleAsset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoleAsset(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}role_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RoleAssetsTable createAlias(String alias) {
    return $RoleAssetsTable(attachedDatabase, alias);
  }
}

class RoleAsset extends DataClass implements Insertable<RoleAsset> {
  final int id;
  final int roleId;
  final String name;
  final String kind;
  final String relativePath;
  final int bytes;
  final DateTime createdAt;
  const RoleAsset({
    required this.id,
    required this.roleId,
    required this.name,
    required this.kind,
    required this.relativePath,
    required this.bytes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['role_id'] = Variable<int>(roleId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['relative_path'] = Variable<String>(relativePath);
    map['bytes'] = Variable<int>(bytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RoleAssetsCompanion toCompanion(bool nullToAbsent) {
    return RoleAssetsCompanion(
      id: Value(id),
      roleId: Value(roleId),
      name: Value(name),
      kind: Value(kind),
      relativePath: Value(relativePath),
      bytes: Value(bytes),
      createdAt: Value(createdAt),
    );
  }

  factory RoleAsset.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoleAsset(
      id: serializer.fromJson<int>(json['id']),
      roleId: serializer.fromJson<int>(json['roleId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      bytes: serializer.fromJson<int>(json['bytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'roleId': serializer.toJson<int>(roleId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'relativePath': serializer.toJson<String>(relativePath),
      'bytes': serializer.toJson<int>(bytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RoleAsset copyWith({
    int? id,
    int? roleId,
    String? name,
    String? kind,
    String? relativePath,
    int? bytes,
    DateTime? createdAt,
  }) => RoleAsset(
    id: id ?? this.id,
    roleId: roleId ?? this.roleId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    relativePath: relativePath ?? this.relativePath,
    bytes: bytes ?? this.bytes,
    createdAt: createdAt ?? this.createdAt,
  );
  RoleAsset copyWithCompanion(RoleAssetsCompanion data) {
    return RoleAsset(
      id: data.id.present ? data.id.value : this.id,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoleAsset(')
          ..write('id: $id, ')
          ..write('roleId: $roleId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('relativePath: $relativePath, ')
          ..write('bytes: $bytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, roleId, name, kind, relativePath, bytes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoleAsset &&
          other.id == this.id &&
          other.roleId == this.roleId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.relativePath == this.relativePath &&
          other.bytes == this.bytes &&
          other.createdAt == this.createdAt);
}

class RoleAssetsCompanion extends UpdateCompanion<RoleAsset> {
  final Value<int> id;
  final Value<int> roleId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> relativePath;
  final Value<int> bytes;
  final Value<DateTime> createdAt;
  const RoleAssetsCompanion({
    this.id = const Value.absent(),
    this.roleId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RoleAssetsCompanion.insert({
    this.id = const Value.absent(),
    required int roleId,
    required String name,
    required String kind,
    required String relativePath,
    required int bytes,
    required DateTime createdAt,
  }) : roleId = Value(roleId),
       name = Value(name),
       kind = Value(kind),
       relativePath = Value(relativePath),
       bytes = Value(bytes),
       createdAt = Value(createdAt);
  static Insertable<RoleAsset> custom({
    Expression<int>? id,
    Expression<int>? roleId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? relativePath,
    Expression<int>? bytes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roleId != null) 'role_id': roleId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (relativePath != null) 'relative_path': relativePath,
      if (bytes != null) 'bytes': bytes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RoleAssetsCompanion copyWith({
    Value<int>? id,
    Value<int>? roleId,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? relativePath,
    Value<int>? bytes,
    Value<DateTime>? createdAt,
  }) {
    return RoleAssetsCompanion(
      id: id ?? this.id,
      roleId: roleId ?? this.roleId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      relativePath: relativePath ?? this.relativePath,
      bytes: bytes ?? this.bytes,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoleAssetsCompanion(')
          ..write('id: $id, ')
          ..write('roleId: $roleId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('relativePath: $relativePath, ')
          ..write('bytes: $bytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RoleRelationshipsTable extends RoleRelationships
    with TableInfo<$RoleRelationshipsTable, RoleRelationship> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoleRelationshipsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fromRoleIdMeta = const VerificationMeta(
    'fromRoleId',
  );
  @override
  late final GeneratedColumn<int> fromRoleId = GeneratedColumn<int>(
    'from_role_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES role (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _toRoleIdMeta = const VerificationMeta(
    'toRoleId',
  );
  @override
  late final GeneratedColumn<int> toRoleId = GeneratedColumn<int>(
    'to_role_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES role (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fromLabelMeta = const VerificationMeta(
    'fromLabel',
  );
  @override
  late final GeneratedColumn<String> fromLabel = GeneratedColumn<String>(
    'from_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toLabelMeta = const VerificationMeta(
    'toLabel',
  );
  @override
  late final GeneratedColumn<String> toLabel = GeneratedColumn<String>(
    'to_label',
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
  List<GeneratedColumn> get $columns => [
    id,
    fromRoleId,
    toRoleId,
    fromLabel,
    toLabel,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'role_relationship';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoleRelationship> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('from_role_id')) {
      context.handle(
        _fromRoleIdMeta,
        fromRoleId.isAcceptableOrUnknown(
          data['from_role_id']!,
          _fromRoleIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromRoleIdMeta);
    }
    if (data.containsKey('to_role_id')) {
      context.handle(
        _toRoleIdMeta,
        toRoleId.isAcceptableOrUnknown(data['to_role_id']!, _toRoleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toRoleIdMeta);
    }
    if (data.containsKey('from_label')) {
      context.handle(
        _fromLabelMeta,
        fromLabel.isAcceptableOrUnknown(data['from_label']!, _fromLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_fromLabelMeta);
    }
    if (data.containsKey('to_label')) {
      context.handle(
        _toLabelMeta,
        toLabel.isAcceptableOrUnknown(data['to_label']!, _toLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_toLabelMeta);
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
  RoleRelationship map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoleRelationship(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fromRoleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}from_role_id'],
      )!,
      toRoleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}to_role_id'],
      )!,
      fromLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_label'],
      )!,
      toLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RoleRelationshipsTable createAlias(String alias) {
    return $RoleRelationshipsTable(attachedDatabase, alias);
  }
}

class RoleRelationship extends DataClass
    implements Insertable<RoleRelationship> {
  final int id;
  final int fromRoleId;
  final int toRoleId;

  /// from 是 to 的 ___。
  final String fromLabel;

  /// to 是 from 的 ___。
  final String toLabel;
  final DateTime createdAt;
  const RoleRelationship({
    required this.id,
    required this.fromRoleId,
    required this.toRoleId,
    required this.fromLabel,
    required this.toLabel,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['from_role_id'] = Variable<int>(fromRoleId);
    map['to_role_id'] = Variable<int>(toRoleId);
    map['from_label'] = Variable<String>(fromLabel);
    map['to_label'] = Variable<String>(toLabel);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RoleRelationshipsCompanion toCompanion(bool nullToAbsent) {
    return RoleRelationshipsCompanion(
      id: Value(id),
      fromRoleId: Value(fromRoleId),
      toRoleId: Value(toRoleId),
      fromLabel: Value(fromLabel),
      toLabel: Value(toLabel),
      createdAt: Value(createdAt),
    );
  }

  factory RoleRelationship.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoleRelationship(
      id: serializer.fromJson<int>(json['id']),
      fromRoleId: serializer.fromJson<int>(json['fromRoleId']),
      toRoleId: serializer.fromJson<int>(json['toRoleId']),
      fromLabel: serializer.fromJson<String>(json['fromLabel']),
      toLabel: serializer.fromJson<String>(json['toLabel']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fromRoleId': serializer.toJson<int>(fromRoleId),
      'toRoleId': serializer.toJson<int>(toRoleId),
      'fromLabel': serializer.toJson<String>(fromLabel),
      'toLabel': serializer.toJson<String>(toLabel),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RoleRelationship copyWith({
    int? id,
    int? fromRoleId,
    int? toRoleId,
    String? fromLabel,
    String? toLabel,
    DateTime? createdAt,
  }) => RoleRelationship(
    id: id ?? this.id,
    fromRoleId: fromRoleId ?? this.fromRoleId,
    toRoleId: toRoleId ?? this.toRoleId,
    fromLabel: fromLabel ?? this.fromLabel,
    toLabel: toLabel ?? this.toLabel,
    createdAt: createdAt ?? this.createdAt,
  );
  RoleRelationship copyWithCompanion(RoleRelationshipsCompanion data) {
    return RoleRelationship(
      id: data.id.present ? data.id.value : this.id,
      fromRoleId: data.fromRoleId.present
          ? data.fromRoleId.value
          : this.fromRoleId,
      toRoleId: data.toRoleId.present ? data.toRoleId.value : this.toRoleId,
      fromLabel: data.fromLabel.present ? data.fromLabel.value : this.fromLabel,
      toLabel: data.toLabel.present ? data.toLabel.value : this.toLabel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoleRelationship(')
          ..write('id: $id, ')
          ..write('fromRoleId: $fromRoleId, ')
          ..write('toRoleId: $toRoleId, ')
          ..write('fromLabel: $fromLabel, ')
          ..write('toLabel: $toLabel, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, fromRoleId, toRoleId, fromLabel, toLabel, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoleRelationship &&
          other.id == this.id &&
          other.fromRoleId == this.fromRoleId &&
          other.toRoleId == this.toRoleId &&
          other.fromLabel == this.fromLabel &&
          other.toLabel == this.toLabel &&
          other.createdAt == this.createdAt);
}

class RoleRelationshipsCompanion extends UpdateCompanion<RoleRelationship> {
  final Value<int> id;
  final Value<int> fromRoleId;
  final Value<int> toRoleId;
  final Value<String> fromLabel;
  final Value<String> toLabel;
  final Value<DateTime> createdAt;
  const RoleRelationshipsCompanion({
    this.id = const Value.absent(),
    this.fromRoleId = const Value.absent(),
    this.toRoleId = const Value.absent(),
    this.fromLabel = const Value.absent(),
    this.toLabel = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RoleRelationshipsCompanion.insert({
    this.id = const Value.absent(),
    required int fromRoleId,
    required int toRoleId,
    required String fromLabel,
    required String toLabel,
    required DateTime createdAt,
  }) : fromRoleId = Value(fromRoleId),
       toRoleId = Value(toRoleId),
       fromLabel = Value(fromLabel),
       toLabel = Value(toLabel),
       createdAt = Value(createdAt);
  static Insertable<RoleRelationship> custom({
    Expression<int>? id,
    Expression<int>? fromRoleId,
    Expression<int>? toRoleId,
    Expression<String>? fromLabel,
    Expression<String>? toLabel,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromRoleId != null) 'from_role_id': fromRoleId,
      if (toRoleId != null) 'to_role_id': toRoleId,
      if (fromLabel != null) 'from_label': fromLabel,
      if (toLabel != null) 'to_label': toLabel,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RoleRelationshipsCompanion copyWith({
    Value<int>? id,
    Value<int>? fromRoleId,
    Value<int>? toRoleId,
    Value<String>? fromLabel,
    Value<String>? toLabel,
    Value<DateTime>? createdAt,
  }) {
    return RoleRelationshipsCompanion(
      id: id ?? this.id,
      fromRoleId: fromRoleId ?? this.fromRoleId,
      toRoleId: toRoleId ?? this.toRoleId,
      fromLabel: fromLabel ?? this.fromLabel,
      toLabel: toLabel ?? this.toLabel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fromRoleId.present) {
      map['from_role_id'] = Variable<int>(fromRoleId.value);
    }
    if (toRoleId.present) {
      map['to_role_id'] = Variable<int>(toRoleId.value);
    }
    if (fromLabel.present) {
      map['from_label'] = Variable<String>(fromLabel.value);
    }
    if (toLabel.present) {
      map['to_label'] = Variable<String>(toLabel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoleRelationshipsCompanion(')
          ..write('id: $id, ')
          ..write('fromRoleId: $fromRoleId, ')
          ..write('toRoleId: $toRoleId, ')
          ..write('fromLabel: $fromLabel, ')
          ..write('toLabel: $toLabel, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WorldsTable worlds = $WorldsTable(this);
  late final $RolesTable roles = $RolesTable(this);
  late final $RoleDescRevisionsTable roleDescRevisions =
      $RoleDescRevisionsTable(this);
  late final $RoleAssetsTable roleAssets = $RoleAssetsTable(this);
  late final $RoleRelationshipsTable roleRelationships =
      $RoleRelationshipsTable(this);
  late final Index roleAssetRoleId = Index(
    'role_asset_role_id',
    'CREATE INDEX role_asset_role_id ON role_asset (role_id)',
  );
  late final Index roleRelationshipFromRoleId = Index(
    'role_relationship_from_role_id',
    'CREATE INDEX role_relationship_from_role_id ON role_relationship (from_role_id)',
  );
  late final Index roleRelationshipToRoleId = Index(
    'role_relationship_to_role_id',
    'CREATE INDEX role_relationship_to_role_id ON role_relationship (to_role_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    worlds,
    roles,
    roleDescRevisions,
    roleAssets,
    roleRelationships,
    roleAssetRoleId,
    roleRelationshipFromRoleId,
    roleRelationshipToRoleId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'world',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('role', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'role',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('role_desc_revision', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'role',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('role_asset', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'role',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('role_relationship', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'role',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('role_relationship', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$WorldsTableCreateCompanionBuilder = WorldsCompanion Function({
  Value<int> id,
  required String name,
  required String summary,
  required String coverImg,
  Value<String> entries,
});
typedef $$WorldsTableUpdateCompanionBuilder = WorldsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> summary,
  Value<String> coverImg,
  Value<String> entries,
});

final class $$WorldsTableReferences
    extends BaseReferences<_$AppDatabase, $WorldsTable, World> {
  $$WorldsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RolesTable, List<Role>> _rolesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.roles,
    aliasName: 'world__id__role__world_id',
  );

  $$RolesTableProcessedTableManager get rolesRefs {
    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.worldId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_rolesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorldsTableFilterComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableFilterComposer({
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

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImg => $composableBuilder(
    column: $table.coverImg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entries => $composableBuilder(
    column: $table.entries,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> rolesRefs(
    Expression<bool> Function($$RolesTableFilterComposer f) f,
  ) {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.worldId,
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
    return f(composer);
  }
}

class $$WorldsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableOrderingComposer({
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

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImg => $composableBuilder(
    column: $table.coverImg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entries => $composableBuilder(
    column: $table.entries,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableAnnotationComposer({
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

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get coverImg =>
      $composableBuilder(column: $table.coverImg, builder: (column) => column);

  GeneratedColumn<String> get entries =>
      $composableBuilder(column: $table.entries, builder: (column) => column);

  Expression<T> rolesRefs<T extends Object>(
    Expression<T> Function($$RolesTableAnnotationComposer a) f,
  ) {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.worldId,
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
    return f(composer);
  }
}

class $$WorldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorldsTable,
          World,
          $$WorldsTableFilterComposer,
          $$WorldsTableOrderingComposer,
          $$WorldsTableAnnotationComposer,
          $$WorldsTableCreateCompanionBuilder,
          $$WorldsTableUpdateCompanionBuilder,
          (World, $$WorldsTableReferences),
          World,
          PrefetchHooks Function({bool rolesRefs})
        > {
  $$WorldsTableTableManager(_$AppDatabase db, $WorldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> coverImg = const Value.absent(),
                Value<String> entries = const Value.absent(),
              }) => WorldsCompanion(
                id: id,
                name: name,
                summary: summary,
                coverImg: coverImg,
                entries: entries,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String summary,
                required String coverImg,
                Value<String> entries = const Value.absent(),
              }) => WorldsCompanion.insert(
                id: id,
                name: name,
                summary: summary,
                coverImg: coverImg,
                entries: entries,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$WorldsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({rolesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (rolesRefs) db.roles],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (rolesRefs)
                    await $_getPrefetchedData<World, $WorldsTable, Role>(
                      currentTable: table,
                      referencedTable: $$WorldsTableReferences._rolesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$WorldsTableReferences(db, table, p0).rolesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.worldId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorldsTable,
      World,
      $$WorldsTableFilterComposer,
      $$WorldsTableOrderingComposer,
      $$WorldsTableAnnotationComposer,
      $$WorldsTableCreateCompanionBuilder,
      $$WorldsTableUpdateCompanionBuilder,
      (World, $$WorldsTableReferences),
      World,
      PrefetchHooks Function({bool rolesRefs})
    >;
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
  Value<int?> worldId,
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
  Value<int?> worldId,
});

final class $$RolesTableReferences
    extends BaseReferences<_$AppDatabase, $RolesTable, Role> {
  $$RolesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorldsTable _worldIdTable(_$AppDatabase db) =>
      db.worlds.createAlias('role__world_id__world__id');

  $$WorldsTableProcessedTableManager? get worldId {
    final $_column = $_itemColumn<int>('world_id');
    if ($_column == null) return null;
    final manager = $$WorldsTableTableManager(
      $_db,
      $_db.worlds,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_worldIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

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

  static MultiTypedResultKey<$RoleAssetsTable, List<RoleAsset>>
  _roleAssetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.roleAssets,
    aliasName: 'role__id__role_asset__role_id',
  );

  $$RoleAssetsTableProcessedTableManager get roleAssetsRefs {
    final manager = $$RoleAssetsTableTableManager(
      $_db,
      $_db.roleAssets,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roleAssetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RoleRelationshipsTable, List<RoleRelationship>>
  _outgoingRelationshipsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.roleRelationships,
        aliasName: 'role__id__role_relationship__from_role_id',
      );

  $$RoleRelationshipsTableProcessedTableManager get outgoingRelationships {
    final manager = $$RoleRelationshipsTableTableManager(
      $_db,
      $_db.roleRelationships,
    ).filter((f) => f.fromRoleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _outgoingRelationshipsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RoleRelationshipsTable, List<RoleRelationship>>
  _incomingRelationshipsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.roleRelationships,
        aliasName: 'role__id__role_relationship__to_role_id',
      );

  $$RoleRelationshipsTableProcessedTableManager get incomingRelationships {
    final manager = $$RoleRelationshipsTableTableManager(
      $_db,
      $_db.roleRelationships,
    ).filter((f) => f.toRoleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _incomingRelationshipsTable($_db),
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

  $$WorldsTableFilterComposer get worldId {
    final $$WorldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableFilterComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  Expression<bool> roleAssetsRefs(
    Expression<bool> Function($$RoleAssetsTableFilterComposer f) f,
  ) {
    final $$RoleAssetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roleAssets,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoleAssetsTableFilterComposer(
            $db: $db,
            $table: $db.roleAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> outgoingRelationships(
    Expression<bool> Function($$RoleRelationshipsTableFilterComposer f) f,
  ) {
    final $$RoleRelationshipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roleRelationships,
      getReferencedColumn: (t) => t.fromRoleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoleRelationshipsTableFilterComposer(
            $db: $db,
            $table: $db.roleRelationships,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> incomingRelationships(
    Expression<bool> Function($$RoleRelationshipsTableFilterComposer f) f,
  ) {
    final $$RoleRelationshipsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roleRelationships,
      getReferencedColumn: (t) => t.toRoleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoleRelationshipsTableFilterComposer(
            $db: $db,
            $table: $db.roleRelationships,
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

  $$WorldsTableOrderingComposer get worldId {
    final $$WorldsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableOrderingComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$WorldsTableAnnotationComposer get worldId {
    final $$WorldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.worldId,
      referencedTable: $db.worlds,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorldsTableAnnotationComposer(
            $db: $db,
            $table: $db.worlds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

  Expression<T> roleAssetsRefs<T extends Object>(
    Expression<T> Function($$RoleAssetsTableAnnotationComposer a) f,
  ) {
    final $$RoleAssetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roleAssets,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoleAssetsTableAnnotationComposer(
            $db: $db,
            $table: $db.roleAssets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> outgoingRelationships<T extends Object>(
    Expression<T> Function($$RoleRelationshipsTableAnnotationComposer a) f,
  ) {
    final $$RoleRelationshipsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.roleRelationships,
          getReferencedColumn: (t) => t.fromRoleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoleRelationshipsTableAnnotationComposer(
                $db: $db,
                $table: $db.roleRelationships,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> incomingRelationships<T extends Object>(
    Expression<T> Function($$RoleRelationshipsTableAnnotationComposer a) f,
  ) {
    final $$RoleRelationshipsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.roleRelationships,
          getReferencedColumn: (t) => t.toRoleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RoleRelationshipsTableAnnotationComposer(
                $db: $db,
                $table: $db.roleRelationships,
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
          PrefetchHooks Function({
            bool worldId,
            bool roleDescRevisionsRefs,
            bool roleAssetsRefs,
            bool outgoingRelationships,
            bool incomingRelationships,
          })
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
                Value<int?> worldId = const Value.absent(),
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
                worldId: worldId,
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
                Value<int?> worldId = const Value.absent(),
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
                worldId: worldId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RolesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                worldId = false,
                roleDescRevisionsRefs = false,
                roleAssetsRefs = false,
                outgoingRelationships = false,
                incomingRelationships = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (roleDescRevisionsRefs) db.roleDescRevisions,
                    if (roleAssetsRefs) db.roleAssets,
                    if (outgoingRelationships) db.roleRelationships,
                    if (incomingRelationships) db.roleRelationships,
                  ],
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
                        if (worldId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.worldId,
                            referencedTable: $$RolesTableReferences
                                ._worldIdTable(db),
                            referencedColumn: $$RolesTableReferences
                                ._worldIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
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
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(
                                db,
                                table,
                                p0,
                              ).roleDescRevisionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (roleAssetsRefs)
                        await $_getPrefetchedData<Role, $RolesTable, RoleAsset>(
                          currentTable: table,
                          referencedTable: $$RolesTableReferences
                              ._roleAssetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(
                                db,
                                table,
                                p0,
                              ).roleAssetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (outgoingRelationships)
                        await $_getPrefetchedData<
                          Role,
                          $RolesTable,
                          RoleRelationship
                        >(
                          currentTable: table,
                          referencedTable: $$RolesTableReferences
                              ._outgoingRelationshipsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(
                                db,
                                table,
                                p0,
                              ).outgoingRelationships,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.fromRoleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (incomingRelationships)
                        await $_getPrefetchedData<
                          Role,
                          $RolesTable,
                          RoleRelationship
                        >(
                          currentTable: table,
                          referencedTable: $$RolesTableReferences
                              ._incomingRelationshipsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(
                                db,
                                table,
                                p0,
                              ).incomingRelationships,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.toRoleId == item.id,
                              ),
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
      PrefetchHooks Function({
        bool worldId,
        bool roleDescRevisionsRefs,
        bool roleAssetsRefs,
        bool outgoingRelationships,
        bool incomingRelationships,
      })
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
typedef $$RoleAssetsTableCreateCompanionBuilder = RoleAssetsCompanion Function({
  Value<int> id,
  required int roleId,
  required String name,
  required String kind,
  required String relativePath,
  required int bytes,
  required DateTime createdAt,
});
typedef $$RoleAssetsTableUpdateCompanionBuilder = RoleAssetsCompanion Function({
  Value<int> id,
  Value<int> roleId,
  Value<String> name,
  Value<String> kind,
  Value<String> relativePath,
  Value<int> bytes,
  Value<DateTime> createdAt,
});

final class $$RoleAssetsTableReferences
    extends BaseReferences<_$AppDatabase, $RoleAssetsTable, RoleAsset> {
  $$RoleAssetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RolesTable _roleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('role_asset__role_id__role__id');

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

class $$RoleAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $RoleAssetsTable> {
  $$RoleAssetsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
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

class $$RoleAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoleAssetsTable> {
  $$RoleAssetsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
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

class $$RoleAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoleAssetsTable> {
  $$RoleAssetsTableAnnotationComposer({
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

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

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

class $$RoleAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoleAssetsTable,
          RoleAsset,
          $$RoleAssetsTableFilterComposer,
          $$RoleAssetsTableOrderingComposer,
          $$RoleAssetsTableAnnotationComposer,
          $$RoleAssetsTableCreateCompanionBuilder,
          $$RoleAssetsTableUpdateCompanionBuilder,
          (RoleAsset, $$RoleAssetsTableReferences),
          RoleAsset,
          PrefetchHooks Function({bool roleId})
        > {
  $$RoleAssetsTableTableManager(_$AppDatabase db, $RoleAssetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoleAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoleAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoleAssetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> roleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RoleAssetsCompanion(
                id: id,
                roleId: roleId,
                name: name,
                kind: kind,
                relativePath: relativePath,
                bytes: bytes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int roleId,
                required String name,
                required String kind,
                required String relativePath,
                required int bytes,
                required DateTime createdAt,
              }) => RoleAssetsCompanion.insert(
                id: id,
                roleId: roleId,
                name: name,
                kind: kind,
                relativePath: relativePath,
                bytes: bytes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoleAssetsTableReferences(db, table, e),
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
                        referencedTable: $$RoleAssetsTableReferences
                            ._roleIdTable(db),
                        referencedColumn: $$RoleAssetsTableReferences
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

typedef $$RoleAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoleAssetsTable,
      RoleAsset,
      $$RoleAssetsTableFilterComposer,
      $$RoleAssetsTableOrderingComposer,
      $$RoleAssetsTableAnnotationComposer,
      $$RoleAssetsTableCreateCompanionBuilder,
      $$RoleAssetsTableUpdateCompanionBuilder,
      (RoleAsset, $$RoleAssetsTableReferences),
      RoleAsset,
      PrefetchHooks Function({bool roleId})
    >;
typedef $$RoleRelationshipsTableCreateCompanionBuilder =
    RoleRelationshipsCompanion Function({
      Value<int> id,
      required int fromRoleId,
      required int toRoleId,
      required String fromLabel,
      required String toLabel,
      required DateTime createdAt,
    });
typedef $$RoleRelationshipsTableUpdateCompanionBuilder =
    RoleRelationshipsCompanion Function({
      Value<int> id,
      Value<int> fromRoleId,
      Value<int> toRoleId,
      Value<String> fromLabel,
      Value<String> toLabel,
      Value<DateTime> createdAt,
    });

final class $$RoleRelationshipsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RoleRelationshipsTable,
          RoleRelationship
        > {
  $$RoleRelationshipsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RolesTable _fromRoleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('role_relationship__from_role_id__role__id');

  $$RolesTableProcessedTableManager get fromRoleId {
    final $_column = $_itemColumn<int>('from_role_id')!;

    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fromRoleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RolesTable _toRoleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('role_relationship__to_role_id__role__id');

  $$RolesTableProcessedTableManager get toRoleId {
    final $_column = $_itemColumn<int>('to_role_id')!;

    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_toRoleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoleRelationshipsTableFilterComposer
    extends Composer<_$AppDatabase, $RoleRelationshipsTable> {
  $$RoleRelationshipsTableFilterComposer({
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

  ColumnFilters<String> get fromLabel => $composableBuilder(
    column: $table.fromLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toLabel => $composableBuilder(
    column: $table.toLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RolesTableFilterComposer get fromRoleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromRoleId,
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

  $$RolesTableFilterComposer get toRoleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toRoleId,
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

class $$RoleRelationshipsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoleRelationshipsTable> {
  $$RoleRelationshipsTableOrderingComposer({
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

  ColumnOrderings<String> get fromLabel => $composableBuilder(
    column: $table.fromLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toLabel => $composableBuilder(
    column: $table.toLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RolesTableOrderingComposer get fromRoleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromRoleId,
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

  $$RolesTableOrderingComposer get toRoleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toRoleId,
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

class $$RoleRelationshipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoleRelationshipsTable> {
  $$RoleRelationshipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fromLabel =>
      $composableBuilder(column: $table.fromLabel, builder: (column) => column);

  GeneratedColumn<String> get toLabel =>
      $composableBuilder(column: $table.toLabel, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RolesTableAnnotationComposer get fromRoleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fromRoleId,
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

  $$RolesTableAnnotationComposer get toRoleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.toRoleId,
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

class $$RoleRelationshipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoleRelationshipsTable,
          RoleRelationship,
          $$RoleRelationshipsTableFilterComposer,
          $$RoleRelationshipsTableOrderingComposer,
          $$RoleRelationshipsTableAnnotationComposer,
          $$RoleRelationshipsTableCreateCompanionBuilder,
          $$RoleRelationshipsTableUpdateCompanionBuilder,
          (RoleRelationship, $$RoleRelationshipsTableReferences),
          RoleRelationship,
          PrefetchHooks Function({bool fromRoleId, bool toRoleId})
        > {
  $$RoleRelationshipsTableTableManager(
    _$AppDatabase db,
    $RoleRelationshipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoleRelationshipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoleRelationshipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoleRelationshipsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> fromRoleId = const Value.absent(),
                Value<int> toRoleId = const Value.absent(),
                Value<String> fromLabel = const Value.absent(),
                Value<String> toLabel = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RoleRelationshipsCompanion(
                id: id,
                fromRoleId: fromRoleId,
                toRoleId: toRoleId,
                fromLabel: fromLabel,
                toLabel: toLabel,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int fromRoleId,
                required int toRoleId,
                required String fromLabel,
                required String toLabel,
                required DateTime createdAt,
              }) => RoleRelationshipsCompanion.insert(
                id: id,
                fromRoleId: fromRoleId,
                toRoleId: toRoleId,
                fromLabel: fromLabel,
                toLabel: toLabel,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RoleRelationshipsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fromRoleId = false, toRoleId = false}) {
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
                    if (fromRoleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.fromRoleId,
                        referencedTable: $$RoleRelationshipsTableReferences
                            ._fromRoleIdTable(db),
                        referencedColumn: $$RoleRelationshipsTableReferences
                            ._fromRoleIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (toRoleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.toRoleId,
                        referencedTable: $$RoleRelationshipsTableReferences
                            ._toRoleIdTable(db),
                        referencedColumn: $$RoleRelationshipsTableReferences
                            ._toRoleIdTable(db)
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

typedef $$RoleRelationshipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoleRelationshipsTable,
      RoleRelationship,
      $$RoleRelationshipsTableFilterComposer,
      $$RoleRelationshipsTableOrderingComposer,
      $$RoleRelationshipsTableAnnotationComposer,
      $$RoleRelationshipsTableCreateCompanionBuilder,
      $$RoleRelationshipsTableUpdateCompanionBuilder,
      (RoleRelationship, $$RoleRelationshipsTableReferences),
      RoleRelationship,
      PrefetchHooks Function({bool fromRoleId, bool toRoleId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WorldsTableTableManager get worlds =>
      $$WorldsTableTableManager(_db, _db.worlds);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db, _db.roles);
  $$RoleDescRevisionsTableTableManager get roleDescRevisions =>
      $$RoleDescRevisionsTableTableManager(_db, _db.roleDescRevisions);
  $$RoleAssetsTableTableManager get roleAssets =>
      $$RoleAssetsTableTableManager(_db, _db.roleAssets);
  $$RoleRelationshipsTableTableManager get roleRelationships =>
      $$RoleRelationshipsTableTableManager(_db, _db.roleRelationships);
}
