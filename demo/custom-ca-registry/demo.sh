#!/usr/bin/env bash
#
# Demo driver for "custom CA certificates for registries" (PR #1743).
#
# Sets up a k3d cluster, a container registry serving a self-signed certificate,
# vanilla Argo CD and a vanilla argocd-image-updater, then lets you switch
# between the three ways of giving the updater that CA certificate:
#
#   ca_data         inline PEM in registries.conf
#   ca_file         explicit path to a mounted PEM file
#   auto-discovery  /app/config/tls/<hostname> from argocd-tls-certs-cm
#
# See README.md for the narrative. Run `./demo.sh help` for the command list.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CLUSTER_NAME="${CLUSTER_NAME:-ca-demo}"
REGISTRY_NS="${REGISTRY_NS:-demo-registry}"
REGISTRY_NAME="demo-registry"
REGISTRY_HOST="${REGISTRY_NAME}.${REGISTRY_NS}.svc.cluster.local"
REGISTRY_NODEPORT=30000
REGISTRY_PREFIX="127.0.0.1:${REGISTRY_NODEPORT}"
IMAGE_REPO="demo/app"

ARGOCD_NS="${ARGOCD_NS:-argocd}"
ARGOCD_MANIFEST="${ARGOCD_MANIFEST:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

APP_NS="${APP_NS:-demo}"
APP_NAME="${APP_NAME:-demo-app}"
APP_REPO="https://github.com/argoproj-labs/argocd-image-updater"
APP_PATH="test/e2e/testdata/005-public-guestbook"
# The image name the upstream kustomization references; our registry image is
# substituted for it through a kustomize image override.
BASE_IMAGE_NAME="quay.io/dkarpele/my-guestbook"

CONTROLLER="argocd-image-updater-controller"
IMAGE_UPDATER_IMAGE="${IMAGE_UPDATER_IMAGE:-quay.io/argoprojlabs/argocd-image-updater:v$(cat "${REPO_ROOT}/VERSION")}"
BUILD_IMAGE="${BUILD_IMAGE:-yes}"
CRANE_IMAGE="${CRANE_IMAGE:-gcr.io/go-containerregistry/crane:latest}"

