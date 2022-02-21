. "./utils.ps1"

switch (choose "(t)est (p)rod) (s)tage?" "t","p","s") {
  "t" {
    $PROPS_FILE = ".\config\oh-ledger-test.props";
    $SECRETS_FILE = ".\secrets\oh-ledger-test.secrets.yaml";
  }
  "p" {
    $PROPS_FILE = ".\config\oh-ledger-prod.props";
    $SECRETS_FILE = ".\secrets\oh-ledger-prod.secrets.yaml";
  }
  "s" {
    $PROPS_FILE = ".\config\oh-ledger-stage.props";
    $SECRETS_FILE = ".\secrets\oh-ledger-stage.secrets.yaml";
  }
}

$username = select-string -Path $PROPS_FILE -Pattern "POSTGRES_USER=\s*([^\s]+)" -AllMatches | % { $_.matches.groups[1] } | % { $_.Value };
$hostname = select-string -Path $PROPS_FILE -Pattern "POSTGRES_HOST=\s*([^\s]+)" -AllMatches | % { $_.matches.groups[1] } | % { $_.Value };
$database = select-string -Path $PROPS_FILE -Pattern "POSTGRES_DB=\s*([^\s]+)" -AllMatches | % { $_.matches.groups[1] } | % { $_.Value };
$port = select-string -Path $PROPS_FILE -Pattern "POSTGRES_PORT=\s*([^\s]+)" -AllMatches | % { $_.matches.groups[1] } | % { $_.Value };
$password = select-string -Path $SECRETS_FILE -Pattern "POSTGRES_PASSWORD:\s*([^\s]+)" -AllMatches | % { $_.matches.groups[1] } | % { $_.Value };

switch (choose "`n`n (s)tage in `n (p)sql in `n (c)lean up `n`n Choose one... " "s","p","c") {
  "s" {
    Write-Host "kubectl run --image=governmentpaas/psql -i --tty --env=""PGPASSWORD=""""$password"""""" --env=""PGSSLMODE=""""require"""""" psql -- psql -h $hostname -U ""$username"" -p $port -d $database"
    kubectl run --image=governmentpaas/psql -i --tty --env="PGPASSWORD=""$password""" --env="PGSSLMODE=""require""" psql -- psql -h $hostname -U "$username" -p $port -d $database
  }

  "p" {
    Write-Host "kubectl exec -it $(getKubectlEntity ""pods"" ""(psql-[^ ]+)"") -- psql -h $hostname -U ""$username"" -p $port -d $database"
    kubectl exec -it $(getKubectlEntity "pods" "(psql-[^ ]+)") -- psql -h $hostname -U "$username" -p $port -d $database
  }

  "c" {
    Write-Host "kubectl delete pods psql"
    kubectl delete pods psql
  }
}
