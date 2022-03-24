<p align="center"><a href="https://overhide.io"><img src="./.github/logo.png" width="200px"/></a></p>
<p align="center"><a href="https://overhide.io">overhide.io</a></p><p style="width: 500px; margin: auto">A free and fully open-sourced ecosystem of widgets, a front-end library, and back-end services &mdash; to make addition of "logins" and "in-app-purchases" (IAP) to your app as banal as possible.</p>
<hr/>
These are deployment notes supporting the scripts here-in to aid in [overhide](https://github.com/overhide) services deployments.

Everything is using `kubectl` and `powershell`.  Adopt as you please.

Once you study the scripts, if you have questions, please come to [r/overhide](https://www.reddit.com/r/overhide/) on reddit.



# Introduction

All YAML files for Kubernetes are in `/k8s`

As much as possible, k8s touchpoints are codified in `/*.ps1` PowerShell scripts, mentioned below in "New Setup Checklist" in context.

All redacted configurations for containers are in `/config`

The YAML files in `/k8s` reference some configurations in `/config` (the `K8_*` prefixed ones).

Running containers used the rest of the values in `/config` at runtime, form their environment.

All redacted secrets for containers are in `/secrets`; YAML files that end up as k8s secrets.



# Setup Checklist



## 1. Install Tools / Main Setup Notes

The *overhide* cluster started on GCP, then moved to DigitalOcean, then moved to Azure.  The deployment should be generic where possible and only specific where necessary.  Actual Az specific bits are omitted.  You should be able to install on any k8s cluster however, managed or not.



Install `kubectl` (install AZ cli).

> - install az cli
> - install [choco](https://chocolatey.org/install)
> - install kubectl: `choco install kubernetes-cli`
> - connect kubectl to ms
> - `az aks install-cli`
> - `az aks get-credentials --admin --name overhide-k8s --resource-group overhide`

Download `config.yaml` file from Digital Ocean into `~\.kube`.

Run: `${env:KUBECONFIG}="~\.kube\config.yaml"` before running commands.

Get cluster config from cloud provider: after initiating cluster.

Merge above cluster config with `~/.kube/config`

When installing nginx with `ingress.ps1` do not restrict *nginx-ingress* to nodes with type=gateway.  Install the 
nginx controller and afterwards grab the load balancer IP from DigitalOcean console.



## 2. Setup Kubernetes Cluster

#### New Node / Replace Node

Determine if the new node will/could run nginx balancer (or this is a replacement node for node that ran nginx balancer).  

If external IP might balance to this node, then label as per below.

```
kubectl get nodes
kubectl label nodes <node-name> type=gateway
```



## 3. Setup Managed DB

Most services interact with Postgres.  

See `/config` files for `POSTGRES*`  config points:

```
POSTGRES_HOST=..
POSTGRES_PORT=5432
POSTGRES_DB=prod
POSTGRES_USER=..
POSTGRES_SSL=true
```

See `/secrets` files for private config points:

```
POSTGRES_PASSWORD: ..
```

Files in `/config` and `/secrets` are redacted:  provide your own values.

We usually run managed Postgress.

#### Database Notes

##### Sizes

```
SELECT nspname || '.' || relname AS "relation",
    pg_size_pretty(pg_relation_size(C.oid)) AS "size"
  FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
  WHERE nspname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_relation_size(C.oid) DESC
  LIMIT 20;
```

Each service has it's own DB evolutions `npm` script, see each individual service.

To work with the managed DB we run `./psql.ps1`, then:

```
\c ohledger
\dt
```



## 4. Setup Redis

Some services interact with Redis.

Look for `redis://redis:6379` configurations in `/config`.

To setup/manager:

``` 
./redis.ps1
```

Study/follow prompts.



## 5. Connect Cluster to Docker-Hub

Thus far we've been using  a private Docker-Hub repo for all our services.

You can use whatever container registry, we just happen to use a private Docker-Hub account.

To let your k8s cluster talk to the private docker-hub, login into Docker-Hub private repo: `docker login`

https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

Run: `./docker-hub.ps1`



## 6. Setup Secrets

Secrets live in `/secrets`.

All secrets are redacted as checked in:  provide your own values.

Secrets are installed into cluster using:

```
./secrets.ps1
```

Study/follow prompts.



## 7. Setup Load Balancing

The files involved are:

```
./k8s/ingress.yaml
./k8s/issuer.yaml
./ingress.ps1
./secrets/auth
```

You'll need to run through `./ingress.ps1` to setup certs and *nginx-ingress*.  Steps are mostly in-order.

See for more:

* https://github.com/kubernetes/ingress-nginx
* https://cert-manager.readthedocs.io/en/latest/getting-started/2-installing.html

Run `./ingress.ps1` and follow the steps:

1. (i)nstall Helm/Tiller
1. (n)ginx-ingress install
1. (s)tatic IP setup
1. (c)ert-manager setup
1. S(e)tup issuer 
1. (d)eploy ingress
1. (v)iew certs
1. (p)atch ssl redirection

If you need to refresh *cert-manager* or *nginx-ingress* use option *(t)abula rasa*.

There is a *basic auth* ingress that uses the secret from `./secrets/auth`.  It's not really used.  Was setup at one point for *stage* oh-ledger but we don't run those nodes anymore.



## 8. Push Services

The following scripts are used to push out the various services:

```
./oh-bitcoin.ps1
./oh-client-auth.ps1
./oh-ethereum.ps1
./oh-ex-rate.ps1
./oh-ledger.ps1
./oh-social.ps1
./oh-arma.ps1
```

Each service script has similar prompts for *test* and *prod* containers.  They share a k8s cluster.

Specific notes below.

#### Deploy *overhide-ledger*

Ensure you have a fresh *overhide-ledger* container:

* go to *overhide-ledger* repo
* `npm run build`

Run `./oh-ledger.ps1`.

##### Evolve

Run `./oh-ledger.ps1`.

Choose `(e)xec in`.

Execute `npm run db-evolve` in container's shell.

##### psql

Run `./psql.ps1`.

```
\c ohledger
\dt
```

##### Migration

See [aks\README.md](aks\README.md)

* `exec` into psql machine
* set password
* `pg_dump` DB
* copy DB to local machine
* copy DB to *psql* node in new cluster
* `psql` DB into new database

```
kubectl exec -it <source cluster psql pod> == /bin/sh
export PGPASSWORD=<password from oh-ledger-*.secrets.yaml>
pg_dump -U <user from oh-ledger-*.props> -h <db host from oh-ledger-*.props> -p <db port from oh-ledger-*.props> > \dump.sql
exit
kubectl cp <source cluster psql pod>:/dump.sql .
kubectl cp dump.sql <target cluster psql pod>:/
kubectl exec -it <target cluster psql pod> == /bin/sh
psql -h <db host from oh-ledger-*.props for new cluster> -U <user from oh-ledger-*.props for new cluster> -p <port from oh-ledger-*.props for new cluster> < /dump.sql
```

#### Deploy *overhide-ethereum*

Ensure you have a fresh *overhide-ethereum* container:

* go to *overhide-ethereum* repo
* `npm run build`

Run `./oh-ethereum.ps1`.

#### Deploy Armadietto + Lucchetto

Overhide deployed [RemoteStorage](https://remotestorage.io/) instance based off of [Armadietto + Lucchetto](https://github.com/overhide/armadietto/tree/master/lucchetto).

- pay attention to the PVC created as part of these deployments:
  - they're `ReadWriteMany`
  - should be on premium SSD

## 9. Monitoring

#### Logs

Deployment logs:

```
kubectl logs deployment/<name-of-deployment> # logs of deployment
kubectl logs -f deployment/<name-of-deployment> # follow logs
```

#### Dashboard

Reference https://github.com/kubernetes/dashboard.

Run `./dashboard.ps1`

Pushes dashboard to cluster and allows its use.

Dashboard link in browser:  http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/job?namespace=default

##### metrics-server

installs with `./dashboard.ps1`

```
kubectl top nodes
kubectl top pods
```

#### Logging

All services are configured for Azure's *application insights* however that's too expensive for our current funding of the *overhide* FOSS.  

As such, all Azure *application insights* logging is disabled.  But, enable it in your deployment if you're on Az.

See the `insights.js` files in the various services.

Configuration has been removed, but all you need is jus the `INSIGHTS_KEY` configuration in your secrets files.  It should work out of the box after that.



For now, we just do simple logging as per below.



Log a whole deployment

```
kubectl logs deployment/oh-ledger-prod --tail 100 --follow
```

##### rsyslog

Run `./rsyslog.ps1`

Installs *rsyslog-server*, *rsyslog-server-service*.

*rsyslog-server* has logs in `/var/log`.

*rsyslog-server* pod has 2 containers, *rsyslog-server* and *logrotate-rsyslog*.

Also installs *logrotate* as *DaemonSet* (one pod on each cluster node) to logrotate *Docker* logs--any *.log files on the host machine in:

* /var/lib/docker/containers
* /var/log/docker
* /var/log/containers/



Use `./rsyslog.ps1` then `(t)ail` to tail all logs.



Also see the Grafana / Prometheus section below for metrics.



##### ~~overhide-ledger LOG (archvie)~~

*rsyslog* logs have audit information for database writes.

These are useful for replay should the managed database fail.

The logs are written as lines containing `database-event`.

Extract the last logs:

```
./rsyslog.ps1
(e)xec in

# grep -h 'database-event' /var/log/*oh-ledger-prod* /var/log/old.logs/*oh-ledger-prod* | sort > LOG
# exit

. ./utils.ps1
$POD = getKubectlEntities 'pod' '(rsyslog-server-[^ ]+)'
kubectl cp ${POD}:/LOG . -c rsyslog-server
```

The `grep` command runs on current and old logs.  All logs are sorted by timestamp.  All logs are written to the `LOG` file.

The `kubectl` commands copy the `LOG` file to local drive.



## Admin Cheat-sheet

#### k8s

Connect to pod 

```
kubectl get pods
kubectl exec -ti oh-site... /bin/sh
```

#### redis

```
./redis.ps1

  > (e)exec in

# redis-cli

  > info
  > exit
```

#### redis-cli Cheatsheet

https://redis.io/commands

```
keys *
```



#### Grafana / Prometheus

Install using `./dashboard.ps1` option (i)nstall.

Notice that we use a custom `libs/prometheus/values.yaml`, look for "# JTN ::" in the file for my changes.

Also install nginx scraping from `./dashboard.ps1` (x)\

> !WARNING!  Ensure to compare the `helm upgrade nginx-ingress stable/nginx-ingress..` to most recent values from `helm install ...` in `ingress.ps1`.  This is not a patch.  This `upgrade` overwrites.  If you don't have all the values, some will be missing.  The (x) command runs `helm get values nginx-ingress` before and after for this reason.

Suggested Grafana dashboards in `libs/grafana/*.json`

Best one is `libs/grafana/nginx.json`

> To import, 
>
> - ensure you're connected to grafana using `./dashboard.ps1` `open (m)etrics`, follow the in-console prompts
> - in grafana UI, once logged in using password from PS1 console, create a prometheus source:  Data Sources > Add > Prometheus > http://localhost:9090 + Access: Browser > Save + Test
> - import nginx.json (below) dashboard

* https://github.com/kubernetes/ingress-nginx/tree/main/deploy/grafana/dashboards
* see https://github.com/Thakurvaibhav/k8s/tree/master/monitoring/dashboards

Run using `./dashboard.ps1` option to run (m)etrics.

Open Grafana with credentials from new console: *http://localhost:3000*.

Debug metrics right in prometheus:  http://localhost:9090/graph

#### Troubleshooting

Port-forward *nginx-ingress* metrics:  `kubectl port-forward <nginx-ingress pod> 10254`

Check for metrics: http://localhost:10254/metrics





## FAQ

#### Cluster Pods Going Haywire

Check for node that's in `NotReady` state: `kubectl get nodes`.

Check if node has any event messages: `kubectl describe node`.

Access *kubelet* logging: ssh into node and run `journalctl -u kubelet`.

Delete last deployment.

Recycle bad node using DigitalOcean *recycle* button from kubernetes menu.