. "./utils.ps1"

switch (choose "(t)est (p)rod?" "t","p") {
  "t" {
    $PROPS_FILE = ".\config\oh-arma-test.props";
    $SECRETS_FILE = ".\secrets\oh-arma-test.secrets.yaml";
    $STATUS_URL = "https://test.rs.overhide.io/status.json";
  }
  "p" {
    $PROPS_FILE = ".\config\oh-arma-prod.props";
    $SECRETS_FILE = ".\secrets\oh-arma-prod.secrets.yaml";
    $STATUS_URL = "https://rs.overhide.io/status.json";
  }
}

$conf = load "./config/k8.props";
$conf = load $PROPS_FILE $conf;

$conf.'K8_IMAGE' = $conf.K8_IMAGE -f $conf.'PROJECT_ID';

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

$local_img = "overhide/armadietto:latest";
$repo_img = $conf.'K8_IMAGE' + ":" + $conf.'K8_VERSION';

switch (choose "`n`n do (i)mages `n (d)eployment `n (e)xec in `n (r)edeploy `n (f)ollow logs for deployment `n s(t)atus `n`n Choose one..." "i", "s", "d", "e", "r", "f", "t") {
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
  "d" {
    go `
    "Apply oh-arma?" `
    (genKubectlApply "k8s/oh-arma.yaml" $conf);

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
    "Redeploy oh-arma?" `
    (genKubectlApply "k8s/oh-arma.yaml" $conf);
  }
  "f" {
    EX("kubectl logs deployment/$($conf.'K8_NAME') --since=1h -f");
  }
  "t" {
    curl $STATUS_URL;    
  }
}