WORKDIR="${WORKDIR:-${TMPDIR:-/tmp}/argocd-iu-ca-demo}"
CA_CRT="${WORKDIR}/registry-ca.crt"
CA_KEY="${WORKDIR}/registry-ca.key"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[0;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

require() {
	for tool in "$@"; do
		command -v "$tool" >/dev/null 2>&1 || die "$tool is required but not in PATH"
	done
}

kc() { kubectl "$@"; }

# ---------------------------------------------------------------------------
# cluster
# ---------------------------------------------------------------------------

cmd_cluster() {
	require k3d kubectl docker
	docker info >/dev/null 2>&1 || die "the Docker daemon is not running"

	if k3d cluster list "${CLUSTER_NAME}" >/dev/null 2>&1; then
		ok "k3d cluster ${CLUSTER_NAME} already exists"
	else
		info "creating k3d cluster ${CLUSTER_NAME}"
		# Port 30000 is published to the host so that `docker push`/`crane` and the
		# `argocd-image-updater test` CLI can reach the registry at 127.0.0.1:30000,
		# the same address the node itself uses.
		k3d cluster create "${CLUSTER_NAME}" \
			--port "${REGISTRY_NODEPORT}:${REGISTRY_NODEPORT}@server:0" \
			--registry-config "${SCRIPT_DIR}/k3d-registries.yaml"
	fi
	kc config use-context "k3d-${CLUSTER_NAME}" >/dev/null
	kc wait --for=condition=Ready nodes --all --timeout=120s >/dev/null
	ok "cluster ready (context k3d-${CLUSTER_NAME})"
}

# ---------------------------------------------------------------------------
# registry with a self-signed certificate
# ---------------------------------------------------------------------------

generate_cert() {
	mkdir -p "${WORKDIR}"
	info "generating self-signed certificate for ${REGISTRY_HOST}"
	# Go ignores the Common Name for hostname verification, so every name a
	# client may dial has to be a subjectAltName: the in-cluster Service DNS
	# names (used by the image updater) and 127.0.0.1 (used from the host).
	# The same certificate is the server cert *and* the trust anchor clients
	# import, hence CA:TRUE and the key usages for both roles.
	openssl genrsa -out "${CA_KEY}" 2048 2>/dev/null
	openssl req -x509 -new -key "${CA_KEY}" -days 365 -out "${CA_CRT}" \
		-subj "/C=US/ST=Demo/L=Demo/O=Argo CD Image Updater Demo/CN=${REGISTRY_HOST}" \
		-addext "subjectAltName=DNS:${REGISTRY_NAME},DNS:${REGISTRY_NAME}.${REGISTRY_NS},DNS:${REGISTRY_NAME}.${REGISTRY_NS}.svc,DNS:${REGISTRY_HOST},DNS:localhost,IP:127.0.0.1" \
		-addext "basicConstraints=critical,CA:TRUE" \
		-addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
		-addext "extendedKeyUsage=serverAuth" 2>/dev/null
	ok "certificate at ${CA_CRT}"
}

cmd_registry() {
	require kubectl openssl
	generate_cert

	info "deploying registry into namespace ${REGISTRY_NS}"
	kc create namespace "${REGISTRY_NS}" --dry-run=client -o yaml | kc apply -f - >/dev/null
	kc create secret tls "${REGISTRY_NAME}-tls" -n "${REGISTRY_NS}" \
		--cert="${CA_CRT}" --key="${CA_KEY}" \
		--dry-run=client -o yaml | kc apply -f - >/dev/null

	kc apply -n "${REGISTRY_NS}" -f - >/dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${REGISTRY_NAME}
data:
  registry.conf: |
    version: 0.1
    storage:
      filesystem:
        rootdirectory: /var/lib/registry
    http:
      addr: 0.0.0.0:5000
      tls:
        certificate: /tmp/tls/tls.crt
        key: /tmp/tls/tls.key
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${REGISTRY_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${REGISTRY_NAME}
  template:
    metadata:
      labels:
        app: ${REGISTRY_NAME}
    spec:
      containers:
      - name: registry
        image: registry:3
        command: ["registry", "serve", "/tmp/config/registry.conf"]
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: config
          mountPath: /tmp/config
        - name: tls
          mountPath: /tmp/tls
          readOnly: true
        - name: data
          mountPath: /var/lib/registry
      volumes:
      - name: config
        configMap:
          name: ${REGISTRY_NAME}
      - name: tls
        secret:
          secretName: ${REGISTRY_NAME}-tls
      - name: data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: ${REGISTRY_NAME}
spec:
  type: NodePort
  selector:
    app: ${REGISTRY_NAME}
  ports:
  - name: https
    protocol: TCP
    port: 443
    targetPort: 5000
    nodePort: ${REGISTRY_NODEPORT}
EOF

	kc rollout status -n "${REGISTRY_NS}" "deployment/${REGISTRY_NAME}" --timeout=180s
	ok "registry serving https://${REGISTRY_HOST} (NodePort ${REGISTRY_PREFIX})"

	seed_images
}

# Seeds three tags into the registry from inside the cluster, so the demo needs
# no "insecure-registries" entry in the host Docker daemon and no daemon restart.
seed_images() {
	info "seeding ${REGISTRY_PREFIX}/${IMAGE_REPO} with tags 1.0.0, 1.0.1, 1.0.2"
	kc delete job -n "${REGISTRY_NS}" seed-images --ignore-not-found >/dev/null
	kc apply -n "${REGISTRY_NS}" -f - >/dev/null <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: seed-images
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      initContainers:
      - name: copy-1-0-0
        image: ${CRANE_IMAGE}
        args: ["copy", "--insecure", "docker.io/library/nginx:1.25-alpine", "${REGISTRY_HOST}/${IMAGE_REPO}:1.0.0"]
      - name: copy-1-0-1
        image: ${CRANE_IMAGE}
        args: ["copy", "--insecure", "docker.io/library/nginx:1.26-alpine", "${REGISTRY_HOST}/${IMAGE_REPO}:1.0.1"]
      containers:
      - name: copy-1-0-2
        image: ${CRANE_IMAGE}
        args: ["copy", "--insecure", "docker.io/library/nginx:1.27-alpine", "${REGISTRY_HOST}/${IMAGE_REPO}:1.0.2"]
EOF
	if ! kc wait -n "${REGISTRY_NS}" --for=condition=complete job/seed-images --timeout=300s >/dev/null; then
		kc logs -n "${REGISTRY_NS}" job/seed-images --all-containers --tail=40 || true
		die "seeding the registry failed"
	fi
	ok "images pushed"
}

cmd_tags() {
	info "tags in the registry (queried from inside the cluster)"
	kc run -n "${REGISTRY_NS}" "reg-check-$$" --rm -i --restart=Never --quiet \
		--image=curlimages/curl -- \
		curl -sk "https://${REGISTRY_HOST}/v2/${IMAGE_REPO}/tags/list"
	echo
}

# ---------------------------------------------------------------------------
# Argo CD + image updater
# ---------------------------------------------------------------------------

cmd_argocd() {
	require kubectl

	info "installing vanilla Argo CD into namespace ${ARGOCD_NS}"
	kc create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kc apply -f - >/dev/null
	kc apply -n "${ARGOCD_NS}" --server-side=true -f "${ARGOCD_MANIFEST}" >/dev/null
	kc rollout status -n "${ARGOCD_NS}" deployment/argocd-repo-server --timeout=300s
	kc rollout status -n "${ARGOCD_NS}" statefulset/argocd-application-controller --timeout=300s
	ok "Argo CD ready"

	if [ "${BUILD_IMAGE}" = "yes" ]; then
		info "building ${IMAGE_UPDATER_IMAGE} from this working tree"
		make -C "${REPO_ROOT}" docker-build IMG="${IMAGE_UPDATER_IMAGE}"
		info "importing the image into the k3d cluster"
		k3d image import "${IMAGE_UPDATER_IMAGE}" -c "${CLUSTER_NAME}" --mode=direct
	else
		warn "BUILD_IMAGE=no — using ${IMAGE_UPDATER_IMAGE} as-is"
	fi

	# Start out deliberately broken: a registry entry with no CA configuration.
	apply_controller none
	ok "image updater installed (no CA configured yet)"
}

# Reinstalls the controller and restarts it with the requested CA configuration.
# $1: registries.conf mode — none | ca_data | ca_file | auto
# $2: optional strategic-merge patch applied to the Deployment.
apply_controller() {
	local mode="$1" patch="${2:-}"
	# Deleting first keeps the Deployment free of leftovers from a previous CA
	# method: `kubectl apply` would not remove volumes added by `kubectl patch`.
	kc delete deployment -n "${ARGOCD_NS}" "${CONTROLLER}" --ignore-not-found >/dev/null
	sed "s|image: quay.io/argoprojlabs/argocd-image-updater:latest|image: ${IMAGE_UPDATER_IMAGE}|" \
		"${REPO_ROOT}/config/install.yaml" |
		kc apply -n "${ARGOCD_NS}" --server-side=true --force-conflicts -f - >/dev/null
	# install.yaml ships argocd-image-updater-config with no `data:` at all, and
	# the server-side apply above claims ownership of the whole object — so it
	# silently drops any registries.conf written *before* it. The registry
	# configuration therefore has to be written afterwards, every time.
	write_registries_conf "${mode}"
	if [ -n "${patch}" ]; then
		kc patch deployment -n "${ARGOCD_NS}" "${CONTROLLER}" --type strategic --patch "${patch}" >/dev/null
	fi
	# registries.conf is read once at startup and the pod created by the apply
	# above may already have read the empty ConfigMap, so force a fresh pod.
	kc rollout restart -n "${ARGOCD_NS}" "deployment/${CONTROLLER}" >/dev/null
	kc rollout status -n "${ARGOCD_NS}" "deployment/${CONTROLLER}" --timeout=300s
}

# Writes the argocd-image-updater-config ConfigMap.
# $1: none | ca_data | ca_file | auto
write_registries_conf() {
	local mode="$1" extra=""
	# The lines below are spliced into the `registries.conf: |` block scalar, where
	# the registry's own fields sit at six spaces — anything less indented would
	# silently become a new top-level key of the ConfigMap instead.
	case "${mode}" in
	none) extra="" ;;
	ca_data)
		extra=$(printf '      ca_data: |\n%s' "$(sed 's/^/        /' "${CA_CRT}")")
		;;
	ca_file) extra="      ca_file: /app/config/registry-certs/demo-registry-ca.crt" ;;
	auto) extra="" ;;
	*) die "unknown registries.conf mode ${mode}" ;;
	esac

	# Server-side apply under a field manager of our own: install.yaml keeps
	# ownership of the object's metadata while this owns `data`, so switching
	# back to a mode without ca_data/ca_file prunes those keys cleanly — and
	# kubectl stops warning about the missing last-applied-configuration.
	kc apply -n "${ARGOCD_NS}" --server-side=true --force-conflicts \
		--field-manager=ca-demo -f - >/dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-config
