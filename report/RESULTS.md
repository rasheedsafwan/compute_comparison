# Infrastructure Load Test Analysis Report
### Compute Platform Benchmark: Lambda vs. Fargate vs. EC2

---

## 1. Introduction & Traffic Model Definitions

This report analyzes latency, reliability, and cost performance across four compute execution environments — AWS Lambda (128MB), AWS Lambda (1024MB), AWS Fargate (256 vCPU units / 512MB), and EC2 (t3.small) — under three distinct traffic models. Each model was chosen to stress compute platforms differently, particularly around auto-scaling behavior, connection warm-up, and idle resource management.

| Traffic Model | Concurrency (VUs) | Throughput | Pattern Description |
|---|---|---|---|
| **Low-Spiky** | Peak of 30 VUs | ~13.5 req/s | Short, sharp bursts of concurrent traffic separated by long **90-second idle windows** with zero requests. |
| **Medium-Steady** | 15 VUs (flat) | ~12.0 req/s | A continuous, uniform stream with no pauses — the classic "always-on" baseline workload. |
| **High-Sustained** | 60 VUs (ramped) | ~47.5 req/s | A heavy, uninterrupted high-concurrency load simulating peak production traffic. |

**What this means operationally:**
* **Low-Spiky** mimics workloads like internal admin tools, scheduled batch triggers, or low-traffic APIs that see occasional bursts (e.g., a webhook receiver). The 90-second silence windows are long enough for compute platforms to begin reclaiming idle resources — this is the critical variable that separates Lambda's behavior from Fargate/EC2 in this test.
* **Medium-Steady** represents a predictable, moderate-traffic production service — think an internal microservice with consistent, non-viral demand. No idle window means no cold-start penalty should be observed here under normal circumstances.
* **High-Sustained** represents peak-hour production traffic for a moderately popular public-facing service, where raw throughput ceiling and concurrency handling — not idle-related penalties — become the dominant performance factors.

---

## 2. Raw Benchmark Metrics

### Scenario A: Low-Spiky (Peak 30 VUs / ~13.5 req/s / 90s idle gaps)

| Platform | p50 | p95 | p99 | Error Rate | Window Cost | Scaled Cost (per 1M req) |
|---|---|---|---|---|---|---|
| Lambda 128MB | 139.98ms | 159.17ms | 178.09ms | 0% | $0.000677 | $0.20 |
| Lambda 1024MB | 134.48ms | 147.92ms | 337.79ms | 0% | $0.005370 | $1.58 |
| Fargate (256/512) | 119.56ms | 127.62ms | 147.83ms | 0% | $0.002057 | $0.60 |
| EC2 (t3.small) | 119.92ms | 128.93ms | 149.61ms | 0% | $0.007217 | $2.10 |

### Scenario B: Medium-Steady (15 VUs / ~12.0 req/s / no pauses)

| Platform | p50 | p95 | p99 | Error Rate | Window Cost | Scaled Cost (per 1M req) |
|---|---|---|---|---|---|---|
| Lambda 128MB | 140.45ms | 159.83ms | 180.25ms | 0.03% (1 fail) | $0.000711 | $0.20 |
| Lambda 1024MB | 134.85ms | 145.50ms | 166.09ms | 0% | $0.005527 | $1.54 |
| Fargate (256/512) | 119.91ms | 136.14ms | 172.73ms | 0% | $0.002057 | $0.57 |
| EC2 (t3.small) | 120.64ms | 131.68ms | 155.74ms | 0% | $0.007217 | $1.99 |

### Scenario C: High-Sustained (60 VUs / ~47.5 req/s / uninterrupted)

| Platform | p50 | p95 | p99 | Error Rate | Window Cost | Scaled Cost (per 1M req) |
|---|---|---|---|---|---|---|
| Lambda 128MB | 140.84ms | 159.46ms | 171.75ms | 0% | $0.005697 | $0.20 |
| Lambda 1024MB | 133.78ms | 147.77ms | 164.20ms | 0% | $0.044238 | $1.54 |
| Fargate (256/512) | 119.23ms | 149.12ms | 231.35ms | 0% | $0.004114 | $0.14 |
| EC2 (t3.small) | 120.77ms | 140.57ms | 177.47ms | 0% | $0.010683 | $0.37 |

---

## 3. Cold-Start Deep Dive: The Low-Spiky Anomaly

The most significant finding in this benchmark surfaces in **Scenario A (Low-Spiky)**, where the p99 tail latency for **Lambda 1024MB spikes to 337.79ms** — nearly double its steady-state p99 of 166.09ms observed in Scenario B. Raw request-duration traces confirm a cold-start scaling event, with the **1024MB configuration recording a maximum single-request latency of 1,132.08ms** in this run.

By contrast, the **128MB configuration's worst-case latency in the same run peaked at only 423.80ms** — roughly a third of the 1024MB tier's maximum. This gap is the core evidence behind the report's cold-start finding: under sparse, idle-heavy traffic, a *smaller* memory allocation reinitializes meaningfully faster than a larger one, even though both are subject to the same eviction policy during the 90-second idle windows.

