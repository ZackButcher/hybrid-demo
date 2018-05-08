To deploy:
----------
Unfortunately parts of our deployment rely on IP addresses provisioned at runtime (specifically, we need the cluster IP addresses of the CoreDNS services in both clusters, and the external static IP addresses of the two cluster's ingresses). Therefore, we cannot deploy with a simple `make` command; we need a few steps with some waiting in between.
> TODO: poll the API server and block until IPs assigned, make the entire deploy runnable in a single `make deploy`.

1. In `Makefile`, set the `CLUSTER_A` and `CLUSTER_B` variables to the names of the kubeconfig context's for your two clusters (the names you'd pass as the `--context` arg to a `kubectl` command).

> Required once, ensure you have cluster admin permissions on both clusters (required to assign roles required by Istio):
> ```bash
> make cluster-roles
> ```

1. Deploy Istio:
```bash
make deploy.istio
```

1. Deploy CoreDNS:
```bash
make deploy.istio.cross-cluster.dns
```

1. Wait until `core-dns` is assigned a cluster IP and `istio-istioingressgateway` an external IP; this is easy to poll across both clusters by running:
```bash
make deploy.istio.cross-cluster --dry-run
```
and waiting for the output to contain IPs like shown below:
```bash
sed -e "s/INGRESS_IP_ADDRESS/192.168.99.1/g" \
		-e "s/CORE_DNS_IP/10.35.247.13/g" \
		./cluster-a/cross-cluster.yaml | \
	kubectl  --context="a" apply -f -
sed -e "s/INGRESS_IP_ADDRESS/192.168.99.2/g" \
		-e "s/CORE_DNS_IP/10.51.245.17/g" \
		./cluster-b/cross-cluster.yaml | \
	kubectl  --context="b" apply -f -
```
> TODO: this is the step to script, e.g. with a simple bash `while` loop, polling the API server to get the IP addresses.

1. Deploy the cross cluster config and the app itself.
```bash
make deploy.istio.cross-cluster deploy
```

1. Verify the deployment:
    1. Verify you can ingress into `CLUSTER_A`:
    ```bash
    INGRESS_IP_A=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CONTEXT_A})
    curl -v ${INGRESS_IP_A}/ -H "Host: test-server.svc.a.remote"
    ```
    1. Verify you can ingress into `CLUSTER_B`:
    ```bash
    INGRESS_IP_B=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CONTEXT_B})
    curl -v ${INGRESS_IP_B}/ -H "Host: test-server.svc.b.remote"
    ```
    1. Verify a pod in `CLUSTER_A` can call across to a pod in `CLUSTER_B`:
    ```bash
    INGRESS_IP_A=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CONTEXT_A})
    curl ${INGRESS_IP_A}/call -H "Host: test-server.svc.a.remote" -d "http://test-server.svc.b.remote"
    ```
    ```bash
    got response: &{200 OK 200 HTTP/1.1 1 1 map[Content-Length:[27] Content-Type:[text/plain; charset=utf-8] X-Envoy-Upstream-Service-Time:[7] Server:[envoy] Date:[Tue, 08 May 2018 02:25:38 GMT]] 0xc420152000 27 [] false false map[] 0xc420115400 <nil>}
    ```
    1. And finally the reverse, that `CLUSTER_B` can call into `CLUSTER_A`:
    ```bash
    INGRESS_IP_B=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CONTEXT_B})
    curl ${INGRESS_IP_B}/call -H "Host: test-server.svc.b.remote" -d "http://test-server.svc.a.remote"
    ```
    ```bash
    got response: &{200 OK 200 HTTP/1.1 1 1 map[Content-Length:[27] Content-Type:[text/plain; charset=utf-8] X-Envoy-Upstream-Service-Time:[7] Server:[envoy] Date:[Tue, 08 May 2018 02:25:38 GMT]] 0xc420152000 27 [] false false map[] 0xc420115400 <nil>}
    ```

----------------

Now services in `CLUSTER_B` can call services in `CLUSTER_A` using hostnames `<service name>.svc.a.remote` and services in `CLUSTER_A` can call those in `CLUSTER_B` using hostnames `<service name>.svc.b.remote`. Traffic can be split across clusters using Istio config targeting those hostnames. For example, the following config splits traffic 50-50 across two clusters:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: global-foo
spec:
  # Match the name `foo`; this is how other services address us
  hosts:
  - foo
  http:
  - route:
    # split the traffic evenly across the two actual `foo` services in our clusters
    - destination:
        host: foo.svc.a.remote
      weight: 50
    - destination:
        host: foo.svc.b.remote
      weight: 50
```