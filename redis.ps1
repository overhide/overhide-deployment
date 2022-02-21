. "./utils.ps1"

$conf = load "./config/k8.props";
$conf = load "./config/redis.props" $conf;

$conf.'K8_IMAGE' = $conf.K8_IMAGE -f $conf.'PROJECT_ID';

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

switch (choose "`n`n (r)edeployment `n (e)xec in `n`n Choose one..." "r","e") {
  "r" {
    $conf.'K8_DIRTY' = "$(Get-Date -Format o)";
    go `
    "Apply oh-site?" `
    (genKubectlApply "k8s/redis.yaml" $conf);
  }
  "e" {
    kubectl exec -it $(getKubectlEntity "pods" "(redis[^ ]+)") -- /bin/sh
  }
}


