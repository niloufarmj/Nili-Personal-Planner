import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../repositories/item_repository.dart';
import '../templates/template_registry.dart';

/// Bottom sheet for creating or editing an item.
/// All fields are driven by [TemplateDef] — no per-template form code.
class ItemEditSheet extends ConsumerStatefulWidget {
  const ItemEditSheet({
    required this.collection,
    required this.template,
    this.item,
    super.key,
  });

  final Collection collection;
  final TemplateDef template;
  final Item? item; // null = create mode

  @override
  ConsumerState<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<ItemEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _description;
  late String _status;
  int? _priority;
  String? _dueDate;
  int? _plannedCostCents;
  final Map<String, TextEditingController> _metaControllers = {};

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _status = item?.status ?? widget.template.openStatus;
    _priority = item?.priority;
    _dueDate = item?.dueDate;
    _plannedCostCents = item?.plannedCostCents;

    for (final f in widget.template.metaFields) {
      final existing = (item?.meta != null)
          ? item!.meta![f.key] as String?
          : null;
      _metaControllers[f.key] = TextEditingController(text: existing ?? '');
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final c in _metaControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final template = widget.template;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Edit item' : 'New item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _title,
                autofocus: !_isEdit,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Description
              if (template.fields.description)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),

              // Status
              _StatusField(
                statuses: template.statuses,
                current: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 12),

              // Priority
              if (template.fields.priority)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PriorityField(
                    value: _priority,
                    onChanged: (v) => setState(() => _priority = v),
                  ),
                ),

              // Due date
              if (template.fields.dueDate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DateField(
                    label: 'Due date',
                    value: _dueDate,
                    onChanged: (v) => setState(() => _dueDate = v),
                  ),
                ),

              // Planned cost
              if (template.fields.plannedCost)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CostField(
                    valueCents: _plannedCostCents,
                    onChanged: (v) => setState(() => _plannedCostCents = v),
                  ),
                ),

              // Template meta fields
              ...template.metaFields.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MetaField(
                    def: f,
                    controller: _metaControllers[f.key]!,
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(_isEdit ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(itemRepositoryProvider);
    final meta = <String, dynamic>{};
    for (final f in widget.template.metaFields) {
      final v = _metaControllers[f.key]?.text.trim() ?? '';
      if (v.isNotEmpty) meta[f.key] = v;
    }

    if (_isEdit) {
      final updated = widget.item!.copyWith(
        title: _title.text.trim(),
        description: Value(
          _description.text.trim().isEmpty ? null : _description.text.trim(),
        ),
        status: _status,
        priority: Value(_priority),
        dueDate: Value(_dueDate),
        plannedCostCents: Value(_plannedCostCents),
        meta: Value(meta.isEmpty ? null : meta),
      );
      await repo.updateItem(updated);
    } else {
      await repo.createItem(
        ItemsCompanion.insert(
          collectionId: widget.collection.id,
          title: _title.text.trim(),
          description: Value(
            _description.text.trim().isEmpty ? null : _description.text.trim(),
          ),
          status: Value(_status),
          priority: Value(_priority),
          dueDate: Value(_dueDate),
          plannedCostCents: Value(_plannedCostCents),
          meta: Value(meta.isEmpty ? null : meta),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }
}

// ── Field sub-widgets ─────────────────────────────────────────────────────────

class _StatusField extends StatelessWidget {
  const _StatusField({
    required this.statuses,
    required this.current,
    required this.onChanged,
  });

  final List<StatusDef> statuses;
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: current,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: statuses
          .map((s) => DropdownMenuItem(value: s.value, child: Text(s.label)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _PriorityField extends StatelessWidget {
  const _PriorityField({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Priority',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('↑ High')),
        DropdownMenuItem(value: 2, child: Text('— Normal')),
        DropdownMenuItem(value: 3, child: Text('↓ Low')),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value != null
              ? DateTime.tryParse(value!) ?? DateTime.now()
              : DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) {
          onChanged(
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}',
          );
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value ?? 'Tap to pick'),
      ),
    );
  }
}

class _CostField extends ConsumerStatefulWidget {
  const _CostField({required this.valueCents, required this.onChanged});

  final int? valueCents;
  final ValueChanged<int?> onChanged;

  @override
  ConsumerState<_CostField> createState() => _CostFieldState();
}

class _CostFieldState extends ConsumerState<_CostField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.valueCents != null
          ? (widget.valueCents! / 100).toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      decoration: const InputDecoration(
        labelText: 'Planned cost (€)',
        border: OutlineInputBorder(),
        prefixText: '€ ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        widget.onChanged(parsed != null ? (parsed * 100).round() : null);
      },
    );
  }
}

class _MetaField extends StatelessWidget {
  const _MetaField({required this.def, required this.controller});

  final MetaFieldDef def;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    if (def.type == MetaFieldType.select && def.options != null) {
      return DropdownButtonFormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        decoration: InputDecoration(
          labelText: def.label,
          border: const OutlineInputBorder(),
        ),
        items: def.options!
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => controller.text = v ?? '',
      );
    }

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: def.label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: def.type == MetaFieldType.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : def.type == MetaFieldType.url
          ? TextInputType.url
          : TextInputType.text,
    );
  }
}
