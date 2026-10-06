# Conceptual / logical entity relationship diagram

Roles and staff identity were implemented in Phase 1; Category and Product are implemented in Phase 2. Order and OrderItem are implemented in Phase 3 for unpaid checkout. Phase 4 implements Payment attempts, order payment selection and immutable PaymentEvidence observations. Inventory/settings/audit remain **proposed**, derived from the requirements. This ERD expresses business relationships; [TRD](trd.md) defines physical types, FKs and indexes.

```mermaid
erDiagram
    ROLE o|--o{ USER : assigned_to
    USER ||--o{ ORDER : creates
    CATEGORY ||--o{ PRODUCT : groups
    PRODUCT ||--o{ ORDER_ITEM : historically_references
    ORDER ||--|{ ORDER_ITEM : contains
    ORDER ||--o{ PAYMENT : attempts
    USER o|--o{ PAYMENT : initiates
    PAYMENT ||--o{ PAYMENT_EVIDENCE : retains_verified_observations
    ORDER o|--o| PAYMENT : accepts_settlement
    ORDER o|--o| PAYMENT : current_attempt
    PRODUCT ||--o{ RECIPE_COMPONENT : requires
    INVENTORY_ITEM ||--o{ RECIPE_COMPONENT : ingredient_of
    ORDER ||--o{ STOCK_RESERVATION : reserves
    INVENTORY_ITEM ||--o{ STOCK_RESERVATION : reserved_for
    INVENTORY_ITEM ||--o{ STOCK_MOVEMENT : has_ledger
    USER o|--o{ STOCK_MOVEMENT : records
    ORDER o|--o{ STOCK_MOVEMENT : causes
    USER o|--o{ SETTING : last_updates
    USER o|--o{ AUDIT_EVENT : performs
    ROLE {
        identifier id PK
        name approved_role
        text label
    }
    USER {
        identifier id PK
        identifier role_id FK
        text name
        text unique_email
        secret password_hash
        boolean active
    }
    CATEGORY {
        identifier id PK
        text name
        boolean active
    }
    PRODUCT {
        identifier id PK
        identifier category_id FK
        text unique_sku
        text name
        money price
        currency currency
        boolean active
    }
    ORDER {
        identifier id PK
        reference public_reference
        identifier creator_id FK
        state status
        money subtotal_discount_tax_total
        currency currency_snapshot
        key checkout_key
    }
    ORDER_ITEM {
        identifier id PK
        identifier order_id FK
        identifier product_id FK
        text name_sku_snapshot
        money unit_price_snapshot
        integer quantity
        money line_totals_snapshot
    }
    PAYMENT {
        identifier id PK
        identifier order_id FK
        method cash_or_external
        state status
        money expected_amount
        currency expected_currency
        reference provider_transaction
    }
    PAYMENT_EVIDENCE {
        identifier id PK
        identifier payment_id FK
        reference unique_provider_transaction
        reference observed_order_correlation_merchant
        money actual_amount
        currency actual_currency
        time verified_at
    }
    INVENTORY_ITEM {
        identifier id PK
        text name
        unit base_unit
        decimal on_hand_reserved_threshold
        boolean active
    }
    RECIPE_COMPONENT {
        identifier product_id PK,FK
        identifier inventory_item_id PK,FK
        decimal required_quantity
    }
    STOCK_RESERVATION {
        identifier order_id PK,FK
        identifier inventory_item_id PK,FK
        decimal requirement_snapshot
        state reserved_consumed_released
    }
    STOCK_MOVEMENT {
        identifier id PK
        identifier inventory_item_id FK
        identifier order_id FK
        identifier actor_id FK
        decimal signed_quantity
        text reason
        key operation_key
    }
    SETTING {
        key name PK
        typed_value value
        identifier updater_id FK
    }
    AUDIT_EVENT {
        identifier id PK
        identifier actor_id FK
        action event
        reference subject
        time occurred_at
    }
```

## Decisions and optionality

- A role can have zero staff; a staff account can be unassigned during provisioning. Active operational access requires exactly one recognized role. No many-to-many role/permission tables are needed for three fixed roles.
- Every order has one retained staff creator and one or more items. Product/category/user references are retained with RESTRICT, while active flags retire them. Financial history has no cascade deletion. Required one-or-more items is enforced by checkout transaction, not a simple FK.
- Order-to-payment attempts is one-to-many. The order's nullable accepted_payment_id and active_payment_id each select at most one of its attempts; one attempt can only settle its own order. Thus optional one-to-one selection coexists with the attempt history. TRD explains the cross-reference constraints.
- Products and inventory items have a many-to-many relationship through recipe components. Recipes are justified for drinks and packaged stock; options, suppliers and purchase-order entities await concrete requirements.
- Order/stock-item reservations are a many-to-many association with requirement snapshots, needed to preserve availability while external payment is pending. They are not customer carts.
- Stock movements may have an order for a sale or no order for deliveries/waste/adjustment; the actor can be null for a trusted system operation, accompanied by an operation reference/reason. Settings and audit system actions have optional actors.
- Audit events are proposed for sensitive administrative changes. They supplement finance/stock records and contain allow-listed metadata, not a generic raw-request log.
- Settings have a unique key and typed approved value. Credentials are deliberately excluded. Framework token/reset/session/cache/job tables are infrastructure, not conceptual business entities; the TRD records their actual status separately.

The operational catalog, role, recipe and stock entities are normalized toward 3NF. Order snapshots intentionally duplicate historical product facts; persisted order aggregates and stock balances are deliberate derived data maintained transactionally and reconciled. No customer, store/tenant, loyalty, printer or delivery table is inferred.
