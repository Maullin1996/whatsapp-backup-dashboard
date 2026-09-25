import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_field_hints.dart';

/// Máximo de dígitos del total: evita desbordar el `int` al parsear.
const int _maxTotalDigits = 12;

/// Tarjeta editable de un comprobante (código, números y total).
class ComprobanteCard extends ConsumerStatefulWidget {
  final String messageId;

  /// Posición 1-based que ve el usuario ("Comprobante N").
  final int number;
  final ComprobanteDraft draft;
  final bool showErrors;
  final bool canRemove;

  const ComprobanteCard({
    super.key,
    required this.messageId,
    required this.number,
    required this.draft,
    required this.showErrors,
    required this.canRemove,
  });

  @override
  ConsumerState<ComprobanteCard> createState() => _ComprobanteCardState();
}

class _ComprobanteCardState extends ConsumerState<ComprobanteCard> {
  late final TextEditingController _codigo;
  late final TextEditingController _total;
  late final TextEditingController _numero;
  final FocusNode _numeroFocus = FocusNode();

  ReviewDraftNotifier get _notifier =>
      ref.read(reviewDraftProvider(widget.messageId).notifier);

  @override
  void initState() {
    super.initState();
    _codigo = TextEditingController(text: widget.draft.codigo);
    _total = TextEditingController(text: widget.draft.total);
    _numero = TextEditingController(text: widget.draft.numeroPendiente);
  }

  @override
  void didUpdateWidget(ComprobanteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al agregar el número (Enter, "+" o al guardar) el borrador limpia el
    // pendiente y el campo debe vaciarse.
    if (widget.draft.numeroPendiente.isEmpty && _numero.text.isNotEmpty) {
      _numero.clear();
    }
  }

  @override
  void dispose() {
    _codigo.dispose();
    _total.dispose();
    _numero.dispose();
    _numeroFocus.dispose();
    super.dispose();
  }

  String? get _codigoError => widget.showErrors && _isBlank(widget.draft.codigo)
      ? ReviewFieldHints.required
      : null;

  String? get _numerosError =>
      widget.showErrors &&
          widget.draft.numeros.isEmpty &&
          _isBlank(widget.draft.numeroPendiente)
      ? ReviewFieldHints.numbersRequired
      : null;

  String? get _totalError {
    if (!widget.showErrors) return null;
    if (widget.draft.total.isEmpty) return ReviewFieldHints.required;
    if (widget.draft.totalValue <= 0) return ReviewFieldHints.totalPositive;
    return null;
  }

  static bool _isBlank(String value) => value.trim().isEmpty;

  void _addNumero() {
    _notifier.addNumero(widget.draft.id);
    _numeroFocus.requestFocus(); // permite seguir agregando con Enter
  }

  Future<void> _confirmRemove() async {
    if (widget.draft.hasData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Quitar comprobante?'),
          content: const Text(
            'Se perderán los datos ingresados en este comprobante.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorMessage,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _notifier.removeComprobante(widget.draft.id);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.draft.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Comprobante ${widget.number}',
                    style: AppTypography.headerTitle(context),
                  ),
                ),
                IconButton(
                  key: ValueKey('quitar-$id'),
                  tooltip: widget.canRemove
                      ? 'Quitar comprobante'
                      : 'Debe haber al menos un comprobante',
                  onPressed: widget.canRemove ? _confirmRemove : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: ValueKey('codigo-$id'),
              controller: _codigo,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Código',
                errorText: _codigoError,
              ),
              onChanged: (value) => _notifier.setCodigo(id, value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: ValueKey('numero-$id'),
              controller: _numero,
              focusNode: _numeroFocus,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Número',
                errorText: _numerosError,
                suffixIcon: IconButton(
                  key: ValueKey('agregar-numero-$id'),
                  tooltip: 'Agregar número',
                  onPressed: _addNumero,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              onChanged: (value) => _notifier.setNumeroPendiente(id, value),
              onSubmitted: (_) => _addNumero(),
            ),
            if (widget.draft.numeros.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < widget.draft.numeros.length; i++)
                    InputChip(
                      key: ValueKey('chip-$id-$i'),
                      label: Text(widget.draft.numeros[i]),
                      deleteButtonTooltipMessage: 'Quitar número',
                      onDeleted: () => _notifier.removeNumero(id, i),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: ValueKey('total-$id'),
              controller: _total,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_maxTotalDigits),
              ],
              decoration: InputDecoration(
                labelText: 'Total',
                prefixText: '\$ ',
                errorText: _totalError,
              ),
              onChanged: (value) => _notifier.setTotal(id, value),
            ),
          ],
        ),
      ),
    );
  }
}
