# Context diagram

Target system, **mostly planned**. Only staff authentication/current-user/logout is implemented in Phase 1. Flutter and Laravel are inside the central system boundary; database tables do not appear here. No customer account or external inventory system is assumed.

```mermaid
flowchart LR
    C[Cashier]
    M[Manager]
    A[Administrator]
    S((Coffee Management System))
    P[Payment / KHQR provider - not selected]
    C -->|credentials; product selection; checkout/payment intent; own-history query; stock availability query| S
    S -->|auth result; menu; order/payment status; receipt; own history; stock availability| C
    M -->|credentials; cashier intents; catalog changes; stock adjustments; shop-history/report/settings queries| S
    S -->|auth result; POS results; catalog/stock outcomes; shop history; reports; operational settings| M
    A -->|credentials; manager intents; staff/role changes; store settings changes| S
    S -->|auth result; POS/management results; staff/settings outcomes; reports| A
    S -->|payment initiation; authenticated verification/reconciliation query| P
    P -->|QR/correlation/expiry; notification; verified settlement/status| S
```

Role permissions constrain the exchanges; arrows do not grant permission. Customer payment through the provider's own app is an external event outside this staff application's boundary, represented by provider status/notification. Manager/admin can also act as cashier. The same exchanges are balanced in [DFD level 1](dfd-level-1.md). Provider arrows describe future contracts only; no external service is contacted by this milestone.
