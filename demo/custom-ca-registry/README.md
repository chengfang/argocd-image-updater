# Demo: custom CA certificates for container registries

Walkthrough for the feature added in [PR #1743](https://github.com/argoproj-labs/argocd-image-updater/pull/1743):
Argo CD Image Updater can trust a registry that serves a certificate signed by a
private CA, in three different ways.

Everything here runs on **vanilla Argo CD + vanilla argocd-image-updater** — no
argocd-operator. (The e2e suite for this feature,
`test/ginkgo/parallel/1-012-custom-ca-registry_test.go`, uses the operator; the
differences that matter are called out in
[What the vanilla install changes](#what-the-vanilla-install-changes).)

---

## 1. The feature in one screen

`registries.conf` gains two fields, and one path is probed automatically
(`registry-scanner/pkg/registry/config.go`):

| # | Method | Configuration | Trust anchor comes from |
|---|---|---|---|
| 1 | `ca_data` | `ca_data: \|` + inline PEM | the ConfigMap itself |
| 2 | `ca_file` | `ca_file: /some/path/ca.crt` | a file you mount |
| 3 | auto-discovery | *nothing* | `/app/config/tls/<hostname-of-api_url>` |

The resolution order (`newRegistryEndpointFromConfig`):

```
insecure: true     ──► no CA handling at all, verification is off
ca_file set        ──► use it
ca_file unset      ──► probe /app/config/tls/<api_url hostname>; use it if it exists
ca_data set        ──► append it too (ca_data and ca_file can be combined)
nothing found      ──► system trust store only  ──► x509: unknown authority
```

The certificates are **appended to the system pool**, so public registries keep
working while a private one is trusted.

Four details worth saying out loud during a demo:

* **`registries.conf` is read once, at startup** (`cmd/common.go` →
  `LoadRegistryConfiguration`). Every change needs a controller restart; the
  mounted ConfigMap updating in place is not enough.
* **A broken CA reference is fatal.** An unreadable `ca_file`, or PEM that does
  not parse, makes `run` return an error — the controller crash-loops instead of
  silently falling back. That is deliberate: a silent fallback would mean
  unverified traffic. Note what this looks like in practice: the *new* pod
  crash-loops while the *old* one keeps running on the old configuration, so the
  rollout stalls rather than taking image updating down. Verified:

  ```
  Error: could not configure CA certificates for registry Demo Registry:
    could not read CA file /app/config/registry-certs/does-not-exist.crt:
    open ...: no such file or directory
  ```
* **Auto-discovery keys are hostnames, never `host:port`.** The path is built
  from `url.Hostname()` of `api_url`, which strips the port. A key named
  `registry.example.com:5000` is never found.
* **`insecure: true` skips all of it**, including `ca_data`. It is the escape
  hatch this feature exists to replace.

---

## 2. What you get

```
demo/custom-ca-registry/
├── demo.sh               # the driver; ./demo.sh help lists every command
├── k3d-registries.yaml   # containerd config so the kubelet can pull demo images
└── README.md
```

The environment `./demo.sh up` builds:

```
k3d cluster "ca-demo"
├── namespace demo-registry
│   └── registry:3, self-signed cert, Service :443 → NodePort 30000
│       holding demo/app:1.0.0, :1.0.1, :1.0.2   (nginx 1.25/1.26/1.27-alpine)
├── namespace argocd
│   ├── Argo CD (stable manifests)
│   ├── argocd-image-updater-controller  (config/install.yaml from this tree)
│   ├── Application  demo-app       → kustomize image override, starts at 1.0.0
│   └── ImageUpdater demo-app       → 127.0.0.1:30000/demo/app:~1.0, semver
└── namespace demo
    └── the Deployment Argo CD syncs, running the image from the private registry
```

Two addresses for one registry, which is the point of the `prefix` /
`api_url` split:

* `api_url: https://demo-registry.demo-registry.svc.cluster.local` — what the
  controller dials, and the name on the certificate.
* `prefix: 127.0.0.1:30000` — how images are written in the manifests, reachable
  both from the node (kubelet pulls) and from your laptop (port published by k3d).

### Prerequisites

`docker` (running), `k3d`, `kubectl`, `openssl` (OpenSSL 3.x or LibreSSL with
`-addext`), and `make`. No Go toolchain is needed on the host — the controller is
compiled inside the Docker build. No changes to your Docker daemon configuration
are needed either, because the demo images are pushed from a Job inside the
cluster rather than from your host.

Verified on macOS/arm64 with Rancher Desktop (moby backend), k3d 5 and Argo CD
stable.

---

## 3. Run it

```bash
cd demo/custom-ca-registry
./demo.sh up          # ~10 min on a cold cache, mostly the controller image build
```

Use a published image instead of building from the working tree if you prefer:

```bash
BUILD_IMAGE=no IMAGE_UPDATER_IMAGE=quay.io/argoprojlabs/argocd-image-updater:latest ./demo.sh up
```

### Act 1 — it does not work

`up` leaves the registry entry deliberately bare:

```yaml
registries:
- name: Demo Registry
  api_url: https://demo-registry.demo-registry.svc.cluster.local
  prefix: 127.0.0.1:30000
```

```bash
./demo.sh tls-logs
```

```
level=error msg="Could not get tags from registry: Get
  \"https://demo-registry.demo-registry.svc.cluster.local/v2/\":
  tls: failed to verify certificate: x509: certificate signed by unknown authority"
  image_name="127.0.0.1:30000/demo/app" image_registry="127.0.0.1:30000" logger=reconcile
```

Note the two addresses in that one line: the updater dialled the `api_url`
(`demo-registry...svc.cluster.local`) while the image it is tracking is named
after the `prefix` (`127.0.0.1:30000`).

The registry is healthy and holds three tags — `./demo.sh tags` proves it — the
controller just refuses to trust it. Nothing is updated:

```bash
./demo.sh status      # Application still pinned to :1.0.0
```

### Act 2 — `ca_data`

```bash
./demo.sh ca-data
./demo.sh status
```

`registries.conf` now carries the PEM inline and the controller restarted. Within
a reconcile cycle (the demo sets `interval: 30s`) the log turns into:

```
level=info msg="Successfully updated image '127.0.0.1:30000/demo/app:1.0.0'
  to '127.0.0.1:30000/demo/app:1.0.2'" logger=reconcile
level=info msg="Successfully updated the live application spec" logger=reconcile
```

and `status` reports:

```
  Application image override
    quay.io/dkarpele/my-guestbook=127.0.0.1:30000/demo/app:1.0.2
  running image
    e2e-registry    127.0.0.1:30000/demo/app:1.0.2
```

(`e2e-registry` is just the Deployment name in the upstream guestbook test
manifest — it is the demo application, not the registry.)

Argo CD picks up the changed Application spec and rolls the Deployment, so the
pod in namespace `demo` is now running the 1.0.2 image pulled from the private
registry. `./demo.sh tls-logs` shows the tag list succeeding and the kustomize
parameter being written.

### Act 3 — the other two methods

```bash
./demo.sh reset            # Application back to :1.0.0
./demo.sh ca-file          # method 2
./demo.sh status           # ... back up at :1.0.2

./demo.sh reset
./demo.sh auto-discovery   # method 3 — nothing in registries.conf at all
./demo.sh status
```

`./demo.sh no-ca` returns to the failing state at any point, which makes a nice
A/B if someone asks "is it really the certificate doing the work?".

### Optional — the same contrast in three seconds

`argocd-image-updater test` resolves a tag through exactly the same registry code
path as the reconciler, without waiting for a reconcile cycle. `./demo.sh
test-cli` runs it twice as a one-shot pod built from the same image the
controller runs — once without the CA and once with `ca_data`:

```
1) resolving the tag WITHOUT the CA certificate
  level=fatal msg="could not get tags: ... x509: certificate signed by unknown authority"

2) the same call WITH ca_data
  level=info msg="Found 3 tags in registry"
  level=info msg="latest image according to constraint is 127.0.0.1:30000/demo/app:1.0.2"
```

It leaves the running controller untouched, so it is safe to use at any point —
including as the opening act, before anyone has looked at a Deployment.

### Teardown

```bash
./demo.sh down
```

---

## 4. What the vanilla install changes

With argocd-operator, `argocd-tls-certs-cm` is mounted into the image updater at
`/app/config/tls` for you, so methods 2 and 3 are pure configuration. The
vanilla manifest (`config/install.yaml`) mounts something else there:

```yaml
- name: argocd-image-updater-tls      # the webhook server's serving certificate
  mountPath: /app/config/tls
```

So on a vanilla install:

| Method | Extra work on vanilla |
|---|---|
| `ca_data` | none |
| `ca_file` | mount `argocd-tls-certs-cm` anywhere and point `ca_file` at it — the demo uses `/app/config/registry-certs` |
| auto-discovery | the CA **must** be at `/app/config/tls/<hostname>`, so that mount has to be repointed at `argocd-tls-certs-cm` (what `./demo.sh auto-discovery` patches) |

If you enable the webhook server *and* want auto-discovery, the two need to
share the directory — a projected volume combining the `argocd-image-updater-tls`
Secret and the `argocd-tls-certs-cm` ConfigMap. Worth mentioning as the one rough
edge, and as an argument for `ca_data`/`ca_file` outside of operator-managed
installs.

Reusing Argo CD's own `argocd-tls-certs-cm` is deliberate for methods 2 and 3:
one ConfigMap holds the private CAs for both Git repositories and registries.

---

## 5. Troubleshooting

| Symptom | Cause |
|---|---|
| `x509: certificate signed by unknown authority` | no CA reached the controller: check `./demo.sh status`, then that the pod restarted after the ConfigMap changed |
| `x509: certificate is valid for X, not Y` | `api_url`'s host is not a SAN on the certificate. Go ignores the Common Name |
| New controller pod in `CrashLoopBackOff`, old one still `Running` | `ca_file` points at a missing file, or the PEM does not parse — `kubectl logs` on the crashing pod shows `could not configure CA certificates for registry` |
| Nothing happens, no errors | the image is not in the Application's live images and `forceUpdate` is off; or the `prefix` does not match the image name in the manifests |
| Auto-discovery ignored | the ConfigMap key has a port in it, or the controller was not restarted |
| `registries.conf` empty after a reinstall | `config/install.yaml` ships `argocd-image-updater-config` with **no `data:`**, and applying it (server-side especially) claims the whole object and drops your keys. Always write the ConfigMap *after* installing the controller, never before |
| `ca_data` shows up as its own ConfigMap key | the inline PEM was spliced in at the wrong indentation and ended the `registries.conf: |` block early. Check with `kubectl get cm argocd-image-updater-config -o jsonpath='{.data}'` |
| App pod `ImagePullBackOff` | the node does not trust the registry; `k3d-registries.yaml` handles that for the demo cluster only |

Useful one-liners:

```bash
kubectl -n argocd exec deploy/argocd-image-updater-controller -- ls -l /app/config/tls /app/config/registry-certs
kubectl -n argocd get cm argocd-image-updater-config -o go-template='{{index .data "registries.conf"}}'
kubectl -n demo-registry logs deploy/demo-registry | tail
```

---

## 6. Related material

* Implementation: `registry-scanner/pkg/registry/config.go`
  (`newRegistryEndpointFromConfig`, `discoverArgoCDCAFile`, `loadRootCAs`)
* Reference docs: `docs/configuration/registries.md` (`ca_file`, `ca_data`)
* E2E coverage: `test/ginkgo/parallel/1-012-custom-ca-registry_test.go` — the same
  three methods against the operator-managed deployment
