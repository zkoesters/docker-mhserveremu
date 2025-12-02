Kubernetes Examples

This directory contains ready-to-use Kubernetes examples for running `mhserveremu` with different ingress controllers, all driven by `kustomize` overlays.

Ingress variants provided:
- Contour (Gateway API)
- Contour (HTTPProxy)
- Traefik (IngressRoute)
- Traefik (Ingress)
- Traefik (Gateway API)
- NGINX (Ingress)
- NGINX (Gateway API)

Prerequisites:
- A working Kubernetes cluster (Kind, k3s, Minikube, or cloud)
- `kubectl` and `kustomize`
- Permissions to install CRDs and cluster-wide resources (ingress controllers)

What the examples deploy:
- Namespace: `mhserveremu`
- Application `Deployment` and `Service` for `mhserveremu`
- `ConfigMap` with static assets for the `mhserveremu-static` service
- TLS certificate managed by cert-manager via a cluster-wide self-signed `ClusterIssuer`, stored in Secret `mhserveremu-tls`
- An ingress layer depending on the chosen controller

Quick start:
1. Apply the common application base (workloads, service, cert-manager resources, configmap):
   - `kustomize build --load-restrictor='LoadRestrictionsNone' --enable-helm deploy/kubernetes/examples/common/ | kubectl apply --server-side -f -`
2. Choose ONE ingress option and apply it:
   - Contour (Gateway API):
     - `kustomize build --enable-helm deploy/kubernetes/examples/contour/ | kubectl apply --server-side --wait -f -`
     - `kustomize build --enable-helm deploy/kubernetes/examples/contour/gateway/ | kubectl apply --server-side --wait -f -`
   - Contour (HTTPProxy):
     - `kustomize build --enable-helm deploy/kubernetes/examples/contour | kubectl apply --server-side --wait -f -`
     - `kustomize build --enable-helm deploy/kubernetes/examples/contour/httpproxy/ | kubectl apply --server-side --wait -f -`
   - Traefik (IngressRoute):
     - `kustomize build --enable-helm deploy/kubernetes/examples/traefik/ | kubectl apply --server-side --wait -f -`
     - `kustomize build --enable-helm deploy/kubernetes/examples/traefik/ingressroute/ | kubectl apply --server-side --wait -f -`
   - Traefik (Ingress):
     - `kustomize build --enable-helm deploy/kubernetes/examples/traefik/ | kubectl apply --server-side --wait -f -`
     - `kustomize build --enable-helm deploy/kubernetes/examples/traefik/ingress/ | kubectl apply --server-side --wait -f -`
   - Traefik (Gateway API):
     - `kustomize build --enable-helm deploy/kubernetes/examples/traefik/ | kubectl apply --server-side --wait -f -`
     - `kustomize build --enable-helm deploy/kubernetes/examples/traefik/gateway/ | kubectl apply --server-side --wait -f -`
   - NGINX (Ingress):
     - `kustomize build --enable-helm deploy/kubernetes/examples/nginx/ | kubectl apply --server-side --wait -f -`
     - `kustomize build --enable-helm deploy/kubernetes/examples/nginx/ingress/ | kubectl apply --server-side --wait -f -`
   - NGINX (Gateway API):
     - `kustomize build --enable-helm deploy/kubernetes/examples/nginx/ | kubectl apply --server-side --wait -f -`
     - `kustomize build --enable-helm deploy/kubernetes/examples/nginx/gateway/ | kubectl apply --server-side --wait -f -`

DNS and TLS:
- Hostnames used by all variants:
  - `mhserveremu.localdev`
  - `static.mhserveremu.localdev`
  - `fe.mhserveremu.localdev`
- TLS is terminated at the ingress using the `mhserveremu-tls` secret issued by cert-manager.
- For local clusters without DNS, map the hostname(s) to your ingress IP (example: Kind with a LoadBalancer or Minikube):
  - Get the external IP/hostname of the ingress Service and add entries to `/etc/hosts`, e.g.:
    - `203.0.113.10 mhserveremu.localdev static.mhserveremu.localdev`
    - `203.0.113.11 fe.mhserveremu.localdev`

Finding the ingress address:
- Contour:
  - `kubectl get svc -n ingress-system -l app.kubernetes.io/name=contour -o wide`
- Traefik:
  - `kubectl get svc -n ingress-system -l app.kubernetes.io/name=traefik -o wide`
- NGINX:
  - `kubectl get svc -n ingress-system -l app.kubernetes.io/name=ingress-nginx -o wide`

Verify the deployment:
- Auth path (rewritten by the route from `/AuthServer` to `/`):
  - `curl -X POST -k -I https://mhserveremu.localdev/AuthServer/`
- Static assets:
  - `curl -k -I -L http://static.mhserveremu.localdev/SiteConfig.xml`

Cleanup (apply only what you used):
```shell
kustomize build --enable-helm deploy/kubernetes/examples/contour/gateway/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/contour/httpproxy/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/traefik/ingressroute/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/traefik/ingress/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/traefik/gateway/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/nginx/ingress/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/nginx/gateway/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/contour/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/traefik/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --enable-helm deploy/kubernetes/examples/nginx/ | kubectl delete --ignore-not-found --wait -f -
kustomize build --load-restrictor='LoadRestrictionsNone' --enable-helm deploy/kubernetes/examples/common/ | kubectl delete --ignore-not-found --wait -f -
```