import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/theme/formatters.dart';
import '../../../shared/widgets/status_badge.dart';
import '../domain/order.dart';
import '../domain/payment.dart';
import 'checkout_controller.dart';

/// Scrollable active-order view. No widget performs a financial request directly.
class CheckoutPanel extends StatefulWidget {
  const CheckoutPanel({super.key, required this.controller, this.onClose});
  final CheckoutController controller;
  final VoidCallback? onClose;
  @override
  State<CheckoutPanel> createState() => _CheckoutPanelState();
}

class _CheckoutPanelState extends State<CheckoutPanel> {
  late final TextEditingController _tender;
  @override
  void initState() {
    super.initState();
    _tender = TextEditingController(text: widget.controller.cashInput);
    widget.controller.addListener(_syncTender);
  }

  void _syncTender() {
    final text = widget.controller.cashInput;
    if (_tender.text == text) return;
    _tender.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void didUpdateWidget(covariant CheckoutPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncTender);
      widget.controller.addListener(_syncTender);
      _syncTender();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTender);
    _tender.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this pending order?'),
        content: const Text(
          'The server will cancel the unpaid order and release any reserved stock. This does not refund a payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.controller.cancel();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final state = controller.state;
      final order = state.order;
      final payment = state.payment;
      final colors = Theme.of(context).colorScheme;
      final paid = state.phase == CheckoutPhase.paid;
      final heading = switch (state.phase) {
        CheckoutPhase.paid => 'Payment successful',
        CheckoutPhase.cancelled => 'Order cancelled',
        CheckoutPhase.expired => 'Order expired',
        CheckoutPhase.review => 'Payment requires review',
        CheckoutPhase.cashEntry => 'Cash payment',
        CheckoutPhase.submitting => _operationLabel(state.operation),
        CheckoutPhase.verifyingOrder => 'Verifying order…',
        CheckoutPhase.requestUncertain => 'Request outcome uncertain',
        CheckoutPhase.refreshRequired => 'Review order',
        _ => 'Pending Order',
      };
      return Theme(
        data: Theme.of(context).copyWith(visualDensity: VisualDensity.standard),
        child: FilledButtonTheme(
          data: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(
                AppSpacing.minTouchTarget,
                AppSpacing.minTouchTarget,
              ),
            ),
          ),
          child: Material(
            color: colors.surface,
            child: ListView(
              padding: AppSpacing.edgeInsetsLg,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      liveRegion: true,
                      header: true,
                      child: Text(
                        heading,
                        style: AppTypography.h3.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        tooltip: 'Close order panel',
                        onPressed: widget.onClose,
                        constraints: const BoxConstraints(
                          minWidth: AppSpacing.minTouchTarget,
                          minHeight: AppSpacing.minTouchTarget,
                        ),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                AppSpacing.gapVerticalLg,
                if (state.busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Request in progress',
                  ),
                if (state.failure != null)
                  Padding(
                    padding: AppSpacing.edgeInsetsSm,
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        state.failure!.message,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
                if (controller.coolingDown)
                  Text(
                    'Retry available after ${state.retryAt!.toUtc().toIso8601String()}',
                  ),
                if (state.phase == CheckoutPhase.requestUncertain ||
                    state.retryOperation != null) ...[
                  const Text(
                    'Do not collect another payment or create another order while this request is unresolved.',
                  ),
                  if (controller.retainedTenderMinor != null)
                    Text(
                      'Original cash received: ${Formatters.formatCents(controller.retainedTenderMinor!)} USD',
                    ),
                  AppSpacing.gapVerticalSm,
                  OutlinedButton(
                    onPressed: state.busy || controller.coolingDown
                        ? null
                        : controller.retrySameRequest,
                    child: Text(
                      state.retryOperation == CheckoutOperation.checkout
                          ? 'Retry checkout'
                          : state.retryOperation == CheckoutOperation.cancel
                          ? 'Retry cancellation'
                          : state.retryOperation == CheckoutOperation.reconcile
                          ? 'Retry verification'
                          : 'Retry same payment request',
                    ),
                  ),
                ],
                if (order == null) ...[
                  AppSpacing.gapVerticalMd,
                  Text('Order preview · USD'),
                  Text(
                    Formatters.formatCents(
                      controller.previewTotalMinor ??
                          controller.cart.totalMinor,
                    ),
                    style: AppTypography.price.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  for (final line in controller.cart.lines)
                    Text('${line.quantity} × ${line.product.name}'),
                ],
                if (order != null) ...[
                  Semantics(
                    label: 'Order reference ${order.reference}',
                    excludeSemantics: true,
                    child: SelectableText(
                      order.reference,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  AppSpacing.gapVerticalSm,
                  Text(paid ? 'Paid total · USD' : 'Order total · USD'),
                  Text(
                    Formatters.formatCents(order.totalMinor),
                    style: AppTypography.priceLarge.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  if (controller.previewTotalMinor != null &&
                      controller.previewTotalMinor != order.totalMinor)
                    const Text(
                      'Prices changed during checkout. This is the server-confirmed total.',
                    ),
                  AppSpacing.gapVerticalMd,
                  StatusBadge(
                    label: _orderLabel(order.status),
                    variant: paid
                        ? StatusBadgeVariant.success
                        : StatusBadgeVariant.warning,
                  ),
                  if (state.phase == CheckoutPhase.review) ...[
                    AppSpacing.gapVerticalMd,
                    const Text(
                      'Do not retry or collect another payment until this transaction is checked. Contact your manager.',
                    ),
                  ],
                  if (payment != null && !paid) ...[
                    AppSpacing.gapVerticalLg,
                    Text(
                      '${payment.method == PaymentMethod.external ? 'External' : 'Cash'} payment',
                    ),
                    StatusBadge(
                      label: _paymentLabel(payment.status),
                      variant: payment.reconciliationRequired
                          ? StatusBadgeVariant.warning
                          : StatusBadgeVariant.information,
                    ),
                    AppSpacing.gapVerticalSm,
                    Text(_paymentGuidance(payment.status)),
                    if (controller.displayPayload != null) ...[
                      AppSpacing.gapVerticalMd,
                      const Text('Payment information'),
                      SelectableText(controller.displayPayload!),
                      const Text(
                        'Displaying payment information does not mean the order is paid.',
                      ),
                    ] else if (payment.status == PaymentStatus.pending &&
                        payment.expiresAt != null &&
                        !controller.now.isBefore(payment.expiresAt!))
                      const Text(
                        'Payment display expired. Check the payment status.',
                      ),
                    if (controller.canCheckPayment)
                      OutlinedButton(
                        onPressed: controller.checkPayment,
                        child: const Text('Check payment status'),
                      ),
                  ],
                  if (state.phase == CheckoutPhase.cashEntry) ...[
                    AppSpacing.gapVerticalLg,
                    TextField(
                      controller: _tender,
                      enabled: controller.canChoosePayment,
                      onChanged: controller.setCashInput,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [LengthLimitingTextInputFormatter(16)],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (controller.enteredTenderMinor != null &&
                            controller.cashInputError == null &&
                            controller.canChoosePayment) {
                          controller.cash(controller.enteredTenderMinor!);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Cash received in USD',
                        prefixText: '\$ ',
                        helperText: 'Dollars, for example 10.50',
                        helperMaxLines: 3,
                        errorMaxLines: 4,
                        errorText: controller.cashInputError,
                      ),
                    ),
                    AppSpacing.gapVerticalSm,
                    OutlinedButton(
                      onPressed: controller.canChoosePayment
                          ? () {
                              controller.useExactTender();
                              _tender.text = controller.cashInput;
                            }
                          : null,
                      child: const Text('Exact amount'),
                    ),
                    if (controller.enteredTenderMinor != null &&
                        controller.enteredTenderMinor! >= order.totalMinor) ...[
                      AppSpacing.gapVerticalSm,
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Change preview: ${Formatters.formatCents(controller.enteredTenderMinor! - order.totalMinor)} USD',
                        ),
                      ),
                    ],
                    AppSpacing.gapVerticalMd,
                    FilledButton(
                      onPressed:
                          controller.canChoosePayment &&
                              controller.enteredTenderMinor != null &&
                              controller.cashInputError == null
                          ? () =>
                                controller.cash(controller.enteredTenderMinor!)
                          : null,
                      child: const Text('Confirm cash payment'),
                    ),
                    TextButton(
                      onPressed: controller.canChoosePayment
                          ? controller.chooseMethods
                          : null,
                      child: const Text('Payment methods'),
                    ),
                  ] else if (controller.canChoosePayment) ...[
                    AppSpacing.gapVerticalLg,
                    FilledButton(
                      onPressed: controller.chooseCash,
                      child: const Text('Cash'),
                    ),
                    AppSpacing.gapVerticalSm,
                    OutlinedButton(
                      onPressed: controller.external,
                      child: const Text('External payment'),
                    ),
                  ],
                  if (paid) ...[
                    AppSpacing.gapVerticalMd,
                    Text(
                      'Paid by ${order.acceptedPayment!.method == PaymentMethod.cash ? 'Cash' : 'External payment'}',
                    ),
                    if (order.acceptedPayment!.method ==
                        PaymentMethod.cash) ...[
                      Text(
                        'Cash received: ${Formatters.formatCents(order.acceptedPayment!.tenderMinor!)} USD',
                      ),
                      Text(
                        'Change: ${Formatters.formatCents(order.acceptedPayment!.changeMinor!)} USD',
                      ),
                    ],
                    Text('Paid at ${order.paidAt!.toUtc().toIso8601String()}'),
                  ],
                  AppSpacing.gapVerticalLg,
                  Text(
                    '${order.itemCount} items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.quantity} × ${item.productName}'),
                          Text(
                            '${Formatters.formatCents(item.unitPriceMinor)} each · ${Formatters.formatCents(item.lineTotalMinor)} USD',
                          ),
                        ],
                      ),
                    ),
                  AppSpacing.gapVerticalLg,
                  if (controller.hasMoreAttempts) ...[
                    const Text(
                      'Review the remaining attempts before starting another payment.',
                    ),
                    OutlinedButton(
                      onPressed: controller.canLoadMoreAttempts
                          ? controller.loadMoreAttempts
                          : null,
                      child: const Text('Load more attempts'),
                    ),
                  ],
                  if (!state.busy &&
                      !controller.coolingDown &&
                      !controller.canStartNewOrder)
                    OutlinedButton(
                      onPressed: controller.refreshOrder,
                      child: const Text('Refresh order'),
                    ),
                  if (controller.canCancel)
                    TextButton(
                      onPressed: _cancel,
                      child: const Text('Cancel pending order'),
                    ),
                  if (controller.canStartNewOrder)
                    FilledButton(
                      onPressed: controller.newOrder,
                      child: const Text('New Order'),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  String _operationLabel(CheckoutOperation? operation) => switch (operation) {
    CheckoutOperation.checkout => 'Creating order…',
    CheckoutOperation.cash => 'Settling cash…',
    CheckoutOperation.external => 'Starting external payment…',
    CheckoutOperation.cancel => 'Cancelling order…',
    CheckoutOperation.reconcile => 'Checking payment status…',
    null => 'Working…',
  };
  String _orderLabel(OrderStatus status) => switch (status) {
    OrderStatus.pendingPayment => 'Pending payment',
    OrderStatus.paid => 'Paid',
    OrderStatus.cancelled => 'Cancelled',
    OrderStatus.expired => 'Expired',
  };
  String _paymentLabel(PaymentStatus status) => switch (status) {
    PaymentStatus.initiated => 'Initiated',
    PaymentStatus.pending => 'Pending',
    PaymentStatus.confirmed => 'Confirmed',
    PaymentStatus.failed => 'Failed',
    PaymentStatus.expired => 'Expired',
    PaymentStatus.uncertain => 'Uncertain',
  };
  String _paymentGuidance(PaymentStatus status) => switch (status) {
    PaymentStatus.initiated =>
      'The attempt exists. Check its status before taking another payment.',
    PaymentStatus.pending => 'Waiting for trusted payment verification.',
    PaymentStatus.confirmed =>
      'Payment is confirmed. Refresh the order to verify settlement.',
    PaymentStatus.failed =>
      'The backend reports this attempt failed. Check the order before choosing another payment.',
    PaymentStatus.expired =>
      'The backend reports this attempt expired. Its display data is hidden.',
    PaymentStatus.uncertain =>
      'The payment outcome is unknown. Check the existing attempt before taking another payment.',
  };
}
