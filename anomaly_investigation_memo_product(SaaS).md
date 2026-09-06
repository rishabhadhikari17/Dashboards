Anomaly Investigation Memo

Finding: The critical drop-off isn't Activated→Power Feature — it's Signup→Activation.

Data: Of 150 signups, only 8 (5.3%) activated within 7 days, but of those 8, fully 50% (4 users) went on to use a power feature within 30 days. The Activation→Power Feature step is actually healthy. The real leak is upstream: 118 of 150 users (79%) find no value within 30 days, and only 4 users hit first value in under a day. Weekly activation rates confirm this — mostly sitting in the 0–12% range, only spiking to 30%+ in the last two (small, low-n) cohorts.

Context: WAU is up 14% WoW to 276, so top-of-funnel and engagement of existing actives look fine — this masks the activation problem for anyone glancing only at the WAU chart.

Hypothesis: Onboarding isn't getting new users to first value fast enough; the 7-day activation window may also be too tight relative to actual time-to-value (median lands in the 7–30 day bucket).

Recommended next step: Instrument the onboarding flow to find where the 7-day window is missed, and test whether extending it or simplifying first-value actions moves the 5% activation rate before optimizing anything downstream.