data:
  log.level: debug
  interval: 30s
  registries.conf: |
    registries:
    - name: Demo Registry
      api_url: https://${REGISTRY_HOST}
      prefix: ${REGISTRY_PREFIX}
${extra}
EOF
}

# Puts the CA certificate into Argo CD's argocd-tls-certs-cm under $1.
put_cert_in_tls_cm() {
	local key="$1"
	kc create configmap argocd-tls-certs-cm -n "${ARGOCD_NS}" \
		--from-file="${key}=${CA_CRT}" --dry-run=client -o yaml |
		kc apply --server-side=true --force-conflicts --field-manager=ca-demo -f - >/dev/null
}

clear_tls_cm() {
	kc create configmap argocd-tls-certs-cm -n "${ARGOCD_NS}" --dry-run=client -o yaml |
		kc apply --server-side=true --force-conflicts --field-manager=ca-demo -f - >/dev/null
}

# ---------------------------------------------------------------------------
# demo application
# ---------------------------------------------------------------------------

cmd_app() {
	require kubectl
	info "creating Application ${APP_NAME} and ImageUpdater ${APP_NAME}"
	kc apply -n "${ARGOCD_NS}" -f - >/dev/null <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
spec:
  project: default
  source:
    repoURL: ${APP_REPO}
    path: ${APP_PATH}
    targetRevision: HEAD
    kustomize:
      images:
      - ${BASE_IMAGE_NAME}=${REGISTRY_PREFIX}/${IMAGE_REPO}:1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: ${APP_NS}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
---
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: ${APP_NAME}
spec:
  applicationRefs:
  - namePattern: "${APP_NAME}"
    images:
    - alias: app
      imageName: ${REGISTRY_PREFIX}/${IMAGE_REPO}:~1.0
      commonUpdateSettings:
        updateStrategy: semver
        # The configured image is only considered when it is live in
        # .status.summary.images; forceUpdate makes the demo independent of
        # whether the first sync has completed yet.
        forceUpdate: true
      manifestTargets:
        kustomize:
          # The image name in the upstream kustomization that gets replaced.
          name: ${BASE_IMAGE_NAME}
EOF
	ok "Application and ImageUpdater created"
}

