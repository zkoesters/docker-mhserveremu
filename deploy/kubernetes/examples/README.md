Overview

This directory contains standalone Kubernetes manifests to run mhserveremu and expose it via different Ingress controllers locally using minikube or kind. All examples use HTTPS (port 443) with a self‑signed certificate for local testing, similar to the Docker examples.

What you get
- A base app (Namespace, Deployment, Service, PVC)
- Ingress examples for three controllers:
  - ingress-nginx
  - Traefik
  - Contour (plus an optional HTTPProxy example)
- Gateway API examples for three controllers:
  - NGINX Gateway Fabric
  - Traefik
  - Contour Gateway (Gateway Provisioner)
 - Optional: Static file hosting at host `static.mhserveremu.localdev` (serves `SiteConfig.xml`)

Notes
- Ingress/Gateway exposes only the HTTP(S) API/UI; the backend service still listens on 8080. The game traffic on TCP/UDP 4306 is exposed via the Service directly. For local testing, you can port-forward or use a LoadBalancer with `minikube tunnel`.
- Default DNS host used in the examples: `fes.mhserveremu.localdev`.
- TLS: A single Kubernetes TLS secret named `mhserveremu-tls` is referenced by all examples. See step 2b to create it from the self‑signed certificate bundled with the Docker examples.


1) Create a local cluster

Minikube
```
minikube start
```

kind
```
kind create cluster --name mhserveremu
```


2) Deploy using Kustomize (one command)

The common example now includes a `kustomization.yaml` that:
- Creates the `mhserveremu` namespace
- Deploys the app `Deployment` and `Service`
- Deploys the optional static file host (Deployment + Service)
- Generates the slim `mhserveremu-static-files` ConfigMap with only `SiteConfig.xml` and `LiveLoadingTips.xml`
- Creates the TLS secret `mhserveremu-tls` from the bundled self‑signed cert

Because the kustomization references files outside its directory (static XMLs and TLS certs under `deploy/common`), you must relax Kustomize’s load restrictor. If you are using kind, run:
```
kubectl kustomize --load-restrictor=LoadRestrictionsNone deploy/kubernetes/examples/common/ | \
  kubectl --context kind-kind apply -f -
```

Notes
- If you need to (re)generate the self‑signed certs first, use `deploy/common/certs/generate_certs.sh`.

Verify:
```
kubectl -n mhserveremu get pods,svc,pvc,cm,secret
```

Static host
- Once applied, `SiteConfig.xml` will be served at:
  ```
  http://static.mhserveremu.localdev/SiteConfig.xml
  ```

Browsers will warn about the bundled self‑signed certificate. You can proceed for local testing, or import `deploy/common/certs/server.crt` into your system trust store.


3) Choose and install ONE ingress controller

A) ingress-nginx

Minikube (recommended):
```
minikube addons enable ingress
```

kind or generic Kubernetes:
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
# wait for the controller to be Ready
kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=180s
```

Apply the example Ingress:
```
kubectl apply -f deploy/kubernetes/examples/nginx/ingress.yaml
```


B) Traefik v2

Minikube addon (if available on your distro):
```
minikube addons enable traefik
```

Helm install (works for both minikube and kind):
```
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --set ports.web.nodePort=32080 \
  --set service.type=NodePort
```

Apply the example Ingress:
```
kubectl apply -f deploy/kubernetes/examples/traefik/ingress.yaml
```

Alternatively, use Traefik's IngressRoute CRD (installed by the Helm chart above):
```
kubectl apply -f deploy/kubernetes/examples/traefik/ingressroute.yaml
```


C) Contour

Install Contour (quickstart):
```
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
# wait for deployments to be ready
kubectl -n projectcontour wait --for=condition=Available deployment/contour --timeout=180s
kubectl -n projectcontour wait --for=condition=Available deployment/envoy --timeout=180s
```

Apply the example Ingress (works without CRDs):
```
kubectl apply -f deploy/kubernetes/examples/contour/ingress.yaml
```

Optional: Apply the HTTPProxy example (Contour CRD):
```
kubectl apply -f deploy/kubernetes/examples/contour/httpproxy.yaml
```


3b) Or use Gateway API instead of Ingress (pick ONE controller)

A) NGINX Gateway Fabric (Gateway API)

Install controller:
```
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/main/deploy/releases/latest/install.yaml
# wait for the deployment to be ready
kubectl -n nginx-gateway wait --for=condition=Available deploy/nginx-gateway --timeout=180s
```

Apply the Gateway and HTTPRoute:
```
kubectl apply -f deploy/kubernetes/examples/nginx/gateway.yaml
kubectl apply -f deploy/kubernetes/examples/nginx/httproute.yaml
```


B) Traefik (Gateway API)

Install Traefik with Helm (exposes a NodePort service for convenience):
```
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --set ports.web.nodePort=32080 \
  --set service.type=NodePort
