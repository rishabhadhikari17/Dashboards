# Executive Summary - Ecommerce Dashboard

## Purpose

The Ecommerce dashboard gives a **Founder/CEO** a three-minute, mobile-friendly view of daily commercial health before leadership meetings. It highlights current trajectory, urgent customer-impacting problems and progress toward quarterly performance.

[Ecommerce Dashboard PRD](https://app.notion.com/p/Ecommerce-Dashboard-3cd573e17e4e8011878ceda18cec3a9d?source=copy_link)

## Executive question

> How are we performing today versus the same point last week, and is anything broken badly enough to escalate immediately?

## Decisions enabled

1. **Performance escalation:** Revenue below **−5% WoW** triggers a growth or operations conversation before the next stand-up.
2. **Immediate risk response:** A Refund Rate increase of approximately **2–3 percentage points** requires immediate investigation.
3. **Trajectory management:** Daily KPI trends and country/channel breakdowns show whether performance is broad-based and whether the business remains on track.

## Five-KPI executive view

| KPI | Current period | Comparison | What it signals |
|---|---|---|---|
| Revenue | Latest selected date | Same weekday seven days earlier | Commercial performance and demand trajectory. |
| Successful Orders | Latest selected date | Same weekday seven days earlier | Transaction volume independent of order value. |
| AOV | Latest selected date | Same weekday seven days earlier | Changes in basket value or product mix. |
| Conversion Rate | Latest selected date | Same weekday seven days earlier | Ability of sessions to produce paid orders. |
| Refund Rate | Rolling seven days | Previous non-overlapping seven days | Customer trust, fulfilment or product-quality risk. |

## Supporting diagnosis

- **Revenue and Orders trend:** Daily performance across the selected period, with exact seven-day comparisons.
- **Revenue by Country:** Identifies geographic concentration or market-level deterioration.
- **Revenue by Acquisition Channel:** Shows which acquisition sources are driving gains or losses.
- **14-day diagnostic table:** Revenue, Orders, AOV, Conversion Rate and Refund Rate by day for rapid investigation.

## Required filters

Date Range, Country, Acquisition Channel, Payment Method and Device Type must propagate consistently across applicable cards. Filter behavior should be verified through a Filter Coverage Matrix.

## Core metric definitions

- **Revenue:** Sum of `orders.total` for distinct paid orders.
- **Successful Orders:** Count of distinct paid `order_id` values.
- **AOV:** Paid-order Revenue ÷ distinct paid Orders.
- **Conversion Rate:** Distinct sessions containing a paid order ÷ distinct eligible sessions.
- **Refund Rate:** Distinct paid orders with a successful refund ÷ distinct paid orders in the rolling seven-day cohort.

## Critical caveats

- Revenue includes only `payment_status = 'paid'`; it will not match reports containing pending or cancelled orders.
- Refunds are not subtracted from Revenue, and Refund Rate measures order incidence rather than refunded monetary value.
- The current Refund Rate is based on order creation date rather than refund occurrence date.
- Attribution and payment joins must be deduplicated to one row per order before aggregation.
- Country and Payment Method are order-level attributes; applying them to Conversion Rate can remove non-converting sessions and inflate the result unless equivalent session-level fields exist.

## Success criterion

The Founder/CEO can answer **“Are we okay, what changed and does anyone need to act now?”** within three minutes, with Refund Rate treated as the highest-priority operational warning signal.

<img width="1070" height="840" alt="image" src="https://github.com/user-attachments/assets/2e720c77-0bef-45a7-92d0-c1d55e73fec8" />

