. "./utils.ps1"

$conf = load "./config/k8.props";
$conf = load "./config/oh-site.props" $conf;

$conf.'K8_IMAGE' = $conf.K8_IMAGE -f $conf.'PROJECT_ID';

Write-Host "CONFIG: `n$($conf.GetEnumerator() | sort name | Format-Table | Out-String)"

$local_img = "oh-site:latest";
$repo_img = $conf.'K8_IMAGE' + ":" + $conf.'K8_VERSION';

$conf.'K8_DIRTY' = "$(Get-Date -Format o)";

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

go `
"Apply oh-site?" `
(genKubectlApply "k8s/oh-site.yaml" $conf);

