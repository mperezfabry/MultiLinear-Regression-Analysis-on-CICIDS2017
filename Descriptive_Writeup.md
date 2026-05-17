# Descriptive Analysis: CICIDS2017 Network Traffic Dataset

## What is this data?

CICIDS2017 is a public dataset from the Canadian Institute for Cybersecurity. Each row is one network *flow* (a connection between two computers), with columns describing packet sizes, timing, TCP flags, and routing. Some flows are normal traffic; others are real attacks (DoS, port scans, brute-force) that researchers ran on purpose so they could be labeled. That ground truth is what makes the dataset useful for modeling.

For this project we kept two slices, both exported by `setup.R` after sampling ~250 rows per day-file, dropping infinities/NAs, and using stepwise BIC to pick informative features:

- **`mlr_data.csv`** — 1,611 *benign* flows, used to model `Flow.Bytes` (a baseline of "what normal looks like").
- **`glm_data.csv`** — 1,997 mixed flows (~19% attacks), used to predict `Attack_Flag`.

## Why this response variable?

Our original plan was `Flow.Bytes.s` (throughput) as the MLR response. The professor flagged that throughput is essentially derived from bytes and duration, so predicting it from related variables is part decomposition, part learning. We switched to `Flow.Bytes` on benign-only flows. The cybersecurity motivation: the MLR builds a statistical picture of "normal" traffic shape, and the logistic regression then learns where attacks deviate from that picture. The two models support each other.

## Variable groups

The raw CICIDS2017 file has ~80 columns. We grouped them so results are easier to discuss:

| Group | What it captures | Example |
|---|---|---|
| Packet size | how big packets are and how variable | `Avg.Fwd.Segment.Size`, `Packet.Length.Variance` |
| Rates | how fast bytes/packets move | `Flow.Bytes.s` |
| Timing | gaps between packets | `Bwd.IAT.Total`, `Bwd.IAT.Max` |
| Idle / active | quiet vs. active periods | `Active.Std`, `Idle.Min` |
| TCP flags | special control bits | `PSH.Flag.Count`, `URG.Flag.Count` |
| Ports | where traffic is going | `Destination.Port` |
| Flow shape | direction and balance | `Down.Up.Ratio`, `Init_Win_bytes_backward` |

## What the descriptive analysis showed

**1. Attack vs. benign distributions are visibly different.** Overlay density plots (`descriptive_density_plots.pdf`) show attack flows are wider and more skewed across `Destination.Port`, `Avg.Fwd.Segment.Size`, `Avg.Bwd.Segment.Size`, and `Packet.Length.Variance`.

**2. Where traffic goes matters.** Bucketing `Destination.Port` into IANA ranges — well-known (0–1023), registered (1024–49151), dynamic (49152–65535) — and testing against `Attack_Flag` with a chi-square gives χ² = 135.83, p ≈ 3e-30. Attacks land disproportionately on well-known service ports. This satisfies the two-categorical-variables requirement: `Port_Category` (predictor), `Attack_Flag` (response).

**3. Boxplots back it up.** Side-by-side boxplots (`descriptive_boxplots.pdf`) show large benign-vs-attack gaps in `Avg.Bwd.Segment.Size`, `Packet.Length.Variance`, and `Init_Win_bytes_backward`.

**4. Correlation pruning is already in place.** `setup.R` drops any feature pair with |r| > 0.9, so the datasets are well-behaved going into modeling.

## Practical caveat: large samples make everything "significant"

With ~2,000 observations almost any predictor will hit p < 0.05. The linear and logistic modeling sections therefore report *practical* significance (effect sizes on standardized predictors) alongside *statistical* significance. `Linear.R` includes a scaled-coefficient block that ranks predictors by how many bytes they actually move the response.

## Variable dictionary

Following the [Boston housing](https://stat.ethz.ch/R-manual/R-devel/library/MASS/html/Boston.html) format — name, source dataset, units where relevant, brief meaning.

**Response.** `Flow.Bytes` — total bytes in the flow (mlr_data, bytes; MLR response). `Attack_Flag` — 1 = attack, 0 = benign (glm_data, binary; logistic response).

**Packet size (bytes).** `Fwd.Packet.Length.Min` — smallest forward packet (glm_data). `Avg.Fwd.Segment.Size` — mean forward packet size (glm_data). `Avg.Bwd.Segment.Size` — mean backward packet size (both). `Bwd.Packet.Length.Min` — smallest backward packet (mlr_data). `Bwd.Packet.Length.Std` — SD of backward packet lengths (mlr_data). `Packet.Length.Variance` — variance of all packet lengths, bytes² (glm_data). `min_seg_size_forward` — minimum forward segment size (mlr_data).

**Counts.** `act_data_pkt_fwd` — forward packets carrying payload data (mlr_data). `PSH.Flag.Count` — packets with TCP PSH flag set (both). `URG.Flag.Count` — packets with TCP URG flag set (glm_data).

**Timing (microseconds).** `Active.Std` — SD of active periods (both). `Active.Max` — longest active period (mlr_data). `Idle.Min` — shortest idle period (glm_data). `Bwd.IAT.Total` — total inter-arrival time of backward packets (glm_data). `Bwd.IAT.Max` — max inter-arrival time of backward packets (glm_data).

**Flow shape / routing.** `Destination.Port` — TCP/UDP destination port, 0–65535 (glm_data). `Down.Up.Ratio` — backward bytes ÷ forward bytes (glm_data). `Init_Win_bytes_backward` — initial TCP receive window from server, bytes (glm_data).

## Files produced

`descriptive_density_plots.pdf`, `descriptive_boxplots.pdf`, `descriptive_correlation_plots.pdf`. Regenerate with `source("Descriptive.R")`.