**A second, easy-to-miss data point complicates a "bigger memory = worse cold starts, always" reading.** In **Scenario B (Medium-Steady)**, where there are no idle gaps to trigger eviction, Lambda 128MB's own worst-case latency actually climbed to **1,117.25ms** — essentially matching the 1024MB tier's Scenario A cold-start max — and this was the single request that produced the run's **0.03% error rate (1 failed request out of 3,548)**. Lambda 1024MB's worst case in the same scenario was lower, at **1,015.94ms**, and it recorded zero failures. Since Scenario B has no idle windows, this spike isn't an eviction-driven cold start; it's more consistent with the 128MB tier's thinner CPU allocation occasionally causing a request to run long enough to breach the API Gateway proxy timeout — a distinct risk from the idle-eviction pattern described below, but one that also disproportionately affects the smallest memory tier.

**Why do larger memory allocations suffer worse cold starts under sparse, idle-heavy traffic?**

1. **Aggressive host-blade pruning**: Cloud providers run underlying compute "blades" at high density to maximize hardware utilization. Idle execution environments are prioritized for eviction based on a cost/benefit calculation — larger-memory containers consume proportionally more reserved capacity on the physical host while sitting idle, making them prime eviction candidates during the 90-second silence windows.
2. **Larger memory footprint = slower initialization**: Provisioning a 1024MB execution environment requires the platform to allocate a proportionally larger memory page set, initialize a larger runtime sandbox, and load a heavier interpreter/VM footprint before the function handler can execute. This scales the re-initialization penalty non-linearly compared to a lean 128MB container — the 1,132.08ms vs. 423.79ms gap observed above illustrates this directly.
3. **Eviction-reinitialization cycle mismatch**: Because the idle gap (90s) is long enough to trigger container recycling but the burst itself is short, the 1024MB configuration essentially "pays the cold-start tax" on every burst cycle, whereas a workload with shorter or zero idle windows (Scenario B/C) never triggers the eviction policy in the first place — explaining why Lambda 1024MB's p99 normalizes back to ~164–166ms in Medium-Steady and High-Sustained scenarios.

**Operational implication:** For sparse/bursty invocation patterns, provisioning *more* memory to Lambda does **not** guarantee better tail latency — it can actively work against you unless paired with Provisioned Concurrency or a warming strategy.

---

## 4. Architectural Recommendation Matrix

| Traffic Pattern | Recommended Platform | Rationale |
|---|---|---|
| **Low-Spiky / Bursty (Idle Gaps ≥ 60–90s)** | **Lambda 128MB** | Lowest scaled cost ($0.20/1M req), zero errors, and the smallest cold-start footprint tested (423.80ms max vs. 1,132.08ms for the 1024MB tier). Avoid Lambda 1024MB in this profile unless Provisioned Concurrency is enabled to neutralize the eviction-driven cold starts. |
| **Medium-Steady (Continuous, Predictable Load)** | **Fargate (256/512)** | Best-in-class p95/p99 balance (136ms/172ms) at competitive cost ($0.57/1M req) with zero errors. Fargate's persistent container model eliminates cold-start risk entirely once warm, making it the safest default for predictable production services. Note that Lambda 128MB recorded its only error of the entire benchmark here (0.03%, 1 request), consistent with occasional CPU-starvation timeouts on the thinnest memory tier even without idle-triggered eviction. |
| **High-Sustained (Peak Concurrency ≥ 60 VUs)** | **Fargate (256/512)**, with **EC2 as secondary** | Fargate delivers the *lowest scaled cost of the entire benchmark* ($0.14/1M req) at this volume, as fixed compute is amortized over massive throughput. EC2 ($0.37/1M req) is a viable secondary if long-term reserved/spot pricing is available, but note EC2's window cost is consistently the highest of all raw per-test costs — it only wins economically at massive, sustained scale over long time horizons, not in short benchmark windows. |

### Crossover Summary

* **Cost crossover:** Lambda's flat $0.20/1M req cost for the 128MB tier makes it unbeatable for low-volume, spiky workloads — but its economic advantage **erodes rapidly** as concurrency rises (see the widening cost delta of Lambda 1024MB at $1.54–1.58/1M req across all three scenarios).
* **Performance crossover:** Fargate and EC2 consistently post tighter, more predictable p50 and p95 tails than either Lambda configuration because they bypass API Gateway routing overhead entirely once warm. However, at extreme scale (**Scenario C**), Lambda 1024MB's horizontal distribution model posted a tighter p99 (164.20ms) than Fargate (231.35ms), suggesting serverless can be more resilient to thread-pool queuing delays under sudden high load.
* **Scale crossover:** At High-Sustained volumes, container-based platforms (Fargate) invert the cost equation entirely — Fargate's per-request cost *drops* as load increases (from $0.60 → $0.14 across Scenarios A → C) due to fixed-capacity amortization, while EC2 similarly benefits ($2.10 → $0.37) but never catches Fargate's efficiency in this dataset. Lambda's cost-per-request, by contrast, stays essentially flat regardless of scenario — serverless costs scale linearly with volume rather than benefiting from amortization the way container platforms do.

**Bottom line:** Use **Lambda 128MB** as the default for unpredictable, bursty, low-throughput services where operational simplicity and near-zero idle cost matter most. Migrate to **Fargate** the moment traffic becomes continuous or predictable — it delivers superior latency consistency and, at true production scale, the lowest total cost of ownership in this benchmark. Reserve **EC2** for workloads requiring OS-level control or where committed-use/spot pricing can be layered on top of its otherwise higher baseline costs.