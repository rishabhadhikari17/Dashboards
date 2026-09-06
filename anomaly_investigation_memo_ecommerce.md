# Anomaly Investigation Memo - Ecommerce Dashboard

**Finding:** The June 14 headline drop (revenue -78%, orders -72%, conversion -34%) is likely a **partial-day artifact, not a real business collapse**. Sessions that day fall to 429 vs. a ~900-1,000/day baseline all week — every KPI moves in lockstep by a similar magnitude, which is the signature of a mid-day data pull rather than an actual demand shock. This should be excluded or footnoted before reporting the "34% conversion drop" as a genuine trend.

**The real anomaly is a 10-week structural decline that predates June 14.** Daily conversion rate fell from ~35-38% in late March to ~18-22% by mid-June — a ~45% relative drop — while sessions declined only ~35-40% (1,600 → ~950/day) over the same window. Conversion is deteriorating *faster* than traffic, compounding into revenue falling from ~$7.6M/day (April 5 peak) to ~$1.3-1.9M/day by June, a much steeper drop than traffic alone explains.

**Supporting signal:** Refund rate spiked to its highest level of the period (0.9-0.98%) in mid-May, right as conversion was cratering — worth checking for a shared root cause (checkout/payment issue, pricing change, or a product-quality problem surfacing around then).

**Next step:** Segment conversion by channel/device/country to isolate whether the decay is broad-based or concentrated in one segment before assuming a single root cause.
