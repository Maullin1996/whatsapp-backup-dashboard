import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/thousands_input_formatter.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_field_hints.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_section_card.dart';

/// Tarjeta editable de un comprobante, en una columna: números, total y
/// lotería (opcional). El Sumador no anota números: su tarjeta solo tiene
/// total y lotería. El código no va aquí: es uno por imagen, arriba de las
/// tarjetas.
class ComprobanteCard extends ConsumerStatefulWidget {
  /// Imagen y rol del borrador al que pertenece.
  final ReviewKey reviewKey;

  /// Posición 1-based que ve el usuario (círculo de la cabecera).
  final int number;
  final ComprobanteDraft draft;
  final bool showErrors;
  final bool canRemove;

  /// true si la tarjeta acaba de agregarse: al crearse hace scroll hasta ella
  /// y enfoca su primer campo (números del Revisor, total del Sumador). Solo
  /// se lee al crear el estado.
  final bool focusOnCreate;

  const ComprobanteCard({
    super.key,
    required this.reviewKey,
    required this.number,
    required this.draft,
    required this.showErrors,
    required this.canRemove,
    this.focusOnCreate = false,
  });

  @override
  ConsumerState<ComprobanteCard> createState() => _ComprobanteCardState();
}

class _ComprobanteCardState extends ConsumerState<ComprobanteCard> {
  late final TextEditingController _total;
  late final TextEditingController _numero;
  late final TextEditingController _loteria;
  final FocusNode _totalFocus = FocusNode();
  late final FocusNode _numeroFocus = FocusNode(onKeyEvent: _onNumeroKey);

  ReviewDraftNotifier get _notifier =>
      ref.read(reviewDraftProvider(widget.reviewKey).notifier);

  @override
  void initState() {
    super.initState();
    _total = TextEditingController(text: formatThousands(widget.draft.total));
    _numero = TextEditingController(text: widget.draft.numeroPendiente);
    _loteria = TextEditingController(text: widget.draft.loteria);
    if (widget.focusOnCreate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(context, duration: AppDurations.quick);
        (_showNumeros ? _numeroFocus : _totalFocus).requestFocus();
      });
    }
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
    _total.dispose();
    _numero.dispose();
    _loteria.dispose();
    _totalFocus.dispose();
    _numeroFocus.dispose();
    super.dispose();
  }

  bool get _showNumeros => widget.reviewKey.rol == ReviewRole.revisor;

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

  /// Patrón de campo de chips: Backspace con el input vacío quita el último
  /// número. Con texto, Backspace borra caracteres como siempre.
  KeyEventResult _onNumeroKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace ||
        _numero.text.isNotEmpty ||
        widget.draft.numeros.isEmpty) {
      return KeyEventResult.ignored;
    }
    _notifier.removeNumero(widget.draft.id, widget.draft.numeros.length - 1);
    return KeyEventResult.handled;
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
    final numeros = widget.draft.numeros;
    final showNumeros = _showNumeros;

    return ReviewSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ComprobanteHeader(
            number: widget.number,
            trailing: IconButton(
              key: ValueKey('quitar-$id'),
              color: Colors.grey.shade600,
              tooltip: widget.canRemove
                  ? 'Quitar comprobante'
                  : 'Debe haber al menos un comprobante',
              onPressed: widget.canRemove ? _confirmRemove : null,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
          if (showNumeros) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: ValueKey('numero-$id'),
              controller: _numero,
              focusNode: _numeroFocus,
              textInputAction: TextInputAction.done,
              style: AppTypography.tabular,
              decoration: InputDecoration(
                labelText: numeros.isEmpty
                    ? 'Números'
                    : 'Números · ${numeros.length}',
                errorText: _numerosError,
                // Tab va de Números a Total; se agrega con Enter.
                suffixIcon: ExcludeFocus(
                  child: IconButton(
                    key: ValueKey('agregar-numero-$id'),
                    tooltip: 'Agregar número',
                    onPressed: _addNumero,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ),
              onChanged: (value) => _notifier.setNumeroPendiente(id, value),
              onSubmitted: (_) => _addNumero(),
            ),
            if (numeros.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ExcludeFocus(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (var i = 0; i < numeros.length; i++)
                      InputChip(
                        key: ValueKey('chip-$id-$i'),
                        label: Text(numeros[i], style: AppTypography.tabular),
                        deleteButtonTooltipMessage: 'Quitar número',
                        onDeleted: () => _notifier.removeNumero(id, i),
                      ),
                  ],
                ),
              ),
            ],
          ],
          SizedBox(height: showNumeros ? AppSpacing.md : AppSpacing.sm),
          TextField(
            key: ValueKey('total-$id'),
            controller: _total,
            focusNode: _totalFocus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            style: AppTypography.tabular.copyWith(fontWeight: FontWeight.bold),
            inputFormatters: const [ThousandsInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Total',
              prefixText: '\$ ',
              errorText: _totalError,
            ),
            // El controller muestra "9.000"; el borrador guarda "9000".
            onChanged: (value) => _notifier.setTotal(id, onlyDigits(value)),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: ValueKey('loteria-$id'),
            controller: _loteria,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Lotería (opcional)'),
            onChanged: (value) => _notifier.setLoteria(id, value),
          ),
        ],
      ),
    );
  }
}
