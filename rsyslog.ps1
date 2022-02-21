. "./utils.ps1"

$conf = load "./config/k8.props";

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

switch (choose "`n`n (d)eployment `n (e)xec in `n (t)ail log `n (g)et volume space `n (f)ollow logs for deployment `n`n Choose one..." "d","e","t","g","f") {
  "d" {
    go `
    "Apply rsyslog?" `
    (genKubectlApply "k8s/rsyslog.yaml" $conf);

    gogo `
    "Show logs?" `
    "kubectl logs $(getKubectlEntity "pods" "(rsyslog-server[^ ]+)") rsyslog-server -f", `
    "kubectl logs $(getKubectlEntity "pods" "(rsyslog-server[^ ]+)") logrotate-rsyslog -f";
  }
  "e" {
    kubectl exec -it $(getKubectlEntity "pods" "(rsyslog-server[^ ]+)") -- /bin/sh
  }
  "t" {
    kubectl exec -it $(getKubectlEntity "pods" "(rsyslog-server[^ ]+)") -- tail -f /var/log/log
  }
  "g" {
    kubectl exec -it $(getKubectlEntity "pods" "(rsyslog-server[^ ]+)") -- /bin/sh -c df -h | out-string -stream | select-string "/var/log"
  }
  "f" {
    gogo `
    "Show logs?" `
    "kubectl logs $(getKubectlEntity "pods" "(rsyslog-server[^ ]+)") rsyslog-server -f", `
    "kubectl logs $(getKubectlEntity "pods" "(rsyslog-server[^ ]+)") logrotate-rsyslog -f";
  }
}