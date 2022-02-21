. "./utils.ps1"

switch (choose "(t)est (p)rod (s)tage?" "t","p","s") {
  "t" {
    $PROPS_FILE = ".\config\oh-bitcoin-test.props";
    $SECRETS_FILE = ".\secrets\oh-bitcoin-test.secrets.yaml";
    $STATUS_URL = "https://rinkeby.bitcoin.overhide.io/status.json";
  }
  "p" {
    $PROPS_FILE = ".\config\oh-bitcoin-prod.props";
    $SECRETS_FILE = ".\secrets\oh-bitcoin-prod.secrets.yaml";
    $STATUS_URL = "https://bitcoin.overhide.io/status.json";
  }
  "s" {
    $PROPS_FILE = ".\config\oh-bitcoin-stage.props";
    $SECRETS_FILE = ".\secrets\oh-bitcoin-stage.secrets.yaml";
    $STATUS_URL = "https://rinkeby-stage.bitcoin.overhide.io/status.json";
  }
}

$conf = load "./config/k8.props";
$conf = load $PROPS_FILE $conf;

$conf.'K8_IMAGE' = $conf.K8_IMAGE -f $conf.'PROJECT_ID';

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

$local_img = "oh-btc:latest";
$repo_img = $conf.'K8_IMAGE' + ":" + $conf.'K8_VERSION';

switch (choose "`n`n do (i)mages `n do (s)ettings `n (d)eployment `n (e)xec in `n (r)edeploy `n (f)ollow logs for deployment `n s(t)atus `n`n Choose one..." "i", "s", "d", "e", "r", "f", "t") {
  "i" {
    EX "docker images ${repo_img}";
    go `
    "Do you see old '${repo_img}' image above you want to delete before tagging?" `
    "docker rmi ${repo_img}";

    EX "docker images ${local_img}";
    go `
    "Do you see local image above?  Do you want to tag it for repo?" `
    "docker tag ${local_img} ${repo_img}";

    go `
    "Push out image?" `
    "docker push ${repo_img}";
  }
  "s" {
    gogo `
      "Create configmap $($conf.'K8_CONFIGMAP_NAME')" `
      "kubectl get configmap $($conf.'K8_CONFIGMAP_NAME') -o yaml", `
      "kubectl delete configmap $($conf.'K8_CONFIGMAP_NAME')", `
      "kubectl create configmap $($conf.'K8_CONFIGMAP_NAME') --from-env-file=${PROPS_FILE}";

    go `
    "You have the secrets installed?" `
    "kubectl get secrets $($conf.'K8_SECRETS') -o yaml"
  }
  "d" {
    go `
    "Apply oh-bitcoin?" `
    (genKubectlApply "k8s/oh-bitcoin.yaml" $conf);

    go `
    "Show logs?" `
    "kubectl logs -l app=$($conf.'K8_NAME')";
  }
  "e" {
    kubectl exec -it $(getKubectlEntity "pods" "($($conf.'K8_NAME')[^ ]+)") -- /bin/sh
  }
  "r" {
    $conf.'K8_DIRTY' = "$(Get-Date -Format o)";
    go `
    "Redeploy oh-bitcoin?" `
    (genKubectlApply "k8s/oh-bitcoin.yaml" $conf);
  }
  "f" {
    EX("kubectl logs deployment/$($conf.'K8_NAME') --since=1h -f");
  }
  "t" {
    curl $STATUS_URL;    
  }
}