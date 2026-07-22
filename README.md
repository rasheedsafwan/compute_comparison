# Compute Platform Load Test: Lambda vs. Fargate vs. EC2

**k6-driven, cost-normalized, cold-start aware**

This project benchmarks four AWS compute execution environments—**AWS Lambda (128MB)**, **AWS Lambda (1024MB)**, **Amazon ECS Fargate (256 CPU / 512MB)**, and **Amazon EC2 Auto Scaling (t3.small)**—under three distinct traffic patterns to answer a practical question: **which AWS compute platform should you choose, and does the answer change depending on your workload?**

All infrastructure is **provisioned using Terraform**, with reusable modules creating the networking, IAM, DynamoDB, API Gateway, ECS, EC2, Application Load Balancers, and supporting AWS resources. This ensures every compute platform is deployed consistently and can be reproduced from code.

Rather than running a single load test, the project deploys the same application to all four compute environments and executes identical k6 traffic scenarios (bursty/idle, steady, and high-concurrency sustained). Performance metrics and cost per request are then compared across platforms to provide a fair, data-driven evaluation of latency, scalability, operational trade-offs, and cost efficiency.

<img width="505" height="502" alt="compute-comparison drawio" src="https://github.com/user-attachments/assets/8f5a00d7-d574-4e83-a022-e3bc10a683e6" />

---

## Traffic models


| Model | Concurrency | Duration | Pattern |
|---|---|---|---|
| **Low-Spiky** | Peak 30 VUs | 4m 10s | Short bursts separated by 90s idle windows — stresses cold-start/eviction behavior |
| **Medium-Steady** | 15 VUs flat | 5m 0s | Continuous uniform stream — no idle gaps, "always-on" baseline |
| **High-Sustained** | 60 VUs ramped | 10m 0s | Uninterrupted high-concurrency load — simulates peak production traffic |

Each model isolates a different variable: idle-window recovery, steady-state predictability, and raw throughput ceiling, respectively.

---

## Key finding

Under sparse, idle-heavy traffic (90s gaps between bursts), **Lambda 1024MB's p99 latency spiked to 337.79ms** — over 3x its 128MB counterpart's worst case — with individual requests as slow as 1,132ms, consistent with a cold-start event triggered by aggressive idle eviction. Under continuous traffic (no idle gaps), that penalty disappears entirely and both memory tiers normalize to ~150–170ms p99.

The practical takeaway: **memory size and traffic shape interact.** More memory doesn't mean better latency — it depends entirely on whether your workload has idle gaps long enough to trigger container eviction.

| Traffic Pattern | Recommended Platform | Why |
|---|---|---|
| Low-Spiky / Bursty (idle gaps ≥ 60–90s) | **Lambda 128MB** | Lowest cost ($0.20/1M req), zero errors, smallest cold-start footprint |
| Medium-Steady (continuous load) | **Fargate (256/512)** | Best latency/cost/simplicity balance ($0.57/1M req) |
| High-Sustained (peak concurrency) | **Fargate (256/512)** | Lowest cost at scale ($0.14/1M req) as fixed compute amortizes |

See Section 4 of the full report for the complete recommendation matrix and crossover analysis.

---

## Results overview

Full latency percentiles, error rates, and cost figures for all four platforms across all three scenarios. "Window Cost" is the total spend for that specific test run (durations differ per scenario — see note below); "Scaled Cost" normalizes to cost per 1M requests and is the number to use for cross-scenario comparisons.

### Scenario A — Low-Spiky (peak 30 VUs, 90s idle gaps, 4m 10s)

| Platform | p50 | p95 | p99 | Error Rate | Window Cost | Scaled Cost (per 1M req) |
|---|---|---|---|---|---|---|
| Lambda 128MB | 139.98ms | 159.17ms | 178.09ms | 0% | $0.000677 | $0.20 |
| Lambda 1024MB | 134.48ms | 147.92ms | **337.79ms** | 0% | $0.005370 | $1.58 |
| Fargate (256/512) | 119.56ms | 127.62ms | 147.83ms | 0% | $0.002057 | $0.60 |
| EC2 (t3.small) | 119.92ms | 128.93ms | 149.61ms | 0% | $0.007217 | $2.10 |

### Scenario B — Medium-Steady (15 VUs flat, no pauses, 5m 0s)

