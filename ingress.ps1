. "./utils.ps1"

$conf = load "./config/k8.props";

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

$ingresses = @(
  "overhide-site",
  "pay2myapp-site",
  "prod-overhide-ledger",
  "test-overhide-ledger"
  "prod-overhide-ethereum",
  "prod-overhide-bitcoin",
  "prod-overhide-client-auth",
  "prod-overhide-ex-rate",
  "prod-overhide-social",
  "auth-ingress"
)

Write-Host "Ingresses configured in this PowerShell script:"
foreach ($ingress in $ingresses) { Write-Host "   $ingress" }
Write-Host "Ingresses configured in k8s/ingress.yaml:"
cat .\k8s\ingress.yaml | out-string -stream | select-string " name: "

if ((choose "Do ingresses in this script correspond to ingresses in k8s/ingress.yaml? (y)es or (n)o or CTRL-C" "y","n") -eq "n") {
  Write-Host "Please fix."
  exit;
}

switch (choose "Select: `n (i)nstall Helm/Tiller `n (t)abula rasa on cert-manager and nginx-ingress `n (n)ginx-ingress install `n dump nginx c(o)nfig `n (s)tatic IP setup `n (c)ert-manager setup `n S(e)tup issuer `n (d)eploy ingress `n (v)iew certs`n (p)atch ssl redirection `n (u)npatch ssl redirection `n De(b)ug `n`n" "i","t","n","o","s","c","d","e","v","p","u","b") {
  "i" { 
    go `
    "Did you download helm and put it in your path?  Will test below." `
    "helm version";
    gogo `
    "(non AKS) We're installing tiller for helm" `
    "kubectl create serviceaccount --namespace kube-system tiller", `
    "kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller", `
    "helm init --service-account tiller", `	
    "helm repo update";
    gogo `
    "(AKS) We're setting up helm" `
    "kubectl create namespace ingress-basic", `
    "helm repo add stable https://charts.helm.sh/stable";
  }
  "t" { 
    gogo `
    "(non AKS) Remove cert-manager and nginx-ingress helm packages?" `
    "helm list", `
    "helm delete --pur cert-manager", `
    "helm delete --purge nginx-ingress", `
    "helm repo update", `
    "helm reset", `
    "helm list";
    gogo `
    "(AKS) Remove cert-manager and nginx-ingress helm packages?" `
    "helm list --namespace ingress-basic", `
    "helm delete cert-manager --namespace ingress-basic", `
    "helm delete nginx-ingress --namespace ingress-basic", `
    "helm repo update", `
    "helm reset", `
    "helm list --namespace ingress-basic";
  }
  "n" {
    gogo `
    "(non AKS) Install nginx-ingress" `
    "helm install nginx-ingress stable/nginx-ingress -f libs/ingress/values.yaml", `
    "kubectl --namespace default get services -o wide -w nginx-ingress-controller";
    gogo `
    "(AKS) Install nginx-ingress" `
    "helm install nginx-ingress stable/nginx-ingress --namespace ingress-basic --set controller.replicaCount=2 --set controller.nodeSelector.""beta\.kubernetes\.io/os""=linux --set defaultBackend.nodeSelector.""beta\.kubernetes\.io/os""=linux --set controller.service.loadBalancerIP=""52.148.167.224"" --set controller.service.annotations.""service\.beta\.kubernetes\.io/azure-dns-label-name""=""overhide-io""", `
    "kubectl --namespace ingress-basic get services -o wide -w nginx-ingress-controller";
  }
  "o" {
    $which = getKubectlEntity "pods" "(nginx-ingress-controller-[^ ]+)";
    go `
    "Dump nginx config" `
    "kubectl exec -it $which cat /etc/nginx/nginx.conf";
  }
  "s" {
    Write-Host "This step is manual.`n`n";
    Write-Host "In Google Cloud Platform go to: ``GCP Hamburger Menu >> VPC Network >> External IP Addresses.  Change the *ingress* IP from Ephemeral to Static and ensure it's in use.`n`n";
    Write-Host "In Digital Ocean go to Load Balancers and get IP for the Load Balancer just created.  Make sure to run 'kubectl label nodes <node-name> type=gateway'"
    Write-Host "Setup DNS`n";
    gogo `
    "Are you ready to test above setup?" `
    "kubectl get svc", `
    "nslookup overhide.io", `
    "nslookup ledger.overhide.io";
  }
  "c" {
    gogo `
    "(AKS) Setting up cert-manager" `
    "kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml", `
    "kubectl label namespace ingress-basic cert-manager.io/disable-validation=true", `
    "helm repo add jetstack https://charts.jetstack.io", `
    "helm repo update", `
    "helm install cert-manager --namespace ingress-basic --version v0.13.0 jetstack/cert-manager";
    go `
    "Watch installed?  CTRL-C when done." `
    "kubectl get services -o wide --namespace ingress-basic -w";
  }
  "e" {
    go `
    "Setup issuer?" `
    (genKubectlApply "k8s/issuer.yaml" $conf);
  }
  "d" {
    gogo `
    "Deploying ingress" `
    (genKubectlSecret "basic-auth" "./secrets/auth"), `
    "kubectl get secret basic-auth -o yaml", `
    (genKubectlApply "k8s/ingress.yaml" $conf), `
    "kubectl get ingress -o yaml", `
    "curl http://overhide.io", `
    "curl http://test.ledger.overhide.io";
  }
  "v" {
    gogo `
    "View certificates" `
    "kubectl describe certificate pay2my-app-cert", `
    "kubectl describe secret pay2my-app-cert", `
    "kubectl describe certificate ohledger-com-cert", `
    "kubectl describe secret ohledger-com-cert", `
    "kubectl describe certificate overhide-io-cert", `
    "kubectl describe secret overhide-io-cert";
  }
  "p" {
    go `
    "view pre-patch ingress?" `
    "kubectl get ingress -o yaml";
    if ((choose "Should we patch? (y)es or (s)kip or CTRL-C" "y","s") -eq "y") {
      foreach ($ingress in $ingresses) {
        kubectl patch ingress $ingress --type json -p @'
- op: replace
  path: /metadata/annotations/"nginx.ingress.kubernetes.io~1ssl-redirect"
  value: "\"true\""
'@;
      }
      kubectl patch ingress auth-ingress --type json -p @'
- op: add
  path: /metadata/annotations/"nginx.ingress.kubernetes.io~1auth-type"
  value: "\"basic\""
'@;
    }
    go `
    "view post-patch ingress?" `
    "kubectl get ingress  -o yaml";
  }
  "u" {
    go `
    "view pre-patch ingress?" `
    "kubectl get ingress -o yaml";
    if ((choose "Should we un-patch? (y)es or (s)kip or CTRL-C" "y","s") -eq "y") {
      foreach ($ingress in $ingresses) {
        kubectl patch ingress $ingress --type json -p @'
- op: replace
  path: /metadata/annotations/"nginx.ingress.kubernetes.io~1ssl-redirect"
  value: "\"false\""
'@;
      }
      kubectl patch ingress auth-ingress --type json -p @'
- op: remove
  path: /metadata/annotations/"nginx.ingress.kubernetes.io~1auth-type"
  value: "\"basic\""
'@;
    }
    go `
    "view post-patch ingress?" `
    "kubectl get ingress -o yaml";
  }
  "b" {
    Write-Host @'
  kubectl get pods -n <namespace-of-ingress-controller>
  kubectl exec -it -n <namespace-of-ingress-controller> nginx-ingress-controller-67956bf89d-fv58j cat /etc/nginx/nginx.conf
'@
  }
}