cmd_reset() {
	info "resetting ${APP_NAME} back to tag 1.0.0"
	kc patch application -n "${ARGOCD_NS}" "${APP_NAME}" --type merge -p \
		"{\"spec\":{\"source\":{\"kustomize\":{\"images\":[\"${BASE_IMAGE_NAME}=${REGISTRY_PREFIX}/${IMAGE_REPO}:1.0.0\"]}}}}" >/dev/null
	ok "Application back at 1.0.0"
}

# ---------------------------------------------------------------------------
# the three CA methods
# ---------------------------------------------------------------------------

cmd_no_ca() {
	bold "registries.conf without any CA configuration"
	clear_tls_cm
	apply_controller none
	ok "controller restarted — it cannot verify the registry certificate"
}

cmd_ca_data() {
	bold "Method 1: ca_data (inline PEM in registries.conf)"
	clear_tls_cm
	apply_controller ca_data
	ok "controller restarted with ca_data"
}

cmd_ca_file() {
	bold "Method 2: ca_file (explicit path to a mounted PEM file)"
	put_cert_in_tls_cm demo-registry-ca.crt
	# The vanilla manifest mounts the webhook serving certificate at
	# /app/config/tls, so argocd-tls-certs-cm gets its own mount point here and
	# registries.conf points ca_file at it.
	apply_controller ca_file "$(cat <<'EOF'
spec:
  template:
    spec:
      containers:
      - name: argocd-image-updater-controller
        volumeMounts:
        - name: registry-certs
          mountPath: /app/config/registry-certs
          readOnly: true
      volumes:
      - name: registry-certs
        configMap:
          name: argocd-tls-certs-cm
EOF
	)"
	ok "controller restarted with ca_file=/app/config/registry-certs/demo-registry-ca.crt"
}

