# Product (SaaS) Dashboard & Metric Definitions

## Scope and conventions

- **Primary user:** Rahul, Product Manager
- **Database:** `saas`
- **Meaningful activity:** An event where `LOWER(TRIM(events.event_type)) = 'feature_use'`.
- **Core feature:** A feature where `LOWER(TRIM(features.category)) = 'core'`.
- **Completed week:** A calendar week ending before the current reporting week.
- **Segmentation:** Plan Type, Signup Source and User Role filter the user population before metrics are calculated. Feature Category applies only to feature-level analysis.
- **Percentage storage:** Unless noted otherwise, rates are returned as decimal ratios (`0.25 = 25%`) for Metabase percentage formatting.

## KPI dictionary

| Metric | Definition | Numerator | Denominator | Window / comparison | Exclusions and notes |
|---|---|---|---|---|---|
| **Weekly Active Users (WAU)** | Unique users who performed meaningful product activity during a completed calendar week. | Distinct users with at least one `feature_use` event in the week. | Not applicable; WAU is a distinct count. | Latest completed week for the hero value; 12 completed weeks for the trend. WoW compares with the previous completed week. | Excludes non-`feature_use` events, duplicate events by the same user, and the incomplete current week. The WAU card and WAU trend must use this identical definition. |
| **Activation Rate** | Share of eligible signups who reached their first core-feature value moment within seven days of signup. | Distinct eligible users with a core `feature_use` event from signup inclusive to 168 hours after signup exclusive. | Distinct users in mature signup-week cohorts. | Reported by signup week across 12 mature cohorts. | Excludes signups without a complete seven-day observation window, activity before signup, non-core features and non-`feature_use` events. Activation is an event-based proxy, not the `users.is_active` field. |
| **30-Day Retention Rate** | Share of activated users who returned for meaningful activity during days 30â€“36 after their activation timestamp. | Distinct activated users with at least one `feature_use` event from day 30 inclusive to day 37 exclusive after activation. | Distinct users activated through a core feature within seven days of signup. | Reported by mature activation week. The smoothed series is a weighted four-calendar-week rate: total retained users divided by total activated users across those four weeks. | Excludes immature activation cohorts, activity outside days 30â€“36 and non-`feature_use` events. A cohort with no activated users returns `NULL`, not 0%. |
| **Time to First Value** | Distribution of the time from signup to a user's first core-feature use. | Distinct eligible users in each time bucket. | All eligible users with a complete 30-day observation window. | Under 1 hour; 1â€“6 hours; 6â€“24 hours; 1â€“3 days; 3â€“7 days; 7â€“30 days; no value within 30 days. | Excludes non-core activity, non-`feature_use` events, activity before signup and users without a complete 30-day window. Users who never reach value remain in the final bucket and are not dropped. |
| **Feature Share of WAU** | Share of weekly active users who used a particular feature during the latest completed week. | Distinct WAU who used the feature at least once. | Total distinct WAU in the selected user segment during the same week. | Latest completed week; features ranked descending and limited to the top 10. | Event volume does not increase the numerator because users are deduplicated. Feature Category restricts the ranked feature list but does not change the total-WAU denominator. Features with no usage do not appear. |
| **Feature Events per User** | Average usage frequency among users of a particular feature. | Total `feature_use` events for the feature. | Distinct users who used that feature. | Latest completed week. | Excludes users who did not use the feature and non-`feature_use` events. This is an engagement diagnostic, not an adoption rate. |
| **Feature-Adoption Funnel** | Sequential progression from signup to activation and then power-feature use. | Stage counts: eligible signups; users activated within seven days; activated users who subsequently used a power feature within 30 days of signup. | Overall conversion uses eligible signups; previous-stage conversion uses the immediately preceding stage. | Users must have a complete 30-day adoption window. | Power features are categories `analytics`, `workflow`, `integrations` and `data`. Power usage must occur at or after activation. The former separate â€œUsed Core Featureâ€ stage is omitted because activation already requires core-feature use. |
| **Signup Cohort Retention (W1/W2/W4/W8/W12)** | Share of a signup cohort that performed meaningful activity in the specified calendar week after signup. | Distinct cohort users with a `feature_use` event in the target week. | Distinct users who signed up in the cohort week. | Target weeks are 1, 2, 4, 8 and 12 calendar weeks after the signup week. | Excludes non-`feature_use` activity. Immature cells return `NULL`, not 0%. SQL currently returns percentage-point values (`55.56 = 55.56%`), unlike the decimal ratios used by the other rate metrics. |

## Interpretation caveats

- The reporting cut-off is currently defined in SQL; it should be replaced by the production data refresh date when the dashboard goes live.
- Activation and first value both use first core-feature activity as a proxy. If the product defines a specific activation event, both metrics should be updated together.
- Thirty-day retention is a seven-day return window starting on day 30; it is not continuous activity throughout the first 30 days.
- Small segmented cohorts can create volatile percentages. Always read activation and retention rates alongside their user counts.

<img width="897" height="745" alt="image" src="https://github.com/user-attachments/assets/7cf873c9-9dee-422a-8a36-a86ad629d5fb" />
<img width="902" height="552" alt="image" src="https://github.com/user-attachments/assets/0e861dd5-c65a-4594-9a31-9d896f91dd6e" />


