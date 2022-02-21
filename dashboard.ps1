. "./utils.ps1"

switch (choose "`n`n open (d)ashboard `n (i)nstall dashboard `n open (m)etrics `n (c)Advisor `n i(n)stall all `n ngin(x) scrape ? `n`n Choose one..." "m","d","c","i","n","x") {
  "c" {
    $port = 11111;
    foreach ($pod in getKubectlEntities "pod" "(cadvisor[^ ]+)" "cadvisor") {
      $comment = " opening cAdvisor from ${pod}:8080 to localhost:${port}";
      EX_async "kubectl --namespace cadvisor port-forward ${pod} ${port}:8080" $comment;
      $port = $port + 1;
    }    
  }
  "m" {
    $comment = " opening prometheus on localhost:9090";
    EX_async "kubectl --namespace default port-forward $(kubectl get pods --namespace default -l ""app=prometheus,component=server"" -o jsonpath=""{.items[0].metadata.name}"") 9090" $comment;
    $comment = " opening grafana on localhost:3000";
    $encoded = "$(kubectl get secret --namespace default grafana -o jsonpath=""{.data.admin-password}"")";
    $decoded = base64Decode $encoded;
    $comment += "`n credentials for grafana:  admin/${decoded}";
    $comment += "`n open metrics UI using 'http://localhost:3000'";
	$nginxPod = getKubectlEntity "pods" "(nginx-ingress-controller[^ ]+)" "ingress-basic"
	EX_async "kubectl --namespace ingress-basic port-forward $($nginxPod) 10254" $comment;
	$comment += "`n nginx prometheus stats on http://localhost:10254/metrics";
	$grafanaPod = getKubectlEntity "pods" "(grafana[^ ]+)"
    EX_async "kubectl --namespace default port-forward $($grafanaPod) 3000" $comment;
  }
  "d" {
    $comment = " Starting k8 dashboard proxy in this console, visit http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/login with browser";
    $comment += "`n Use token from below";    
    $comment += "`n ----------------------------------------------------------------------"
    EX_async "kubectl describe secret $(getKubectlEntity ""secret"" ""(default-token[^ ]+)""); kubectl proxy;" $comment;
  }
  "i" {
    gogo `
    "Installing dashboard component to cluster" `
    "kubectl create clusterrole defaultrole --verb=""*""  --resource=""*.*""", `
    "kubectl create rolebinding defaultbinding --clusterrole=""defaultrole"" --user=""system:serviceaccount:default:default"" -n default", `
    "kubectl create clusterrolebinding root-cluster-admin-binding --clusterrole=""cluster-admin"" --user=""system:serviceaccount:default:default""", `
    "kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml"
  }
  "n" {
    gogo `
    "Installing all dashboard components to cluster" `
    "kubectl apply -f libs/cAdvisor/", `
    "kubectl apply -f libs/metrics-server/1.8+/", `
    "kubectl create clusterrole defaultrole --verb=""*""  --resource=""*.*""", `
    "kubectl create rolebinding defaultbinding --clusterrole=""defaultrole"" --user=""system:serviceaccount:default:default"" -n default", `
    "kubectl create clusterrolebinding root-cluster-admin-binding --clusterrole=""cluster-admin"" --user=""system:serviceaccount:default:default""", `
    "kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml", `
    "helm install prometheus stable/prometheus -f libs/prometheus/values.yaml", `
    "helm install grafana stable/grafana";
  }
  "x" {
	Write-Host "----------------------------------"
	Write-Host "WARNING!!  Ensure the helm upgrade below contains all options from the heml install in ingress.ps1"
	Write-Host "----------------------------------"
	gogo `
	"Installing and verifying nginx scrape" `
	"helm get values nginx-ingress --namespace ingress-basic", `
	"helm upgrade nginx-ingress stable/nginx-ingress --namespace ingress-basic --set controller.replicaCount=2 --set controller.nodeSelector.""beta\.kubernetes\.io/os""=linux --set defaultBackend.nodeSelector.""beta\.kubernetes\.io/os""=linux --set controller.service.loadBalancerIP=""52.148.167.224"" --set controller.service.annotations.""service\.beta\.kubernetes\.io/azure-dns-label-name""=""overhide-io"" --set controller.metrics.enabled=true --set-string controller.podAnnotations.""prometheus\.io/scrape""=""true"" --set-string controller.podAnnotations.""prometheus\.io/port""=""10254"" --set controller.extraArgs.metrics-per-host=false", `
	"helm get values nginx-ingress --namespace ingress-basic";
  }
}