cmd_auto_discovery() {
	bold "Method 3: auto-discovery (/app/config/tls/<hostname>)"
	put_cert_in_tls_cm "${REGISTRY_HOST}"
	# Auto-discovery looks at the hard-coded path /app/config/tls/<hostname>.
	# In the vanilla manifest that directory holds the webhook serving
	# certificate, so the volume is repointed at argocd-tls-certs-cm — which is
	# the layout argocd-operator ships by default.
	apply_controller auto "$(cat <<'EOF'
spec:
  template:
    spec:
      volumes:
      - name: argocd-image-updater-tls
        secret: null
        configMap:
          name: argocd-tls-certs-cm
          optional: true
EOF
	)"
	ok "controller restarted with the CA at /app/config/tls/${REGISTRY_HOST}"
}

# ---------------------------------------------------------------------------
# observation helpers
# ---------------------------------------------------------------------------

cmd_status() {
	# Every lookup below is guarded: the ConfigMaps legitimately have no `data`
	# in some states, and a template error there must not abort the whole report.
	local conf keys
	bold "registries.conf"
	conf=$(kc get cm -n "${ARGOCD_NS}" argocd-image-updater-config \
		-o jsonpath='{.data.registries\.conf}' 2>/dev/null || true)
	if [ -n "${conf}" ]; then
		echo "${conf}" | sed 's/^/  /'
	else
		echo "  (empty — the controller has no registry configuration at all)"
	fi
	bold "argocd-tls-certs-cm keys"
	keys=$(kc get cm -n "${ARGOCD_NS}" argocd-tls-certs-cm \
		-o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}' 2>/dev/null || true)
	if [ -n "${keys}" ]; then echo "${keys}" | sed 's/^/  /'; else echo "  (none)"; fi
	bold "controller"
	kc get pods -n "${ARGOCD_NS}" -l control-plane="${CONTROLLER}" \
		-o custom-columns=NAME:.metadata.name,STATUS:.status.phase,AGE:.metadata.creationTimestamp --no-headers | sed 's/^/  /'
	bold "Application image override"
	kc get application -n "${ARGOCD_NS}" "${APP_NAME}" \
		-o jsonpath='{.spec.source.kustomize.images[*]}{"\n"}' | sed 's/^/  /'
	bold "running image"
	kc get deployment -n "${APP_NS}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}' 2>/dev/null | sed 's/^/  /'
	bold "ImageUpdater status"
	kc get imageupdater -n "${ARGOCD_NS}" "${APP_NAME}" \
		-o jsonpath='{.status.applicationsMatched}{" app(s) matched, "}{.status.imagesManaged}{" image(s) managed, last checked "}{.status.lastCheckedAt}{"\n"}' 2>/dev/null | sed 's/^/  /'
}

cmd_logs() {
	kc logs -n "${ARGOCD_NS}" "deployment/${CONTROLLER}" -f --tail=50
}

cmd_tls_logs() {
	bold "certificate-related log lines"
	kc logs -n "${ARGOCD_NS}" "deployment/${CONTROLLER}" --tail=-1 |
		grep -Ei 'x509|certificate|could not get tags|Setting Kustomize parameter|Successfully updated' |
		tail -20 | sed 's/^/  /' || echo "  (nothing yet — give it a reconcile cycle)"
}

