# Executive Summary - Product (SaaS) Dashboard

## Purpose

The Product (SaaS) dashboard gives **Rahul, Product Manager**, a decision-ready view of product health across acquisition, activation, adoption and retention. Its purpose is to separate sustained regressions from short-term noise before product and engineering capacity is committed.

## Executive question

> Is the product journey deteriorating consistently enough to require sprint action, and where is the friction concentrated?

## Decisions enabled

1. **Sprint action or research first:** A decline sustained for three or more weeks and linked to a recent change can move into sprint planning; a one-week wobble requires diagnosis first.
2. **Where to intervene:** Activation, time-to-value, funnel drop-off and cohort retention identify whether friction occurs before first value, during feature adoption or after activation.
3. **Who is affected:** Plan Type, Signup Source and User Role filters reveal whether deterioration is broad or isolated to a segment.

## Dashboard hierarchy

| Level | What Rahul sees | Decision value |
|---|---|---|
| Product health | WAU and 12-week WAU trend | Confirms whether engagement is stable, rising or declining. |
| Lifecycle quality | Weekly Activation Rate and 30-Day Retention Rate | Shows whether new users reach value and return. |
| Adoption diagnostics | Time to First Value, Top 10 Features by WAU and Feature-Adoption Funnel | Locates onboarding and feature-discovery friction. |
| Cohort evidence | W1/W2/W4/W8/W12 retention table | Distinguishes a persistent cohort regression from a temporary spike. |

## Core metric definitions

- **WAU:** Distinct users with at least one `feature_use` event in a completed calendar week.
- **Activation Rate:** Eligible signups using a core feature within seven days ÷ eligible mature signups.
- **30-Day Retention:** Activated users with meaningful activity during days 30–36 after activation ÷ mature activated users.
- **Time to First Value:** Time from signup to first core-feature use within 30 days.
- **Feature Share of WAU:** Distinct users of a feature ÷ total WAU for the selected user segment.

## Action signals

- Treat a **three-or-more-week decline** as evidence requiring product review, especially when it aligns with a release, UI change or plan change.
- Treat an isolated weekly movement as a research prompt, not an automatic sprint ticket.
- Prioritize the largest sequential funnel drop and confirm it across activation, retention and cohort evidence.
- Read percentages with their population counts; small filtered cohorts can produce unstable rates.

## Critical caveats

- Activation and first value both use core-feature activity as proxies until a dedicated milestone is instrumented.
- Activation, adoption and retention exclude cohorts without complete observation windows.
- Thirty-day retention is a seven-day return window beginning on day 30; it is not continuous 30-day activity.
- Release-date annotations are still required on diagnostic trends to connect regressions with product changes.

## Success criterion

Rahul can determine within minutes whether to **monitor, investigate or prepare an evidenced sprint intervention**, without mistaking a single-week spike for a product regression.

<img width="897" height="745" alt="image" src="https://github.com/user-attachments/assets/92dae264-faf4-40cb-9dbd-7d8d0185cbf7" />
<img width="902" height="552" alt="image" src="https://github.com/user-attachments/assets/e2dc82a7-0f4a-426f-b272-7eee803dc6e8" />


