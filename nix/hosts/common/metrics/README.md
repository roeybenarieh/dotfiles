# My metrics stack

Currently:

- Prometheus & Fluentbit sends to Grafana Alloy(Otel collector distribution)
- Alloy sends logs to loki.
- Grafana gets data from loki and prometheus
