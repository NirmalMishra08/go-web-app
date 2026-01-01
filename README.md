Go Web App with Helm, Docker, and GitOps
========================================

This repo is a tiny static-site server written in Go and packaged for Kubernetes with Helm. It is meant to be easy to run locally, in Docker, or through a GitOps pipeline with Argo CD.


Project map
-----------
- Go HTTP server: [main.go](main.go#L1-L35) serves static HTML from [static/](static)
- Container build: [Dockerfile](Dockerfile#L1-L33) multi-stage build to a distroless image exposing port 8080
- Helm chart: [helm/go-web-app-chart](helm/go-web-app-chart) with Deployment, Service, and Ingress manifests
- Defaults: image repository/tag in [helm/go-web-app-chart/values.yaml](helm/go-web-app-chart/values.yaml#L1-L2) and host in [helm/go-web-app-chart/templates/manifests/ingress.yaml](helm/go-web-app-chart/templates/manifests/ingress.yaml#L7-L17)


Run locally (no Docker)
-----------------------
Prereqs: Go 1.22+

```bash
go run main.go
# open http://localhost:8080/home
```


Build and run with Docker
-------------------------
Prereqs: Docker

```bash
# build (set your repo/tag as needed)
docker build -t YOUR_REPO/go-web-app:dev .

# run
docker run --rm -p 8080:8080 YOUR_REPO/go-web-app:dev
# open http://localhost:8080/home
```


Kubernetes deploy with Helm
---------------------------
Prereqs: kubectl, Helm, and a cluster (kind/minikube/real). If using an Ingress, ensure an ingress controller is installed (e.g., ingress-nginx).

```bash
# set your image repo/tag and (optionally) host override
helm upgrade --install go-web-app ./helm/go-web-app-chart \
	--set image.repository=YOUR_REPO/go-web-app \
	--set image.tag=YOUR_TAG \
	--set ingress.host=go-web-app.localdev.me

# verify
kubectl get deploy,svc,ingress
```


Ingress controller and DNS
--------------------------
Use ingress-nginx (the standard NGINX-based controller) if your cluster does not already have one:

```bash
# install ingress-nginx (cluster-scoped)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# wait for the controller to be ready
kubectl -n ingress-nginx get pods -w
```

DNS mapping so you can reach the app:
- Quick test: point your hosts file to the ingress IP. After the controller is ready, get its external IP: `kubectl -n ingress-nginx get svc ingress-nginx-controller`. Add a hosts entry like `203.0.113.10 go-web-app.localdev.me`.
- Wildcard helpers: use nip.io/sslip.io instead of editing hosts. For example, set `--set ingress.host=$(EXTERNAL_IP).nip.io` so DNS resolves automatically to the ingress IP.
- Local clusters (kind/minikube): enable their built-in ingress add-ons or port-forward the controller service if no LoadBalancer IP is available.

With ingress working, apply the chart and confirm routing:

```bash
kubectl get ingress
curl -H "Host: go-web-app.localdev.me" http://<ingress-ip>/home
```


GitOps with Argo CD
-------------------
Typical flow:
1) Build and push the image (`docker build` + `docker push`).
2) Commit the updated image tag into [helm/go-web-app-chart/values.yaml](helm/go-web-app-chart/values.yaml#L1-L2) (or use a Helm values file in a separate GitOps repo).
3) Point an Argo CD Application to this repo and chart path `helm/go-web-app-chart`.
4) Sync the Application; Argo CD will apply the Deployment, Service, and Ingress.

Minimal Argo CD Application example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
	name: go-web-app
	namespace: argocd
spec:
	project: default
	source:
		repoURL: https://github.com/iam-veeramalla/go-web-app.git
		path: helm/go-web-app-chart
		targetRevision: HEAD
	destination:
		server: https://kubernetes.default.svc
		namespace: default
	syncPolicy:
		automated: { prune: true, selfHeal: true }
```


What you must tweak for your PC/cluster
---------------------------------------
Apply these small changes so the chart deploys with your image and domain. Replace placeholders and commit the diff.

```diff
--- a/helm/go-web-app-chart/values.yaml
+++ b/helm/go-web-app-chart/values.yaml
-image:
-  repository: nirmal08/go-web-app
-  tag: "20640481273"
+image:
+  repository: YOUR_REPO/go-web-app
+  tag: "YOUR_TAG"

--- a/helm/go-web-app-chart/templates/manifests/ingress.yaml
+++ b/helm/go-web-app-chart/templates/manifests/ingress.yaml
-  - host: go-web-app.com
+  - host: go-web-app.localdev.me
```

Common troubleshooting
----------------------
- Ingress not reachable: ensure an ingress controller exists and update the host to a resolvable name (use `nip.io`/`sslip.io` for quick tests).
- Wrong image: confirm `image.repository` and `image.tag` in your Helm release match the pushed image.
- Pod not ready: check container port (8080) matches the Service `targetPort` in [helm/go-web-app-chart/templates/manifests/service.yaml](helm/go-web-app-chart/templates/manifests/service.yaml#L8-L11).


Directory guide
---------------
- [main.go](main.go) — Go HTTP server serving static HTML pages
- [static/](static) — HTML and assets
- [Dockerfile](Dockerfile) — multi-stage build to distroless runtime
- [helm/go-web-app-chart](helm/go-web-app-chart) — Helm chart with Deployment/Service/Ingress
