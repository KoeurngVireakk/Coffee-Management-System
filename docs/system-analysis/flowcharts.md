# Workflow flowcharts

Authentication below reflects implemented backend behavior. Unpaid cart validation/calculation/order creation is implemented in Phase 3; Cash/payment attempt/verified acceptance branches now have Phase 4 implementations, with fake-only provider evidence. Phase 5 implements gated stock reservation, shared consumption and manual release. Real KHQR and receipt-printing branches remain proposed; no automatic expiry. No Flutter screens are implemented here.

## Staff authentication

```mermaid
flowchart TD
    A([Start]) --> B[Submit email / password / device_name]
    B --> C{IP and identity/IP rate limit?}
    C -->|Exceeded| X[429 JSON with Retry-After]
    C -->|Allowed| D{Validate bounded allow-listed request}
    D -->|Invalid / privilege fields| Y[422 JSON errors]
    D -->|Valid| E[Lookup normalized email / verify password hash]
    E --> F{Credentials correct?}
    F -->|No| Z[401 generic credential failure]
    F -->|Yes| G{Active account / recognized assigned role?}
    G -->|No| Z
    G -->|Yes| H[Rehash if needed / issue eight-hour Sanctum token]
    H --> I[Resource: identity / current role / permission hints]
    I --> J[200 token returned once / no-store]
    J --> K[Protected request with Bearer token]
    K --> L{Token valid and unexpired?}
    L -->|No| U[401 JSON]
    L -->|Yes| M{Account active / role recognized now?}
    M -->|No| V[403 JSON]
    M -->|Yes| N{Action / object permitted?}
    N -->|No| V
    N -->|Yes| O[Return authorized result]
    O --> P[Logout request revokes calling token]
    P --> Q([204 / end])
```

Malformed login attempts also count against the IP/identity limits. Successful login does not reset them. Current-user retrieves only the caller; logout does not revoke other device tokens. An inactive account cannot use protected APIs even if a previously issued token still exists.

## POS checkout and gated stock completion

```mermaid
flowchart TD
    A([Start]) --> B[Browse active menu / select products]
    B --> C[Set positive quantities / approved options only]
    C --> D[Add to client cart]
    D --> E[Submit selection and checkout replay key]
    E --> F{Authenticate / authorize / validate intent}
    F -->|Denied / invalid| X[Return error; keep cart for correction]
    F -->|Valid| G{Existing checkout key?}
    G -->|Same payload| R[Return original order/status]
    G -->|Different payload| Y[409 conflict]
    G -->|New| H[Reload active products / calculate exact snapshots]
    H --> I{Tracking enabled / enough stock?}
    I -->|Insufficient / invalid| X
    I -->|Sufficient or explicitly disabled| J[Atomic pending order + items + optional stock reservations]
    J --> K[Select payment / persist attempt]
    K --> L{Cash or external?}
    L -->|Cash| M[Validate exact tender / calculate change]
    L -->|External| N[Initiate provider outside locks / show QR]
    M --> O{Verified full settlement?}
    N --> P[Server verification / reconcile uncertainty]
    P --> O
    O -->|Pending / uncertain| R
    O -->|Verified no payment / authorized manual cancellation| S[Release reservation once / cancel order]
    O -->|Confirmed| T[Atomic payment + paid order + stock consumption / ledger]
    T --> U{Local commit succeeded?}
    U -->|No| V[Retry local transition / reconcile external funds]
    U -->|Yes| W[Return persisted order/payment summary]
    W --> Z([Complete])
```

No paid-order editing, split payments or refunds are implied. Options require a future approved model. Failed local checkout leaves no partial order/stock state. External funds already received are reconciled if local completion cannot commit.

## Generic payment / KHQR (planned)

```mermaid
flowchart TD
    A[Pending authorized order] --> B[Persist expected amount/currency/merchant/correlation]
    B --> C[Call selected provider outside transaction]
    C --> D{Provider initiation reply?}
    D -->|Timeout / crash| U[Persist uncertain; bounded recovery verification]
    D -->|Valid QR| E[Persist pending QR / expiry]
    E --> F[QR displayed - still unpaid]
    F --> G[Customer payment attempt in provider app]
    G --> H[Provider notification or backend status query]
    H --> I[Authenticate callback per contract / fetch trusted status]
    U --> I
    I --> J{Verified matching identity/merchant/amount/currency?}
    J -->|No / ambiguous| K[Keep pending or quarantine mismatch; no paid state]
    J -->|Yes| L{Already applied transaction?}
    L -->|Same result| M[Idempotent acknowledgment / existing status]
    L -->|New| N[Lock order/attempt; ensure unsettled and valid reservation]
    N --> O{Safe completion?}
    O -->|Second settlement / cancelled / stock released| P[Record settlement exception; manual reconciliation]
    O -->|Yes| Q[Atomic unique transaction + confirmed payment + paid order + stock ledger]
    Q --> R[Confirmed backend payment / persisted receipt]
```

Signatures, status names, polling intervals and expiry semantics come from the eventual provider contract. QR hashes are correlation values, not proof or authentication. Failed/expired results require verified no-settlement before releasing stock. Provider-neutral verification/manual recovery are fake-tested; real network verification and durable recovery workers remain unimplemented.

## Safe manual cancellation (Phase 5)

```mermaid
flowchart TD
    A[Authorized own or shop pending order] --> B[Lock order then payment state]
    B --> C{Paid or active unresolved review payment?}
    C -->|Yes| D[409 preserve order and reservations]
    C -->|No| E{Already cancelled?}
    E -->|Yes| F[200 original cancelled order]
    E -->|No| G[Lock tracked inventory IDs ascending]
    G --> H[Release reserved snapshots; on_hand unchanged]
    H --> I[Atomically mark cancelled]
    I --> F
```

No automatic reservation timeout is implied. A late trusted provider success records funds/review without paying the cancelled order or consuming released stock.
