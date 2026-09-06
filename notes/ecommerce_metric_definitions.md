# Ecommerce Dashboard — Metric Definitions

## Scope and conventions

- **Primary user:** Founder/CEO
- **Database:** `ecom`
- **Successful order:** A distinct order where `LOWER(TRIM(orders.payment_status)) = 'paid'`.
- **Revenue recognition:** Revenue includes only successful paid orders.
- **Daily KPI anchor:** For Revenue, Orders, AOV and Conversion Rate, “today” means the latest date in the selected dashboard range.
- **WoW comparison:** The daily KPI is compared with the same weekday seven calendar days earlier.
- **Percentage storage:** Rates and relative changes are returned as decimal ratios (`0.10 = 10%`) for Metabase percentage formatting.

## KPI dictionary

| Metric | Definition | Numerator | Denominator | Window / comparison | Exclusions and notes |
|---|---|---|---|---|---|
| **Revenue** | Gross order value from successful orders. | Sum of `orders.total` after reducing joined data to one row per paid order. | Not applicable; Revenue is a sum. | Latest selected date for the hero value; WoW compares with the same weekday seven days earlier. Trend can display up to 90 selected days. | Excludes pending, failed and cancelled orders. Refund amounts are not subtracted. Currency conversion, taxes and shipping treatment follow the stored `orders.total` value. |
| **Successful Orders** | Number of distinct successfully paid orders. | Distinct paid `order_id` values. | Not applicable; Orders is a distinct count. | Latest selected date for the hero value; WoW compares with the same weekday seven days earlier. | Excludes unpaid orders. One-to-many attribution, payment and refund records are deduplicated before counting. `order_id` is the canonical counting key; use `order_number` only if the business confirms it is uniquely enforced. |
| **Average Order Value (AOV)** | Average gross value of successful orders. | Revenue from distinct paid orders. | Distinct paid orders in the same period and segment. | Latest selected date for the hero value; WoW compares with the same weekday seven days earlier. | Excludes unpaid orders and dates with zero paid orders, for which AOV is `NULL`. Refunds are not netted from order value. It is calculated from aggregate Revenue ÷ Orders, not by averaging pre-calculated daily AOVs. |
| **Conversion Rate** | Share of eligible sessions that produced at least one successful paid order. | Distinct sessions containing one or more paid orders. | Distinct eligible sessions. | Latest selected session date for the hero value; WoW compares with the same weekday seven days earlier. | Multiple paid orders in one session count as one converted session, so the rate cannot exceed 100%. Date filtering uses `sessions.started_at`. Country and Payment Method are order-level attributes; applying them removes sessions without matching order data and can inflate the rate. They should not filter this KPI unless equivalent session-level fields exist. |
| **Refund Rate — 7 Day** | Share of paid orders in a rolling seven-day order cohort that have at least one successful refund record. | Distinct paid orders created during the rolling seven-day window with a refund whose status is `succeeded`. | Distinct paid orders created during the same rolling seven-day window. | Latest seven days ending on the selected anchor date; WoW compares with the immediately preceding, non-overlapping seven days. | Measures refunded-order incidence, not refunded monetary value. Partial and full refunds both count as one refunded order. The current implementation groups by order creation date, not refund occurrence date, and therefore is not a true refund-event trend. |

## Supporting dashboard metrics

| Metric | Numerator | Denominator | Exclusions and notes |
|---|---|---|---|
| **Revenue by Country** | Paid-order Revenue assigned to each customer country. | Not applicable. | Excludes unpaid orders. Missing country values should be labelled `Unknown`. Joined data must be deduplicated to one row per order. |
| **Revenue by Acquisition Channel** | Paid-order Revenue assigned to each attribution channel. | Not applicable. | Excludes unpaid orders. If a session has multiple attribution touches, a documented attribution rule is required; otherwise the same order can be associated with multiple channels. |
| **Diagnostic Revenue** | Sum of `orders.total` for paid orders on each diagnostic date. | Not applicable. | The diagnostic table covers the latest 14 available session dates. Refunds are not subtracted. |
| **Diagnostic Orders** | Distinct paid orders on each diagnostic date. | Not applicable. | Excludes unpaid orders and must be deduplicated after joins. |
| **Diagnostic AOV** | Diagnostic Revenue. | Diagnostic paid Orders. | Returns `NULL` when a date has no paid orders. |
| **Diagnostic Conversion Rate** | Distinct converted sessions. | Distinct eligible sessions on the date. | Must use the same converted-session definition as the hero KPI. |
| **Diagnostic Refund Rate** | Distinct successfully refunded paid orders. | Distinct paid orders on the date. | Uses order-level incidence, not refunded value. |

## Interpretation caveats

- Dashboard Date Range controls the displayed dates; each daily hero tile shows the latest selected date rather than the total across the range.
- Revenue will not match reports that include pending or cancelled orders because only `payment_status = 'paid'` is included.
- Order-level joins can duplicate Revenue and Orders unless the data is reduced to one row per order before aggregation.
- The operational refund-spike KPI should eventually use a refund timestamp. Until then, the current rate describes paid-order cohorts that were later refunded.
- All filters should be validated through a filter-coverage matrix. A filter being connected does not guarantee that its denominator remains analytically valid.
