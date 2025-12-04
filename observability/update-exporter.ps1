# Update Policy Metrics Exporter
Write-Host "Updating Policy Metrics Exporter..." -ForegroundColor Cyan

# Apply the updated Python file via ConfigMap
kubectl create configmap policy-exporter-code --from-file=policy-metrics-exporter.py=F:\sanal_thesis\observability\policy-metrics-exporter.py -n monitoring --dry-run=client -o yaml | kubectl apply -f -

Write-Host "ConfigMap updated. Now updating the deployment..." -ForegroundColor Yellow

# Update deployment to use ConfigMap
$deployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: policy-metrics-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: policy-metrics-exporter
  template:
    metadata:
      labels:
        app: policy-metrics-exporter
    spec:
      serviceAccountName: policy-exporter
      containers:
      - name: exporter
        image: python:3.11-slim
        command: ["/bin/sh", "-c"]
        args:
          - |
            pip install prometheus-client kubernetes && \
            python /app/policy-metrics-exporter.py
        ports:
        - containerPort: 9091
          name: metrics
        volumeMounts:
        - name: code
          mountPath: /app
      volumes:
      - name: code
        configMap:
          name: policy-exporter-code
"@

$deployment | kubectl apply -f -

Write-Host "Deployment updated. Waiting for rollout..." -ForegroundColor Yellow
kubectl rollout status deployment/policy-metrics-exporter -n monitoring --timeout=60s

Write-Host "`nChecking pod status..." -ForegroundColor Cyan
kubectl get pods -n monitoring -l app=policy-metrics-exporter

Write-Host "`nWaiting 15 seconds for metrics to generate..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "`nChecking pod logs..." -ForegroundColor Cyan
kubectl logs -n monitoring -l app=policy-metrics-exporter --tail=30
