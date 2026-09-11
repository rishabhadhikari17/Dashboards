# Analytics & Dashboard Portfolio

This project contains two Metabase dashboards built on separate analytics databases:

1. **Product (SaaS)** — product health, activation, adoption and retention for Rahul, Product Manager.
2. **Ecommerce** — daily commercial health and operational warning signals for a Founder/CEO.

The dashboards share a consistent design principle: leadership metrics appear first, trends provide context, and diagnostic breakdowns help users decide where to investigate.

## Dashboard summary

| Dashboard | Primary user | Database | Reporting grain | Primary purpose |
|---|---|---|---|---|
| Product (SaaS) | Rahul, Product Manager | `saas` | Weekly cohorts and completed weeks | Detect sustained product regressions and identify onboarding or feature-adoption friction. |
| Ecommerce | Founder/CEO | `ecom` | Daily, refreshed daily | Assess current performance, identify urgent commercial risks and monitor trajectory. |

## 1. Product (SaaS) dashboard

### Job to be done

When product-health metrics change, Rahul needs to distinguish a sustained regression from a temporary fluctuation so he can decide whether to investigate first or take an evidenced issue into sprint planning.

### Decisions enabled

1. Is a decline sustained and strong enough to enter sprint planning?
2. Where does the signup-to-value journey lose the most users?
3. Which user segment, feature or signup cohort is driving the change?

### Dashboard components

| Section | Cards and charts |
|---|---|
| Health overview | Weekly Active Users and WAU trend |
| Lifecycle trends | Activation Rate and 30-Day Retention Rate |
| Adoption diagnostics | Time to First Value, Top 10 Features by Share of WAU and Feature-Adoption Funnel |
| Cohort diagnostics | W1, W2, W4, W8 and W12 signup-cohort retention table |

### Core definitions

- **WAU:** Distinct users performing at least one `feature_use` event during a completed calendar week.
- **Activation:** First core-feature use within seven days of signup.
- **30-day retention:** Meaningful activity from day 30 inclusive to day 37 exclusive after activation.
- **First value:** First core-feature use within 30 days of signup.
- **Power feature:** A feature in `analytics`, `workflow`, `integrations` or `data`.

### Filters

- Signup Date
- Plan Type (`users.plan_type`)
- Signup Source (`users.signup_source`)
- User Role (`users.role`)
- Feature Category (`features.category`) — applies only to feature-level analysis

Plan Type, Signup Source and User Role must filter the user population before numerators and denominators are calculated. Feature Category restricts the Top 10 feature list but does not change the total-WAU denominator.

### Key caveats

- Activation and first value use core-feature activity as proxies until a dedicated product milestone is defined.
- The current reporting cut-off is specified in SQL and should use the production refresh date when deployed.
- Activation, retention and adoption queries exclude cohorts without complete observation windows.
- Small segmented cohorts can produce volatile rates; percentages should be read alongside user counts.
- The cohort table returns percentage-point values, while the other rate queries return decimal ratios for Metabase formatting.

## 2. Ecommerce dashboard

### Job to be done

Before a daily business meeting, the Founder/CEO needs a fast view of performance and operational risk so they can escalate material problems and assess whether the business remains on track.

### Decisions enabled

1. Is current performance materially worse than the same point last week?
2. Is there an urgent issue—such as a refund spike, payment problem or market decline—to escalate today?
3. Is commercial performance tracking toward the quarterly goal?

### Hero KPIs

Only these five KPIs appear at the top:

| KPI | Current value | Comparison |
|---|---|---|
| Revenue | Latest selected date | Same weekday seven days earlier |
| Successful Orders | Latest selected date | Same weekday seven days earlier |
| AOV | Latest selected date | Same weekday seven days earlier |
| Conversion Rate | Latest selected date | Same weekday seven days earlier |
| Refund Rate | Rolling seven days ending on the latest selected date | Immediately preceding, non-overlapping seven days |

The Date Range controls the dates displayed by a Trend tile. It does not make the hero value a total across the selected range; the tile displays the latest selected date.

### Supporting analysis

- Revenue and Orders trend
- Revenue by Country
- Revenue by Acquisition Channel
- Last-14-days diagnostic table containing Revenue, Orders, AOV, Conversion Rate and Refund Rate

### Filters

- Date Range
- Country
- Acquisition Channel
- Payment Method
- Device Type

All filters should be tested through a Filter Coverage Matrix. Country and Payment Method require special care on Conversion Rate because they are order-level attributes: filtering sessions through these fields can remove non-converting sessions and inflate the rate.

### Core definitions

- **Revenue:** Sum of `orders.total` for distinct orders where `payment_status = 'paid'`.
- **Successful Orders:** Distinct paid `order_id` values.
- **AOV:** Paid-order Revenue divided by distinct paid Orders.
- **Conversion Rate:** Distinct sessions containing at least one paid order divided by distinct eligible sessions.
- **Refund Rate:** Distinct paid orders with at least one successful refund divided by distinct paid orders in the rolling seven-day order cohort.

### Key caveats

- Revenue excludes pending, failed and cancelled orders and does not subtract refunds.
- One-to-many attribution and payment joins must be reduced to one row per order before aggregating Revenue, Orders or AOV.
- Refund Rate measures refunded-order incidence, not refunded value; the current implementation is based on order creation date rather than refund occurrence date.
- Revenue by Channel needs a documented attribution rule when sessions contain multiple attribution touches.
- The Conversion Rate denominator must count sessions, while its numerator counts converted sessions—not orders.

## Shared implementation standards

### SQL

- Normalize categorical comparisons with `LOWER(TRIM(...))`.
- Use distinct business keys before aggregating across one-to-many joins.
- Generate continuous calendars so dates or weeks with zero activity do not disappear.
- Exclude incomplete periods from lifecycle rates or return `NULL` rather than presenting them as 0%.
- Compare daily Ecommerce KPIs with the exact calendar date seven days earlier.
- Return decimal ratios for Metabase percentage formatting unless a metric dictionary explicitly states otherwise.

### Dashboard QA

Before publishing or completing the consistency audit, verify:

- Each filter is mapped to the intended physical database field.
- The same filter produces consistent populations across related cards.
- Hero tiles and supporting charts use identical metric definitions.
- No metric is inflated by attribution, payment, refund or event join duplication.
- Zero-activity periods appear correctly and immature cohorts remain blank.
- Trend comparisons use the intended prior period rather than the previous displayed row.
- Titles and descriptions state the metric window and population clearly.
- Cross-dashboard consistency audit (2026-05-15 to 2026-06-14, no filters):Ecom — Revenue: ₹5.89Cr. SaaS — no shared Revenue card, no conflict. Audit date: 2026-09-06.