# Runs `argocd-image-updater test` as a one-shot pod built from the very image
# the controller runs, with the registries.conf in $1. Going through a pod rather
# than `go run` keeps the demo independent of the host Go toolchain and of the
# state of ./vendor, and it resolves the registry by its in-cluster DNS name.
run_test_pod() {
	local conf="$1" name="iu-test" phase=""
	kc delete pod -n "${ARGOCD_NS}" "${name}" --ignore-not-found >/dev/null 2>&1
	kc create configmap "${name}" -n "${ARGOCD_NS}" --from-file="registries.conf=${conf}" \
		--dry-run=client -o yaml | kc apply -f - >/dev/null
	kc apply -n "${ARGOCD_NS}" -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${name}
spec:
  restartPolicy: Never
  serviceAccountName: argocd-image-updater-controller
  containers:
  - name: test
    image: ${IMAGE_UPDATER_IMAGE}
    args:
    - test
    - ${REGISTRY_PREFIX}/${IMAGE_REPO}
    - --semver-constraint
    - "~1.0"
    - --registries-conf-path
    - /conf/registries.conf
    volumeMounts:
    - name: conf
      mountPath: /conf
  volumes:
  - name: conf
    configMap:
      name: ${name}
EOF
	for _ in $(seq 60); do
		phase=$(kc get pod -n "${ARGOCD_NS}" "${name}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
		case "${phase}" in Succeeded | Failed) break ;; esac
		sleep 2
	done
	kc logs -n "${ARGOCD_NS}" "${name}" 2>&1 | sed 's/^/  /'
	kc delete pod -n "${ARGOCD_NS}" "${name}" --ignore-not-found >/dev/null 2>&1
}

cmd_test_cli() {
	local conf="${WORKDIR}/registries-test.conf"

	bold "1) resolving the tag WITHOUT the CA certificate"
	cat >"${conf}" <<EOF
registries:
- name: Demo Registry
  api_url: https://${REGISTRY_HOST}
  prefix: ${REGISTRY_PREFIX}
EOF
	run_test_pod "${conf}"

	echo
	bold "2) the same call WITH ca_data"
	{
		cat <<EOF
registries:
- name: Demo Registry
  api_url: https://${REGISTRY_HOST}
  prefix: ${REGISTRY_PREFIX}
  ca_data: |
EOF
		sed 's/^/    /' "${CA_CRT}"
	} >"${conf}"
	run_test_pod "${conf}"
}

# ---------------------------------------------------------------------------

cmd_up() {
	cmd_cluster
	cmd_registry
	cmd_argocd
	cmd_app
	echo
	bold "Environment is up, with no CA certificate configured."
	echo "  Watch it fail:   ${0} tls-logs"
	echo "  Then fix it:     ${0} ca-data"
}

cmd_down() {
	info "deleting k3d cluster ${CLUSTER_NAME}"
	k3d cluster delete "${CLUSTER_NAME}" || true
	rm -rf "${WORKDIR}"
	ok "cleaned up"
}

cmd_help() {
	cat <<EOF
$(bold "usage: ./demo.sh <command>")

Setup
  up               cluster + registry + Argo CD + image updater + demo app
  cluster          create the k3d cluster
  registry         deploy the TLS registry and seed demo/app:1.0.{0,1,2}
  argocd           install Argo CD and the image updater (no CA configured)
  app              create the Argo CD Application and the ImageUpdater CR

CA configuration (each one restarts the controller)
  no-ca            remove all CA configuration — reproduces the x509 failure
  ca-data          method 1: inline PEM in registries.conf
  ca-file          method 2: ca_file pointing at a mounted PEM
  auto-discovery   method 3: /app/config/tls/<hostname> from argocd-tls-certs-cm

Observation
  status           registries.conf, controller, Application and running image
  tls-logs         the certificate-related controller log lines
  logs             follow the controller log
  tags             list the tags the registry holds
  reset            put the Application image back to 1.0.0
  test-cli         run \`argocd-image-updater test\` in a throwaway pod, without and with the CA

Teardown
  down             delete the k3d cluster and the working directory

Environment: CLUSTER_NAME, ARGOCD_NS, APP_NS, IMAGE_UPDATER_IMAGE, BUILD_IMAGE=no,
              ARGOCD_MANIFEST, WORKDIR (currently ${WORKDIR})
EOF
}

case "${1:-help}" in
up) cmd_up ;;
cluster) cmd_cluster ;;
registry) cmd_registry ;;
argocd) cmd_argocd ;;
app) cmd_app ;;
no-ca) cmd_no_ca ;;
ca-data) cmd_ca_data ;;
ca-file) cmd_ca_file ;;
auto-discovery) cmd_auto_discovery ;;
status) cmd_status ;;
logs) cmd_logs ;;
tls-logs) cmd_tls_logs ;;
tags) cmd_tags ;;
reset) cmd_reset ;;
test-cli) cmd_test_cli ;;
down) cmd_down ;;
help | -h | --help) cmd_help ;;
*) die "unknown command '${1}' (try ./demo.sh help)" ;;
esac