| Platform | p50 | p95 | p99 | Error Rate | Window Cost | Scaled Cost (per 1M req) |
|---|---|---|---|---|---|---|
| Lambda 128MB | 140.45ms | 159.83ms | 180.25ms | 0.03% (1 fail) | $0.000711 | $0.20 |
| Lambda 1024MB | 134.85ms | 145.50ms | 166.09ms | 0% | $0.005527 | $1.54 |
| Fargate (256/512) | 119.91ms | 136.14ms | 172.73ms | 0% | $0.002057 | $0.57 |
| EC2 (t3.small) | 120.64ms | 131.68ms | 155.74ms | 0% | $0.007217 | $1.99 |

### Scenario C — High-Sustained (60 VUs ramped, uninterrupted, 10m 0s)

| Platform | p50 | p95 | p99 | Error Rate | Window Cost | Scaled Cost (per 1M req) |
|---|---|---|---|---|---|---|
| Lambda 128MB | 140.84ms | 159.46ms | 171.75ms | 0% | $0.005697 | $0.20 |
| Lambda 1024MB | 133.78ms | 147.77ms | 164.20ms | 0% | $0.044238 | $1.54 |
| Fargate (256/512) | 119.23ms | 149.12ms | **231.35ms** | 0% | $0.004114 | **$0.14** |
| EC2 (t3.small) | 120.77ms | 140.57ms | 177.47ms | 0% | $0.010683 | $0.37 |

> **Window Cost isn't comparable across scenarios** — test durations vary (4m 10s / 5m 0s / 10m 0s). Always compare using **Scaled Cost**.

### Crossover highlights

- **Cost:** Lambda 128MB stays flat at $0.20/1M req regardless of load; Fargate's cost per request *drops* as load rises ($0.60 → $0.57 → $0.14 from Low-Spiky → Medium-Steady → High-Sustained) because fixed capacity gets amortized over more requests. EC2 shows the same amortization effect ($2.10 → $1.99 → $0.37) but never becomes cost-competitive with Fargate on-demand.
- **Latency:** Fargate/EC2 post tighter p50/p95 than either Lambda tier at low-to-medium concurrency, but at High-Sustained scale Lambda 1024MB's p99 (164.20ms) actually beats Fargate's (231.35ms) — Lambda's horizontal scaling model handles the extreme tail better once volume is high enough.
- **Cold starts:** Lambda 1024MB's p99 in Low-Spiky (337.79ms) is roughly 2x its own steady-state p99 (166.09ms in Medium-Steady) — the clearest signature of idle-eviction cold starts in the whole dataset. Full deep-dive with max-latency traces in Section 3 of the report.

---

## Infrastructure Verification

### 1. Requests getting processed successfully
<img width="642" height="662" alt="Screenshot 2026-07-19 at 2 19 09 PM" src="https://github.com/user-attachments/assets/a348966e-e723-4b87-8f3c-12047c85f514" />

### 2. Healthy Target Groups
<img width="1217" height="666" alt="Screenshot 2026-07-20 at 6 23 56 PM" src="https://github.com/user-attachments/assets/3a914a54-35d2-48a7-bc42-f81b6215221b" />


<img width="1232" height="681" alt="Screenshot 2026-07-20 at 6 23 39 PM" src="https://github.com/user-attachments/assets/568d2fa4-07bf-422b-8265-1791de12bdac" />

### 3. Healthy Autoscaling Group
<img width="1225" height="494" alt="Screenshot 2026-07-20 at 6 25 49 PM" src="https://github.com/user-attachments/assets/031c0ac6-2043-4d72-9d00-666e2ff351f9" />

### 4. Populated DynamoDB Table
<img width="915" height="677" alt="Screenshot 2026-07-20 at 6 28 32 PM" src="https://github.com/user-attachments/assets/964770d6-c98c-44e0-9778-66f9659899a4" />

### 5. CI Manual Approval
<img width="1110" height="436" alt="Screenshot 2026-07-20 at 10 24 54 PM" src="https://github.com/user-attachments/assets/81f21bf9-4ec5-4b40-8e85-e1b7e87ab42c" />

### 6. Resources Created Successfully
<img width="1111" height="522" alt="Screenshot 2026-07-22 at 6 50 46 PM" src="https://github.com/user-attachments/assets/985b3108-108c-464f-9140-b37ad7930610" />

