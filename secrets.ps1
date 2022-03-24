. "./utils.ps1"

$conf = load "./config/k8.props";

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

# add each secret file below explicitly to check for availability
$secrets = @(
  "secrets/oh-arma-test.secrets.yaml",
  "secrets/oh-arma-prod.secrets.yaml",
  "secrets/oh-client-auth-stage.secrets.yaml",
  "secrets/oh-client-auth-prod.secrets.yaml",
  "secrets/oh-ledger-test.secrets.yaml", 
  "secrets/oh-ledger-stage.secrets.yaml",
  "secrets/oh-ledger-prod.secrets.yaml",
  "secrets/oh-ethereum-stage.secrets.yaml",
  "secrets/oh-ethereum-test.secrets.yaml",
  "secrets/oh-ethereum-prod.secrets.yaml",
  "secrets/oh-bitcoin-test.secrets.yaml",
  "secrets/oh-bitcoin-prod.secrets.yaml",
  "secrets/oh-ex-rate-stage.secrets.yaml",
  "secrets/oh-ex-rate-test.secrets.yaml",
  "secrets/oh-ex-rate-prod.secrets.yaml",
  "secrets/oh-social-prod.secrets.yaml"
)

foreach ($secret in $secrets) {
  Write-Host "Does ""$secret"" exist? :: " (Test-Path $secret -PathType Leaf)
}

foreach ($secret in $secrets) {
  go `
  "Apply secret?" `
    (genKubectlApply $secret $conf);
}