# Kubernetes SRE Incident Lab

A hands-on break/fix lab for practicing production troubleshooting on Kubernetes. It runs a small event-driven shop (REST API, Kafka, MySQL, MongoDB) on a local `kind` cluster, then breaks it in one of 24 realistic ways. Your job is to find the root cause with `kubectl`, logs and metrics, fix it, and write a short RCA, the same way you would during an on-call incident.

I built it to prepare for a live SRE troubleshooting interview, working alongside Claude (Anthropic) as a pairing partner: I ran, investigated and fixed every scenario myself.

> A detailed Hebrew guide with the full study notes is in [README.he.md](README.he.md).

## Architecture

```
loadgen ──HTTP──> orders-api ──INSERT──> MySQL
                      │            (HPA 2-6 pods, readiness checks MySQL)
                      └──produce──> Kafka (topic "orders", 3 partitions, KRaft)
                                        │
                                        └──consume──> orders-worker ──insert──> MongoDB
                                                      (consumer group "orders-worker")
```

- **One image, several roles** (`app/app.py`, Flask + kafka-python + PyMySQL + pymongo): `api`, `worker`, and a `hog` role used by a scenario.
- **Structured logs:** every log line is single-line JSON (`service`, `level`, `msg`, `error`, `dependency`, `client`, latency fields), so it is easy to search in Splunk, Datadog or `jq`.
- **Business config lives in data:** some behavior is driven by rows in MySQL (`app_settings`) and documents in MongoDB, so not every incident is visible in Kubernetes objects.
- **Health checks:** `/healthz` (process only) for liveness, `/ready` (runs `SELECT 1`) for readiness.

## Quick start

Requirements: Docker Desktop (or OrbStack/colima) with about 4 CPUs and 6 GB RAM, plus `kind`, `kubectl` and `jq`.

```bash
brew install kind kubectl jq
./setup.sh      # kind cluster, metrics-server, MySQL, MongoDB, Kafka, app (5-10 min first time)
./status.sh     # pods, HPA, endpoints, Kafka lag, last HTTP statuses
```

## How to practice

```bash
./break.sh            # random scenario, name hidden (closest to a real incident)
./break.sh list       # list scenarios
./break.sh 13         # a specific scenario
./reveal.sh hint      # a nudge
./reveal.sh solution  # full solution, prevention, and the equivalent on AWS
./reset.sh            # back to healthy
```

Each scenario has a `ticket.md` (what the "customer" reports), a `hint.md`, a `solution.md` (symptom, investigation commands, Splunk queries, fix, prevention) and the `break.sh` that causes it. Don't open `scenarios/` before trying: the folder names give the answer away.

**The method used throughout:** symptom → impact → what changed → outside-in → logs + metrics → hypothesis and proof → mitigate, then fix → verify → 3-line RCA.

## Scenarios

<details>
<summary>24 scenarios (spoilers)</summary>

| # | Area | What breaks |
|---|---|---|
| 01 | Secrets / DB | Wrong MySQL password in the API's Secret, pods crash-loop |
| 02 | Resources | Worker memory limit too low, OOMKilled (exit 137) |
| 03 | Scheduling | Huge CPU requests, new pods stuck in Pending |
| 04 | Networking | Service selector doesn't match pod labels, no endpoints |
| 05 | Probes | Readiness probe on a non-existent path plus `Recreate` strategy, full outage |
| 06 | Autoscaling | HPA shows `<unknown>` because CPU requests were removed |
| 07 | Deploy | Image tag that doesn't exist, ImagePullBackOff |
| 08 | Kafka | No consumers, lag grows |
| 09 | Kafka | Consumer subscribed to the wrong topic |
| 10 | Kafka | Poison message crash-loops the consumer (offset skip, DLQ discussion) |
| 11 | Kafka | Slow consumer, lag grows gradually |
| 12 | Secrets / Mongo | Wrong MongoDB password for the worker |
| 13 | SQL | Table lock held by a sleeping session (MySQL + SQL Server equivalents) |
| 14 | SQL | `max_connections` exhausted by a rogue service (MySQL + SQL Server equivalents) |
| 15 | Config | Wrong Kafka bootstrap port in a shared ConfigMap |
| 16 | Nodes | All worker nodes cordoned after maintenance |
| 17 | Mongo | MongoDB down |
| 18 | Mongo | Dropped index, COLLSCAN on 1.5M documents, latency only |
| 19 | Mongo | Worker user downgraded to read-only |
| 20 | Data config | Wrong business limit in a MySQL settings table, 422s with no deploy |
| 21 | Data config | Settings document in Mongo routes events to the wrong collection |
| 22 | Load | New client floods the API, HPA at max |
| 23 | Probes | Liveness probe checks the DB, a short DB restart becomes a long outage |
| 24 | Probes | Liveness too aggressive, app killed before it finishes starting (fixed with startupProbe) |

</details>

## Observability add-ons (`tools/`)

- **Splunk** (`tools/splunk/`): local Splunk in Docker plus `ship-logs.sh`, which ships pod logs and Kubernetes events through HEC. Includes the SPL queries used in the scenarios.
- **Datadog** (`tools/datadog/`): Helm install of the Agent (DaemonSet + Cluster Agent) with log collection.
- **Dynatrace** (`tools/dynatrace/`): notes for connecting the Operator / OneAgent.

## AWS extensions (`tools/eks/`, `tools/documentdb/`)

- **EKS** with `eksctl` (`cluster.yaml`): access entries, Pod Identity, kubeconfig and auth drills (401 vs 403), and a full CloudFormation-based teardown.
- **DocumentDB:** connecting from a pod with the CA bundle, `retryWrites=false`, and how it differs from MongoDB.

Lessons from actually running them, worth more than the happy path:

- **A timeout isn't a root cause.** `eksctl` reported only a timeout. The real error was in the CloudFormation stack events: the EC2 Fleet quota, because the AWS account was on hold.
- **Two failures can stack.** Fargate pods stayed Pending because the profile selector only covered `default` (`eksctl` kept only the last `--namespace` flag). After fixing that, the next layer appeared: `fargate-scheduler` reported the blocked account.
- **SCPs shape the design.** A Service Control Policy denying IAM OIDC providers ruled out IRSA, so the cluster uses EKS Pod Identity instead.

## Cleanup

```bash
kind delete cluster --name bootcamp
docker rm -f splunk               # if you used the Splunk add-on
helm uninstall datadog-agent -n datadog   # before deleting the cluster, if installed
```

For AWS, delete DocumentDB before EKS, then the eksctl CloudFormation stacks (disable termination protection first). Verify that no NAT gateways, Elastic IPs or volumes are left behind.

## Tech

Kubernetes (kind), Kafka 3.8 (KRaft), MySQL 8.4, MongoDB 7, Python/Flask, HPA and metrics-server, Splunk, Datadog, AWS EKS, eksctl, CloudFormation, DocumentDB.
