import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../classes/models/class_model.dart';
import '../models/enrol_by_token.dart';

String? _genderName(int? gender) => switch (gender) {
  1 => 'Gents',
  2 => 'Ladies',
  _ => null,
};

/// Everything the lookup returns about the member (#1050).
class MemberDetailsCard extends StatelessWidget {
  const MemberDetailsCard({super.key, required this.member});

  final MemberDetails member;

  @override
  Widget build(BuildContext context) {
    final requested = member.requestedClass;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.spacingSM),
          _Field('Token', '${member.token}'),
          _Field('Gender', _genderName(member.gender)),
          _Field('Email', member.email),
          _Field('Phone', member.mobile),
          _Field('City', member.city),
          _Field('Country', member.country),
          _Field('Registered', member.registeredOn),
          if (requested != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSM),
              child: Text(
                'Asked for ${requested.code}: ${requested.name}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: AppTheme.spacingMD),
          const AppSectionHeader(title: 'In these classes now'),
          if (member.classesNow.isEmpty)
            const Text('Not in any class.')
          else
            for (final c in member.classesNow)
              _ClassLine(c, c.level == null ? null : 'Level ${c.level}'),
          if (member.classesLeft.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingMD),
            const AppSectionHeader(title: 'Classes they left'),
            for (final c in member.classesLeft)
              _ClassLine(c, c.leftOn == null ? null : 'Left ${c.leftOn}'),
          ],
        ],
      ),
    );
  }
}

/// A label and its value; nothing when the member has no value.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
            ),
          ),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }
}

class _ClassLine extends StatelessWidget {
  const _ClassLine(this.cls, this.extra);

  final EnrolClassRef cls;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cls.code, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(cls.name),
          if (extra != null)
            Text(
              extra!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
            ),
        ],
      ),
    );
  }
}

/// The classes the member can be enrolled into. Only active classes of the
/// member's gender are listed (both when none is recorded); the class the
/// member's link named comes first; classes they are in are disabled.
class ClassChooser extends StatefulWidget {
  const ClassChooser({
    super.key,
    required this.member,
    required this.classes,
    required this.selectedId,
    required this.onSelect,
  });

  final MemberDetails member;
  final List<ClassModel> classes;
  final int? selectedId;
  final ValueChanged<ClassModel> onSelect;

  @override
  State<ClassChooser> createState() => _ClassChooserState();
}

class _ClassChooserState extends State<ClassChooser> {
  String _filter = '';

  List<ClassModel> _visible(Set<int> inClasses) {
    final gender = widget.member.gender;
    final askedId = widget.member.requestedClass?.id;
    final needle = _filter.trim().toLowerCase();
    final shown = [
      for (final c in widget.classes)
        if (c.status == 'A' &&
            (gender == null || c.gender == gender) &&
            (needle.isEmpty ||
                c.code.toLowerCase().contains(needle) ||
                c.name.toLowerCase().contains(needle)))
          c,
    ];
    shown.sort((a, b) {
      final byAsked = (b.id == askedId ? 1 : 0) - (a.id == askedId ? 1 : 0);
      return byAsked != 0 ? byAsked : a.code.compareTo(b.code);
    });
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    final inClasses = {for (final c in widget.member.classesNow) c.id};
    final shown = _visible(inClasses);
    return Column(
      key: const ValueKey('class-chooser'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Choose class'),
        TextField(
          onChanged: (v) => setState(() => _filter = v),
          decoration: const InputDecoration(
            labelText: 'Search classes',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        if (shown.isEmpty) const Text('No class to choose from.'),
        for (final c in shown)
          ListTile(
            key: ValueKey('class-${c.id}'),
            enabled: !inClasses.contains(c.id),
            selected: widget.selectedId == c.id,
            title: Text(c.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.code),
                if (inClasses.contains(c.id))
                  const Text('Already in this class'),
              ],
            ),
            trailing: widget.selectedId == c.id
                ? const Icon(Icons.check_circle, semanticLabel: 'Chosen')
                : null,
            onTap: () => widget.onSelect(c),
          ),
      ],
    );
  }
}
