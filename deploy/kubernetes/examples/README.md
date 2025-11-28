Overview

This directory contains standalone Kubernetes manifests to run mhserveremu and expose it via different Ingress controllers locally using minikube or kind.

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

Notes
- Ingress exposes only the HTTP API/UI on port 8080. The game traffic on TCP/UDP 4306 is exposed via the Service directly. For local testing, you can port-forward or use a LoadBalancer with `minikube tunnel`.
- Default DNS host used in the examples: `fes.mhserveremu.localdev`.


1) Create a local cluster

Minikube
```
minikube start
```

kind
```
kind create cluster --name mhserveremu
```


2) Deploy the base app
```
kubectl apply -f deploy/kubernetes/examples/common/namespace.yaml
kubectl apply -f deploy/kubernetes/examples/common/pvc.yaml
kubectl apply -f deploy/kubernetes/examples/common/deployment.yaml
kubectl apply -f deploy/kubernetes/examples/common/service.yaml
```

Verify:
```
kubectl -n mhserveremu get pods,svc,pvc
```


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
kubectl apply -f deploy/kubernetes/examples/ingress-nginx/ingress.yaml
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
kubectl apply -f deploy/kubernetes/examples/nginx-gateway/gateway.yaml
kubectl apply -f deploy/kubernetes/examples/nginx-gateway/httproute.yaml
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
kubectl apply -f deploy/kubernetes/examples/traefik-gateway/gateway.yaml
kubectl apply -f deploy/kubernetes/examples/traefik-gateway/httproute.yaml
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
kubectl apply -f deploy/kubernetes/examples/contour-gateway/gateway.yaml
kubectl apply -f deploy/kubernetes/examples/contour-gateway/httproute.yaml
```


4) Make the host resolve and access the UI

Add to your /etc/hosts (or platform equivalent):
```
127.0.0.1 fes.mhserveremu.localdev
```

Option A: Port-forward the Ingress Service (works everywhere)

- ingress-nginx:
```
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8080:80
```
- Traefik (Helm NodePort install above):
```
kubectl -n traefik port-forward svc/traefik 8080:80
```
- Contour (Envoy service):
```
kubectl -n projectcontour port-forward svc/envoy 8080:80
```

Gateway API controllers (port-forward one of the following):

- NGINX Gateway Fabric:
```
kubectl -n nginx-gateway port-forward svc/nginx-gateway 8080:80
```
- Traefik (Helm NodePort install above):
```
kubectl -n traefik port-forward svc/traefik 8080:80
```
- Contour (Envoy service):
```
kubectl -n projectcontour port-forward svc/envoy 8080:80
```

Then open http://fes.mhserveremu.localdev:8080 in your browser.

Option B: Use a LoadBalancer IP (minikube only)
```
minikube tunnel
kubectl get svc -A | grep -E "ingress-nginx-controller|traefik|envoy"
```
Use the assigned EXTERNAL-IP to access http://fes.mhserveremu.localdev:80.


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
kubectl delete -f deploy/kubernetes/examples/contour-gateway/httproute.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/contour-gateway/gateway.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/traefik-gateway/httproute.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/traefik-gateway/gateway.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/nginx-gateway/httproute.yaml --ignore-not-found
kubectl delete -f deploy/kubernetes/examples/nginx-gateway/gateway.yaml --ignore-not-found
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
