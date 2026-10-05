# API boundary checks

Project-specific security checks added to the Apache-2.0 adapted workflow. OWASP is cited as reference material, not copied or relicensed.

| Surface | Check and useful negative case |
| --- | --- |
| Identity/session | Document token/cookie model, expiry, revocation and recovery; reject expired/revoked credentials |
| Object access | Query scope plus policy; a second actor cannot read or mutate a protected order/user/payment |
| Property access | Allow-listed write/response fields; reject role, ownership, price and paid-status escalation |
| Function access | Server-side cashier/manager/admin permission decisions; hidden controls are insufficient |
| Input/query | Bound strings, numbers, collections, uploads and filters; bind values and map SQL identifiers |
| Abuse/cost | Limit auth attempts and expensive report/provider operations; consider shared shop networks and avoid account-lockout abuse |
| Outbound I/O | Allow-listed provider hosts, HTTPS, timeouts and strict status/schema handling; reject user-supplied fetch destinations |
| Configuration | No debug disclosure or unnecessary public routes; maintain API version/endpoint inventory |
| Secrets | Backend-only provider keys; app build defines are public; redact tokens/PII/payment payloads |

Compare the relevant concerns against the OWASP API Security Top 10 (2023) and current cheat sheets linked in the skill README. Consult newer editions if published; do not relabel 2023 guidance as a newer release. The table is an engineering aid, not a complete certification checklist.

For a browser cookie/session feature, preserve CSRF protections and explicit origins. For native bearer-token use, avoid inventing a browser cookie flow. Follow Laravel's actual installed auth package and bootstrap conventions.
