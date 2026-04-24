param(
  [ValidateSet("docker", "k8s")]
  [string]$Mode = "docker",
  [string]$Target = "sfu",
  [string]$Namespace = "default",
  [int]$RestartAfterSeconds = 15
)

if ($Mode -eq "docker") {
  docker stop $Target
  Start-Sleep -Seconds $RestartAfterSeconds
  docker start $Target
  exit $LASTEXITCODE
}

kubectl -n $Namespace delete pod -l "app=$Target"
