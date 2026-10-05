# Responsive POS engineering

Adapted from Flutter's responsive-layout skill; BSD-3-Clause. Breakpoints and POS composition below are project decisions to validate, not fixed Flutter requirements.

Use `LayoutBuilder` for the space allocated to a POS panel. Use `MediaQuery.sizeOf` only when the whole window is relevant. A hardware label or portrait/landscape check does not determine usable width.

Choose breakpoints where the content stops fitting. A wide view may place catalog and cart together; a narrow view may show one with a persistent cart summary. Both views must share order/cart state and preserve it while resizing. Avoid rebuilding state ownership when switching layout branches.

Use flexible constraints, bounded reading widths and lazy lists/grids for catalogs. Keep checkout totals and actions reachable when the keyboard opens. Respect safe areas; avoid imposing portrait-only operation without a product requirement.

Validate a narrow phone, tablet portrait, tablet landscape, resizable window, long Khmer labels and enlarged text. Check scrolling, selection preservation, focus and no overflow exceptions. Select actual test widths from supported devices and describe them in the verification report.
