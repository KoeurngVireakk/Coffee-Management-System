# Acceptance scenarios

Original project checks. WCAG 2.2 web criteria are linked for authoritative definitions; native mobile targets need platform-specific checks too.

- At enlarged text and narrow width, long Khmer names wrap without cutting glyphs, obscuring quantities or hiding checkout. Review actual Khmer text with a fluent speaker.
- A cashier can navigate product, cart and payment controls with touch and keyboard. TalkBack/VoiceOver describe the item, quantity, action and total without announcing duplicate decorative content.
- After validation/network failure, preserve valid inputs and the cart; identify what needs correction and allow recovery. A timeout is an uncertain provider outcome, not proof of failure or permission to charge again.
- Pending, failed, expired and verified payment states have distinct text. A customer screenshot or a locally decoded QR does not generate a verified state.
- Check normal text contrast against the applicable WCAG AA definition (generally 4.5:1, with 3:1 for qualifying large text and stated exceptions). Focus and control boundaries need their own applicable checks. The local 48-logical-pixel POS target goal is not WCAG's 24-CSS-pixel web minimum.

Record devices, sizes, text scales, input methods, language samples and assistive technologies actually tested. Preserve unresolved language/currency/user-research questions in the report.
