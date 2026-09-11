import 'package:flutter/material.dart';

import '../../theme/zaidang_spacing.dart';
import '../../theme/zaidang_type.dart';
import '../../widgets/section_label.dart';
import 'role_card_content.dart';

class RoleCardFieldPicker extends StatefulWidget {
  const RoleCardFieldPicker({
    super.key,
    required this.snapshot,
    required this.selection,
  });

  final RoleCardSnapshot snapshot;
  final RoleCardSelection selection;

  @override
  State<RoleCardFieldPicker> createState() => _RoleCardFieldPickerState();
}

class _RoleCardFieldPickerState extends State<RoleCardFieldPicker> {
  late final _fields = {...widget.selection.fields};
  late final _attributes = {...widget.selection.customAttributes};

  @override
  Widget build(BuildContext context) {
    final type = ZaidangType.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZaidangSpacing.page,
              ZaidangSpacing.md,
              ZaidangSpacing.md,
              ZaidangSpacing.xs,
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('显示内容', style: type.heading),
                TextButton(
                  key: const Key('role-card-fields-apply'),
                  onPressed: () => Navigator.of(context).pop(
                    RoleCardSelection(
                      fields: _fields,
                      customAttributes: _attributes,
                    ),
                  ),
                  child: const Text('应用'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: ZaidangSpacing.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ZaidangSpacing.page,
                    0,
                    ZaidangSpacing.page,
                    ZaidangSpacing.md,
                  ),
                  child: Text('只导出勾选的内容。隐藏字段不会遮盖立绘里已有的文字。', style: type.body),
                ),
                for (final field in const [
                  RoleCardField.cover,
                  RoleCardField.name,
                  RoleCardField.sex,
                  RoleCardField.age,
                  RoleCardField.birthday,
                  RoleCardField.race,
                  RoleCardField.occupation,
                  RoleCardField.desc,
                ])
                  _field(field),
                if (widget.snapshot.customAttributes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      ZaidangSpacing.page,
                      ZaidangSpacing.xl,
                      ZaidangSpacing.page,
                      ZaidangSpacing.xs,
                    ),
                    child: SectionLabel('自定义属性', padding: EdgeInsets.zero),
                  ),
                  for (
                    var index = 0;
                    index < widget.snapshot.customAttributes.length;
                    index++
                  )
                    _attribute(index),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(RoleCardField field) {
    final value = widget.snapshot.valueFor(field);
    final hasContent = value.trim().isNotEmpty;
    return CheckboxListTile(
      key: ValueKey('role-card-field-${field.name}'),
      value: hasContent && _fields.contains(field),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(field.label),
      subtitle: field == RoleCardField.cover && hasContent
          ? null
          : Text(
              hasContent ? value : '未填写',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      onChanged: !hasContent
          ? null
          : (selected) => setState(() {
              selected == true ? _fields.add(field) : _fields.remove(field);
            }),
    );
  }

  Widget _attribute(int index) {
    final attribute = widget.snapshot.customAttributes[index];
    final hasContent = attribute.content.trim().isNotEmpty;
    return CheckboxListTile(
      key: ValueKey('role-card-attribute-$index'),
      value: hasContent && _attributes.contains(index),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(attribute.name.trim().isEmpty ? '未命名属性' : attribute.name),
      subtitle: Text(
        hasContent ? attribute.content : '未填写',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: !hasContent
          ? null
          : (selected) => setState(() {
              selected == true
                  ? _attributes.add(index)
                  : _attributes.remove(index);
            }),
    );
  }
}
