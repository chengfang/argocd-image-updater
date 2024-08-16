This is a simple e2e test case that uses public container registry and public github repo.

To run this individual test case,
* make sure both docker daemon and k8s cluster is running
* cd `$HOME/go/src/image-updater/test/e2e`
```bash
SRC_DIR=$HOME/go/src/image-updater kubectl kuttl test --namespace argocd-image-updater-e2e --timeout 120 --test 111-simple-kustomize-app-semver
```
Test output:
```bash
=== RUN   kuttl
    harness.go:464: starting setup
    harness.go:255: running tests using configured kubeconfig.
    harness.go:278: Successful connection to cluster at: https://0.0.0.0:55975
    harness.go:363: running tests
    harness.go:75: going to run test suite with timeout of 120 seconds for each step
    harness.go:375: testsuite: ./suite has 5 tests
=== RUN   kuttl/harness
=== RUN   kuttl/harness/111-simple-kustomize-app-semver
=== PAUSE kuttl/harness/111-simple-kustomize-app-semver
=== CONT  kuttl/harness/111-simple-kustomize-app-semver
    logger.go:42: 10:35:38 | 111-simple-kustomize-app-semver | Skipping creation of user-supplied namespace: argocd-image-updater-e2e
    logger.go:42: 10:35:38 | 111-simple-kustomize-app-semver/1-install | starting test step 1-install
    logger.go:42: 10:35:38 | 111-simple-kustomize-app-semver/1-install | Namespace:/image-updater-e2e-111 created
    logger.go:42: 10:35:38 | 111-simple-kustomize-app-semver/1-install | Application:argocd-image-updater-e2e/image-updater-111 created
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/1-install | test step completed 1-install
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | starting test step 2-run-updater
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | running command: [sh -c ${SRC_DIR}/dist/argocd-image-updater run --once \
          --argocd-namespace argocd-image-updater-e2e \
          --loglevel trace
        ]
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="argocd-image-updater v99.9.9+2bf4b0a starting [loglevel:TRACE, interval:once, healthport:off]"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=warning msg="commit message template at /app/config/commit.template does not exist, using default"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Successfully parsed commit message template"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=warning msg="Registry configuration at /app/config/registries.conf could not be read: stat /app/config/registries.conf: no such file or directory -- using default configuration"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Creating in-cluster Kubernetes client"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="ArgoCD configuration: [apiKind=kubernetes, server=argocd-server.argocd-image-updater-e2e, auth_token=false, insecure=false, grpc_web=false, plaintext=false]"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="Starting metrics server on TCP port=8081"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="Warming up image cache"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="processing app 'argocd-image-updater-e2e/image-updater-111' of type 'Kustomize'" application=image-updater-111 namespace=argocd-image-updater-e2e
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Processing application argocd-image-updater-e2e/image-updater-111"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Considering this image for update" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="setting rate limit to 20 requests per second" prefix=gcr.io registry="https://gcr.io"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Inferred registry from prefix gcr.io to use API https://gcr.io"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Using version constraint '~0' when looking for a new tag" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No sort option found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No match annotation found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No ignore-tags annotation found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="Using runtime platform constraint darwin/arm64" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No pull-secret annotation found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="Performing HTTP GET https://gcr.io/v2/heptio-images/ks-guestbook-demo/tags/list"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="List of available tags found: [0.1 0.2]" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="Finding out whether to consider 0.1 for being updateable" image="gcr.io/heptio-images/ks-guestbook-demo:0.1"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="Finding out whether to consider 0.2 for being updateable" image="gcr.io/heptio-images/ks-guestbook-demo:0.1"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="found 2 from 2 tags eligible for consideration" image="gcr.io/heptio-images/ks-guestbook-demo:0.1"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="Setting new image to gcr.io/heptio-images/ks-guestbook-demo:0.2" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="Setting Kustomize parameter gcr.io/heptio-images/ks-guestbook-demo:0.2" application=image-updater-111
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="Successfully updated image 'gcr.io/heptio-images/ks-guestbook-demo:0.1' to 'gcr.io/heptio-images/ks-guestbook-demo:0.2', but pending spec update (dry run=true)" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Using commit message: "
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="Dry run - not committing 1 changes to application" application=image-updater-111
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="Finished cache warm-up, pre-loaded 0 meta data entries from 2 registries"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Starting askpass server"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="processing app 'argocd-image-updater-e2e/image-updater-111' of type 'Kustomize'" application=image-updater-111 namespace=argocd-image-updater-e2e
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=info msg="Starting image update cycle, considering 1 annotated application(s) for update"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Processing application argocd-image-updater-e2e/image-updater-111"
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Considering this image for update" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=debug msg="Using version constraint '~0' when looking for a new tag" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No sort option found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No match annotation found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No ignore-tags annotation found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="Using runtime platform constraint darwin/arm64" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="No pull-secret annotation found" image_alias=guestbook image_digest= image_name=gcr.io/heptio-images/ks-guestbook-demo image_tag="~0" registry_url=gcr.io
    logger.go:42: 10:35:41 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:41-04:00" level=trace msg="Performing HTTP GET https://gcr.io/v2/heptio-images/ks-guestbook-demo/tags/list"
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=trace msg="List of available tags found: [0.1 0.2]" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=trace msg="Finding out whether to consider 0.1 for being updateable" image="gcr.io/heptio-images/ks-guestbook-demo:0.1"
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=trace msg="Finding out whether to consider 0.2 for being updateable" image="gcr.io/heptio-images/ks-guestbook-demo:0.1"
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=debug msg="found 2 from 2 tags eligible for consideration" image="gcr.io/heptio-images/ks-guestbook-demo:0.1"
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=info msg="Setting new image to gcr.io/heptio-images/ks-guestbook-demo:0.2" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=trace msg="Setting Kustomize parameter gcr.io/heptio-images/ks-guestbook-demo:0.2" application=image-updater-111
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=info msg="Successfully updated image 'gcr.io/heptio-images/ks-guestbook-demo:0.1' to 'gcr.io/heptio-images/ks-guestbook-demo:0.2', but pending spec update (dry run=false)" alias=guestbook application=image-updater-111 image_name=heptio-images/ks-guestbook-demo image_tag=0.1 registry=gcr.io
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=debug msg="Using commit message: "
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=info msg="Committing 1 parameter update(s) for application image-updater-111" application=image-updater-111
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | W0816 10:35:42.217945    9841 warnings.go:70] unknown field "status.history[0].initiatedBy"
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=info msg="Successfully updated the live application spec" application=image-updater-111
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=info msg="Processing results: applications=1 images_considered=1 images_skipped=0 images_updated=1 errors=0"
    logger.go:42: 10:35:42 | 111-simple-kustomize-app-semver/2-run-updater | time="2024-08-16T10:35:42-04:00" level=info msg=Finished.
    logger.go:42: 10:35:53 | 111-simple-kustomize-app-semver/2-run-updater | test step completed 2-run-updater
    logger.go:42: 10:35:53 | 111-simple-kustomize-app-semver/99-delete | starting test step 99-delete
    logger.go:42: 10:36:35 | 111-simple-kustomize-app-semver/99-delete | test step completed 99-delete
    logger.go:42: 10:36:35 | 111-simple-kustomize-app-semver | skipping kubernetes event logging
=== NAME  kuttl
    harness.go:407: run tests finished
    harness.go:515: cleaning up
    harness.go:572: removing temp folder: ""
--- PASS: kuttl (57.53s)
    --- PASS: kuttl/harness (0.00s)
        --- PASS: kuttl/harness/111-simple-kustomize-app-semver (57.52s)
PASS
```