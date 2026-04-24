param(
  [ValidateSet("docker", "k8s")]
  [string]$Mode = "docker",
  [string]$Target = "redis",
  [string]$Namespace = "default",
  [int]$OutageSeconds = 10
)

if ($Mode -eq "docker") {
  docker stop $Target
  Start-Sleep -Seconds $OutageSeconds
  docker start $Target
  exit $LASTEXITCODE
}

kubectl -n $Namespace scale deployment $Target --replicas=0
Start-Sleep -Seconds $OutageSeconds
kubectl -n $Namespace scale deployment $Target --replicas=1