### 7. K6 in Action
<img width="1007" height="712" alt="Screenshot 2026-07-20 at 12 33 46 PM" src="https://github.com/user-attachments/assets/1fce715e-c4fe-4e2d-a6e3-c4e7d0c2a047" />

---

## Troubleshooting

### 1. Container Image Pull Failures
<img width="825" height="754" alt="Screenshot 2026-07-19 at 1 47 31 PM" src="https://github.com/user-attachments/assets/ff73f4ce-a2cc-4f41-98fd-e43b2c65fc4e" />

After deploying all infrastructure, Lambda endpoints returned 200 OK but Fargate and EC2 ALBs returned 503 Service Temporarily Unavailable and 502 Bad Gateway errors respectively.
 - ***Root cause***: The EC2 services were failing to start because the container image couldn't be pulled from ECR.
The EC2 instance profile was missing ECR permissions.
- ***Fix***: Attached AmazonEC2ContainerRegistryReadOnly to the EC2 instance profile:

### 2. AWS Lambda Concurrency Limit Exceeded
My AWS account had a default Lambda concurrency limit of 10 — the maximum number of Lambda functions that can be running simultaneously across all functions in a region. Each Lambda function consumes 1 concurrency unit per invocation. I was deploying two Lambda functions (128MB and 1024MB), but other resources in the account (from previous projects) were consuming the remaining concurrency, leaving no capacity for new functions.
- ***Fix***: Requested a service quota increase
- ***Response time***: ~2 hours (request was automatically approved)

---

## Project structure

```
compute-comparison/
├── scenarios/
│   ├── low-spiky.js           # k6 script: 20s burst / 90s idle x3 + cooldown
│   ├── medium-steady.js       # k6 script: 30s ramp + 4m hold + 30s ramp down
│   └── high-sustained.js      # k6 script: 1m ramp + 8m hold + 1m ramp down
├── targets/
│   ├── lambda-128mb/           # Lambda function config (128MB)
│   ├── lambda-1024mb/          # Lambda function config (1024MB)
│   ├── fargate/                # Fargate task definition (256/512)
│   └── ec2/                    # EC2 (t3.small) app deployment
├── results/
│   ├── low-spiky/               # Raw k6 JSON output + cost calculations per platform
│   ├── medium-steady/
│   └── high-sustained/
├── cost-model/
│   └── scaled-cost.py             # Normalizes window cost → cost per 1M requests
├── compute_comparison_build_guide.md   # Full analysis report (this repo's main deliverable)
└── README.md
```

---

## Tech stack

- **k6** for load generation and latency/error measurement
- **AWS**: Lambda (128MB & 1024MB), Fargate (256 vCPU / 512MB), EC2 (t3.small)
- **Cost normalization**: window cost → scaled cost per 1M requests, to compare across test durations of different lengths (4m 10s / 5m 0s / 10m 0s)

---

## Methodology notes 

1. **Cold-start behavior depends on more than memory size** — runtime choice, package size, VPC/ENI attachment, and region/time-of-day all matter and weren't isolated in this test.
2. **AWS doesn't publish its eviction policy.** The cold-start explanation in the report (Section 3) is an informed hypothesis based on observed latency patterns, not confirmed AWS internals.
3. **Throughput figures are estimated** from k6 VU/sleep configuration, not measured directly — provided for context, not as a primary benchmark metric.
4. **Window Cost vs. Scaled Cost:** because test durations differ (4m 10s / 5m 0s / 10m 0s), only the *scaled* (per 1M req) cost figures are valid for cross-scenario comparison — raw window costs are not.

---

## Getting started


### Prerequisites

- [k6](https://k6.io/docs/get-started/installation/) installed
- An AWS account with programmatic access configured (`aws configure`)
- Deployed targets for each platform under test (Lambda x2, Fargate, EC2) — see `targets/`

### 1. Deploy the four compute targets

Deploy each target environment (Lambda 128MB, Lambda 1024MB, Fargate, EC2) and note their invoke URLs/endpoints.

### 2. Point the k6 scripts at your endpoints

```
export TARGET_URL='https://your-endpoint-here'
```

### 3. Run a scenario against a platform

```
k6 run scenarios/low-spiky.js
k6 run scenarios/medium-steady.js
k6 run scenarios/high-sustained.js
```


## License

MIT — use this as a learning reference or a starting point for your own compute benchmarking.
