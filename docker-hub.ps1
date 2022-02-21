. "./utils.ps1"

$conf = load "./config/k8.props";
$conf = load "./config/docker-hub.props" $conf;
$conf = load "./secrets/docker-hub.props" $conf;

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

go `
"Add docker-registry regcred??" `
"kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=$($conf.USERNAME) --docker-password='$($conf.PASSWORD)' --docker-email=$($conf.EMAIL)";