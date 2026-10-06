# DFD level 2: POS order + checkout + payment

Phase 3 implements 3.1-3.5 unpaid order creation and 3.8 scoped history; Phase 5 activates P5 reservation calls only for new checkouts when the deployment gate is enabled; historical untracked orders stay untracked. Phase 4 implements cash and provider-neutral initiation/verification/accepted settlement with a test fake. Real provider/callback authenticity, paid receipt printing remain **proposed**. Phase 5 local inventory completion/manual cancellation are implemented. The diagram includes target real-provider/callback/receipt/expiry exchanges; local payment/stock transactions and manual cancellation are implemented. This decomposes the combined P3/P4 boundary from level 1; P5 remains the inventory collaborator. External inputs/outputs preserve checkout, payment selection, history, receipts and provider exchanges. P2 catalog browsing precedes cart submission and is not repeated here.

```mermaid
flowchart TB
    Staff[Authorized Cashier / Manager / Admin]
    Provider[Payment / KHQR provider]
    Catalog[(D2 Catalog / recipes)]
    Orders[(D3 Orders / items)]
    Payments[(D4 Payment attempts)]
    Settings[(D6 Store settings)]
    Inventory((5. Inventory))
    Q31((3.1 Receive selection / replay key))
    Q32((3.2 Load authoritative catalog))
    Q33((3.3 Validate products / quantities))
    Q34((3.4 Calculate exact totals))
    Q35((3.5 Persist pending order))
    Q41((4.1 Select method / persist attempt))
    Q42((4.2 Validate cash tender))
    Q43((4.3 Initiate external payment))
    Q44((4.4 Verify / reconcile provider result))
    Q45((4.5 Apply verified settlement once))
    Q36((3.6 Finalize / expire order))
    Q37((3.7 Return receipt / order result))
    Q38((3.8 Read authorized history))
    Staff -->|product IDs; quantities; checkout key| Q31
    Orders -->|existing replay / payload hash| Q31
    Q31 -->|new validated intent| Q32
    Catalog -->|product state / prices / recipe requirements| Q32
    Q32 -->|catalog snapshot candidate| Q33
    Settings -->|approved currency / pricing rules| Q34
    Q33 -->|authorized positive quantities / active products| Q34
    Q34 -->|totals / item snapshots / required stock| Q35
    Q35 -->|reserve requirements when tracking enabled| Inventory
    Inventory -->|availability / reservation outcome| Q35
    Q35 -->|pending order / items / replay hash| Orders
    Q35 -->|order ID / due / currency| Q41
    Staff -->|authorized order / method / tender or attempt key| Q41
    Orders -->|state / owner / expected totals| Q41
    Q41 -->|current attempt selection| Orders
    Q41 -->|attempt / expected amount / merchant| Payments
    Q41 -->|cash attempt / tender| Q42
    Q41 -->|external attempt / intent| Q43
    Q42 -->|validated cash settlement / change| Q45
    Q43 -->|initiation / idempotency key| Provider
    Provider -->|QR / correlation / expiry| Q43
    Q43 -->|pending / uncertain attempt| Payments
    Q43 -->|QR display data / pending status| Staff
    Provider -->|callback / notification| Q44
    Q44 -->|authenticated status / reconciliation query| Provider
    Provider -->|verified transaction / merchant / amount / currency| Q44
    Payments -->|expected identity / recovery state| Q44
    Q44 -->|verified outcome / replay identity| Q45
    Q45 -->|confirmed / failed / uncertain / exception record| Payments
    Q45 -->|settlement / verified expiry result| Q36
    Orders -->|current order / accepted attempt| Q36
    Q36 -->|consume or safely release reserved quantities| Inventory
    Inventory -->|stock movements / completion result| Q36
    Q36 -->|paid / expired / reconciliation state| Orders
    Q36 -->|persisted outcome| Q37
    Q31 -->|matching replayed order| Q37
    Q33 -->|validation / unavailable outcome| Q37
    Q37 -->|order status / error / final paid receipt| Staff
    Staff -->|own or authorized shop history query| Q38
    Orders -->|persisted snapshots / status| Q38
    Payments -->|accepted verified payment summary| Q38
    Q38 -->|bounded authorized history| Staff
```

## Integrity and failure interpretation

- 3.2-3.5 form one local checkout transaction; tracking off keeps the no-stock path. Shared locks cover product PKs ascending then their actual category PKs ascending; authoritative snapshots are persisted atomically. Tracking on aggregates current recipe requirements, locks inventory ascending and atomically snapshots/reserves. Catalog and stock are revalidated inside locks; any invalidity rolls back the order/reservation. The cart and client prechecks are not trusted.
- 4.1 persists attempt before external I/O; 4.3 never holds SQL locks during provider requests. Remote timeout/crash leaves a recoverable initiated/uncertain record. The QR is display data only.
- 4.4 authenticates according to the actual provider contract or treats callbacks as hints and verifies by server query. Match amount/currency/merchant/correlation/unique transaction before settlement.
- 4.5 + 3.6 now share one local acceptance/stock-consumption transaction for tracked orders; untracked orders have no stock effects. Same verified result is idempotent; second settlement/mismatch is quarantined for reconciliation. A provider success can require manual recovery if local commit fails.
- Safe manual cancellation releases reservations only after uncertainty is resolved; no automatic expiry is implemented. Late payment after release records funds plus reconciliation requirement without silently finalizing a cancelled order or overselling stock.
- History is read-only and scoped by actor/policy. Pending status returns no paid receipt. Bounded recovery scan/worker uses persisted attempts after restart; synchronous queues and client polling are insufficient crash recovery.

See [TRD](trd.md) for exact transaction/lock order and [business rules](business-rules.md) for proposed states. Tax/discount/options remain decision gates, not invented behaviors.
