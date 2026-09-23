# Performance test

Install k6 using the official instructions for your OS. Run against a disposable local or sandbox API only:

~~~powershell
k6 run loadtest/read-path.js
# For a sandbox endpoint, avoid embedding credentials in this URL.
$env:BASE_URL = "http://127.0.0.1:8000"
k6 run loadtest/read-path.js
~~~

The test creates one task then performs a bounded, 10-VU, two-minute read path. Defaults check p50 < 100 ms, p95 < 300 ms, p99 < 750 ms and errors < 1%; these are test thresholds, not measured results or an availability promise. k6 prints measured percentiles. Repeat with cache healthy and Redis stopped; record API latency, RDS connections/CPU, Redis CPU/evictions, pod CPU/memory, HPA replicas, and run conditions. Never run an unconstrained load test against production or a shared AWS account.

Increase concurrency gradually and change one variable at a time. A rise in tail latency can come from connection pool pressure, cold cache, database saturation, node CPU, network, or ALB. This simple test is a starting point and not a statistically complete benchmark.
