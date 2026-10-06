# DFD level 1

Target logical decomposition. Data stores are conceptual groups, not new databases/services. P1 has implemented backend foundations; P2 Category/Product management and reads are implemented. P3 checkout/history and P4 cash settlement/payment records are implemented, with provider-neutral external verification tested using a fake. Real provider traffic/callbacks, receipt printing, P6-P7 remain planned; Phase 5 implements recipes and gated inventory/reservation/consumption/manual release. Provider exchanges below describe the target boundary; the production adapter is unconfigured. Requests to protected processes carry identity established by P1; every process still authorizes its action/object.

```mermaid
flowchart TB
    C[Cashier]
    M[Manager]
    A[Administrator]
    E[Payment / KHQR provider]
    P1((1. Authentication and access))
    P2((2. Catalog management))
    P3((3. POS and orders))
    P4((4. Payments))
    P5((5. Inventory))
    P6((6. Users and settings))
    P7((7. Reports))
    D1[(D1 Users / roles / tokens / audit)]
    D2[(D2 Catalog / recipes)]
    D3[(D3 Orders / items)]
    D4[(D4 Payment attempts)]
    D5[(D5 Inventory / reservations / movements)]
    D6[(D6 Store settings)]
    C -->|credentials; token; logout| P1
    M -->|credentials; token; logout| P1
    A -->|credentials; token; logout| P1
    P1 -->|auth result / current identity| C
    P1 -->|auth result / current identity| M
    P1 -->|auth result / current identity| A
    D1 -->|identity; status; role; token hash| P1
    P1 -->|issued / revoked tokens| D1
    C -->|menu search| P2
    M -->|menu search; catalog changes| P2
    A -->|menu search; catalog changes| P2
    D2 -->|categories / products| P2
    P2 -->|validated catalog changes| D2
    P2 -->|menu| C
    P2 -->|menu / catalog outcome| M
    P2 -->|menu / catalog outcome| A
    C -->|checkout intent; own-history query| P3
    M -->|checkout intent; shop-history query| P3
    A -->|checkout intent; shop-history query| P3
    D2 -->|authoritative products / recipe| P3
    D6 -->|approved currency / pricing rules| P3
    D3 -->|order snapshots / state| P3
    P3 -->|orders / item snapshots / transition| D3
    P3 -->|order result; receipt; own history| C
    P3 -->|order result; receipt; shop history| M
    P3 -->|order result; receipt; shop history| A
    C -->|authorized order / payment method| P4
    M -->|authorized order / payment method| P4
    A -->|authorized order / payment method| P4
    P3 -->|pending order / expected totals| P4
    P4 -->|verified settlement / receipt data| P3
    D4 -->|attempt / identity / recovery state| P4
    P4 -->|attempt / verified result| D4
    P4 -->|payment initiation / verification query| E
    E -->|QR / expiry / notification / settlement status| P4
    P4 -->|payment display / status| C
    P4 -->|payment display / status| M
    P4 -->|payment display / status| A
    P3 -->|reservation / consumption / release intent| P5
    P5 -->|availability / stock result| P3
    C -->|stock availability query| P5
    M -->|stock query / adjustment| P5
    A -->|stock query / adjustment| P5
    D5 -->|balance / reservations / ledger| P5
    P5 -->|stock reservation / movement / balance| D5
    P5 -->|adjustment actor / reason / audit| D1
    P5 -->|stock availability| C
    P5 -->|stock outcome / low-stock data| M
    P5 -->|stock outcome / low-stock data| A
    M -->|settings query| P6
    A -->|staff / role / settings changes| P6
    D1 -->|staff / role data| P6
    P6 -->|authorized staff / role change / audit| D1
    D6 -->|approved settings| P6
    P6 -->|validated settings| D6
    P6 -->|operational settings| M
    P6 -->|staff / settings result| A
    M -->|bounded report query| P7
    A -->|bounded report query| P7
    D3 -->|paid orders / snapshots| P7
    D4 -->|verified payments / exceptions| P7
    D5 -->|stock balances / ledger| P7
    D6 -->|business timezone| P7
    P7 -->|authorized report| M
    P7 -->|authorized report| A
```

All actor/provider exchanges from the context appear at this level. Manager/admin POS exchanges reflect their cashier capability; cashier has no settings/report/staff-management flow. Tokens are infrastructure grouped with identity. Manual stock adjustments now retain actor/reason in their append-only ledger; administrative audit remains planned; financial history is its own authoritative record. DFD relationships do not imply separate network deployments or independent transactions.