```

Apply the Gateway and HTTPRoute:
```
kubectl apply -f deploy/kubernetes/examples/traefik/gateway.yaml
kubectl apply -f deploy/kubernetes/examples/traefik/httproute.yaml
```


C) Contour (Gateway API via Gateway Provisioner)

Install Contour with Gateway Provisioner (quickstart):
```
kubectl apply -f https://projectcontour.io/quickstart/contour-gateway-provisioner.yaml
# wait for deployments to be ready
kubectl -n projectcontour wait --for=condition=Available deployment/contour --timeout=180s
kubectl -n projectcontour wait --for=condition=Available deployment/envoy --timeout=180s
```

Apply the Gateway and HTTPRoute:
```
kubectl apply -f deploy/kubernetes/examples/contour/gateway.yaml
kubectl apply -f deploy/kubernetes/examples/contour/httproute.yaml
```


4) Make the host resolve and access the UI

Add to your /etc/hosts (or platform equivalent):
```
127.0.0.1 fes.mhserveremu.localdev
127.0.0.1 mhserveremu.localdev
127.0.0.1 static.mhserveremu.localdev
```

Option A: Port-forward the Ingress Service (works everywhere)

- ingress-nginx:
```
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8443:443
```
- Traefik (Helm install above):
```
kubectl -n traefik port-forward svc/traefik 8443:443
```
- Contour (Envoy service):
```
kubectl -n projectcontour port-forward svc/envoy 8443:443
```

Gateway API controllers (port-forward one of the following):

- NGINX Gateway Fabric:
```
kubectl -n nginx-gateway port-forward svc/nginx-gateway 8443:443
```
- Traefik (Helm install above):
```
kubectl -n traefik port-forward svc/traefik 8443:443
```
- Contour (Envoy service):
```
kubectl -n projectcontour port-forward svc/envoy 8443:443
```

Then open https://fes.mhserveremu.localdev:8443 in your browser.

Option B: Use a LoadBalancer IP (minikube only)
```
minikube tunnel
kubectl get svc -A | grep -E "ingress-nginx-controller|traefik|envoy"
```
Use the assigned EXTERNAL-IP to access https://fes.mhserveremu.localdev:443.


5) Access game ports (TCP/UDP 4306)

- Port-forward TCP:
```
kubectl -n mhserveremu port-forward svc/mhserveremu 4306:4306 --address 0.0.0.0
```
- UDP forwarding is not supported by `kubectl port-forward`. For local testing, prefer `minikube tunnel` with a Service of type LoadBalancer, or expose a NodePort and connect to the node IP.

If you want a LoadBalancer for the mhserveremu Service on minikube:
```
kubectl -n mhserveremu patch svc mhserveremu -p '{"spec": {"type": "LoadBalancer"}}'
minikube tunnel
kubectl -n mhserveremu get svc mhserveremu -w
```


Cleanup
```
kubectl delete -f deploy/kubernetes/examples/common/static-service.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/common/static-deployment.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/common/static-configmap.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/contour/httproute.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/contour/gateway.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/traefik/httproute.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/traefik/gateway.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/nginx/httproute.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/nginx/gateway.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/contour/httpproxy.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/contour/ingress.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/traefik/ingress.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/traefik/ingressroute.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/ingress-nginx/ingress.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/common/service.yaml
kubectl delete -f deploy/kubernetes/examples/common/deployment.yaml
kubectl delete -f deploy/kubernetes/examples/common/pvc.yaml
kubectl delete -f deploy/kubernetes/examples/common/namespace.yaml
```
