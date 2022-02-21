function EX ($what) {
	Write-Host "`n:: $(Get-Date -Format g) >> ``$what``";
	iex $what;
}

#
# $what is the command to run
# $comment is an additional comment to write out in the new console, instructions perhaps
#
function EX_async ($what, $comment) {  
  $msg = "`n:: $(Get-Date -Format g) [asyc] >> ``$what``";  
  if (! [string]::IsNullOrEmpty($comment)) {
    $msg = "$comment `n $msg";
  }
  invoke-expression "cmd /c start powershell -Command { Write-Host '$msg'; $what }"
}

#
# Check if variable set and wrtie error if not set else show value;  returns 'true' if exists.
#
# check "env:FOO";
#
function check($var) {
  $exists = Test-Path ${var};
  if ($exists) {
    $val = (get-item $var).Value;
    $exists = [string]::IsNullOrEmpty($val)
  }
  if (! $exists) { 
    Write-Host "ERROR: ${var} *needs* to be set"; 
  } else {    
    Write-Host "${var} => ${val}"; 
  }
  return $exists
}

#
# Loads props from file and optionally ammend to $ammendTo object
#
# $props = load "./conf.props";
# Write-Host "$($props.'PROJECT_ID')";
#
function load($file, $ammendTo) {
  $props = convertfrom-stringdata (get-content $file -raw)
  if ($ammendTo -ne $null -and $ammendTo -is [Hashtable]) {
    foreach ( $key in $ammendTo.keys){
      $props.$key = $ammendTo["${key}"];        
    }
  }
  return $props;
}

#
# Perform $cmd if $question answered with "y"es and not "s"kip, returns 'true' if performed
#
# go "Deploy?" "kubectl apply -f ...";
# 
function go ($question, $cmd) {
  do { $answer = Read-Host "`n:: $(Get-Date -Format g) :: ${question}`n${cmd}`n(y)es, (s)kip, or CTRL-C" } 
  until ("y","s" -contains $answer)
  if ($answer -eq "y") {
    EX $cmd;
    return $true;
  }
}

#
# Same as 'go' except takes a list of commands
#
function gogo($question, $cmds) {
  $step = 1;
  foreach ( $cmd in $cmds){
    go "$question (STEP $step)" $cmd;
    $step += 1;
  }
}

#
# Provide a choice with a $question and array of $choices, returns answer.
#
#
# switch (choose 'enter (x) (y)' "x","y") {
#  "x" { Write-Host "good"; }
#  "y" { Write-Host "bad"; }
#}
#
function choose ($question, $choices) {
  Write-Host "`n";
  do { $answer = Read-Host "`n:: $(Get-Date -Format g) :: ${question} or CTRL-C" } 
  until ($choices -contains $answer)
  return $answer
}


###################################################

#
# Generate kubectl statement for ConfigMap with name $name from hashtable $props
#
# Creates config map so it can be used in deployment > spec > template > spec:
#        envFrom:
#        - configMapRef:
#            name: oh-site-config
#
function genKubectlConfigMap($name, $props) {
  $result = "kubectl create configmap $name ";
  foreach ( $key in $props.keys){
    $result += " --from-literal=$($key)=$($props.${key})";        
  }
  return $result;
}

#
# Generate kubectl statement for 'secret' with name $name from $file
#
function genKubectlSecret($name, $file) {
  $result = "kubectl create secret generic $name --from-file=$file";
  return $result;
}

#
# Creates a kubectl apply statement from a definition $file after substituting $props
#
function genKubectlApply($file, $props) {
  $def = (Get-Content $file) -join "`n";
  foreach ( $key in $props.keys ){
    $def = $def.replace("`$${key}", $props.${key});        
  }
  return "`'$def`' | kubectl apply -f -";
}

#
# Retrieve all entities such as secrets or a pods
#
# @param which - e.g. "pods", "secrets", "deployments"
# @param regex - with one group to return e.g. '(some-pod-name[^ ]+)'
#
function getKubectlEntities($which, $regex, $namespace) {
  if ([string]::IsNullOrEmpty($namespace)) {
    $namespace = "default";
  }
  return kubectl -n $namespace get $which | select-string -Pattern $regex -AllMatches | % { $_.matches.groups[1] } | % { $_.Value }
}

#
# Retrieve an entity such as a secret or a pod, retrieves first one
#
# @param which - e.g. "pods", "secrets", "deployments"
# @param regex - with one group to return e.g. '(some-pod-name[^ ])+'
#
function getKubectlEntity($which, $regex, $namespace) {
  return getKubectlEntities $which $regex $namespace | Select -First 1
}

function base64Decode($what) {
  return  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(${what}))
}