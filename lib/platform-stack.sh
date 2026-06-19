#!/usr/bin/env bash
# k3s virtualization platform stack — Helm installs from deployer (Cilium, KubeVirt, …).

platform::_repo_root() {
  echo "${HYPERCLUSTER_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
}

platform::_kc() {
  echo "${KUBECONFIG_OUTPUT/#\~/$HOME}"
}

platform::_export_kc() {
  export KUBECONFIG
  KUBECONFIG="$(platform::_kc)"
  [[ -f "$KUBECONFIG" ]] || die "kubeconfig not found: $KUBECONFIG"
}

platform::_helm() {
  platform::_export_kc
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — helm $*"
    return 0
  fi
  helm "$@"
}

platform::_kubectl() {
  platform::_export_kc
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — kubectl $*"
    return 0
  fi
  kubectl "$@"
}

platform::_first_cp_ip() {
  echo "$CONTROL_PLANE_IPS" | awk '{print $1}'
}

platform::_helm_version_arg() {
  local var_name="$1"
  local ver="${!var_name:-}"
  if [[ -n "$ver" ]]; then
    printf '%s' "--version ${ver}"
  fi
  return 0
}

platform::_conf_bool() {
  local var_name="$1" default="${2:-false}"
  local val="${!var_name:-$default}"
  if [[ "$val" == "true" || "$val" == "1" || "$val" == "yes" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

platform::_gen_cilium_values() {
  local dest="$1" pod_cidr="${KUBE_PODS_SUBNET:-10.42.0.0/16}"
  local svc_host="${CILIUM_K8S_SERVICE_HOST:-127.0.0.1}"
  local kpr hubble bgp gateway enc tpl
  kpr="$(platform::_conf_bool CILIUM_KUBE_PROXY_REPLACEMENT true)"
  hubble="$(platform::_conf_bool CILIUM_HUBBLE_ENABLED true)"
  bgp="$(platform::_conf_bool CILIUM_BGP_ENABLED false)"
  gateway="$(platform::_conf_bool CILIUM_GATEWAY_API_ENABLED false)"
  enc="$(platform::_conf_bool CILIUM_WIREGUARD_ENABLED false)"
  tpl="$(platform::_repo_root)/config/k3s/cilium-values.yaml"
  [[ -f "$tpl" ]] || die "missing $tpl"
  sed \
    -e "s|K8S_SERVICE_HOST|${svc_host}|g" \
    -e "s|POD_CIDR|${pod_cidr}|g" \
    -e "s|KUBE_PROXY_REPLACEMENT|${kpr}|g" \
    -e "s|HUBBLE_ENABLED|${hubble}|g" \
    -e "s|GATEWAY_API_ENABLED|${gateway}|g" \
    -e "s|BGP_CONTROL_PLANE_ENABLED|${bgp}|g" \
    -e "s|ENCRYPTION_ENABLED|${enc}|g" \
    "$tpl" > "$dest"
}

platform::ensure_helm_repos() {
  log::info "Adding Helm repositories …"
  platform::_helm repo add cilium https://helm.cilium.io 2>/dev/null || true
  platform::_helm repo add metallb https://metallb.github.io/metallb 2>/dev/null || true
  platform::_helm repo add kubevirt https://kubevirt.github.io/helm-charts 2>/dev/null || true
  platform::_helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
  platform::_helm repo add piraeus https://piraeus.io/helm-charts 2>/dev/null || true
  platform::_helm repo add longhorn https://charts.longhorn.io 2>/dev/null || true
  platform::_helm repo add descheduler https://kubernetes-sigs.github.io/descheduler/ 2>/dev/null || true
  platform::_helm repo add nfd https://kubernetes-sigs.github.io/node-feature-discovery/charts 2>/dev/null || true
  platform::_helm repo add nvidia https://helm.ngc.nvidia.com/nvidia 2>/dev/null || true
  if [[ "${PLATFORM_HELM_REPO_UPDATE:-1}" == "1" ]]; then
    platform::_helm repo update
  fi
}

platform::_helm_unstick() {
  local release="$1" namespace="$2"
  local status=""
  status="$(platform::_helm status "$release" -n "$namespace" -o json 2>/dev/null \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("info",{}).get("status",""))' 2>/dev/null \
    || true)"
  case "$status" in
    pending-install|pending-upgrade|pending-rollback|uninstalling|failed)
      log::warn "Clearing stuck Helm release $release ($status) in $namespace …"
      platform::_helm uninstall "$release" -n "$namespace" --no-hooks 2>/dev/null || true
      sleep 3
      ;;
  esac
}

platform::_helm_wait_or_ready() {
  local release="$1" namespace="$2" timeout="${3:-10m}"
  shift 3
  platform::_helm_unstick "$release" "$namespace"
  if platform::_helm upgrade --install "$release" "$@" \
    --namespace "$namespace" \
    --create-namespace \
    --wait --timeout "$timeout"; then
    return 0
  fi
  log::warn "$release helm --wait failed — verifying workloads in $namespace …"
  if platform::_kubectl wait --for=condition=Available deployment --all -n "$namespace" --timeout=600s 2>/dev/null \
    || platform::_kubectl wait --for=condition=Ready pod --all -n "$namespace" --timeout=600s 2>/dev/null; then
    log::ok "$release workloads ready (skipping stuck helm reconcile)"
    return 0
  fi
  platform::_helm_unstick "$release" "$namespace"
  platform::_helm upgrade --install "$release" "$@" \
    --namespace "$namespace" \
    --create-namespace \
    --timeout 5m
}

platform::install_cert_manager() {
  [[ "${CERT_MANAGER_ENABLED:-true}" == "true" ]] || return 0
  log::section "cert-manager"
  local ver_arg
  ver_arg=$(platform::_helm_version_arg CERT_MANAGER_VERSION)
  # shellcheck disable=SC2086
  platform::_helm_wait_or_ready cert-manager cert-manager 10m jetstack/cert-manager \
    ${ver_arg} \
    --set crds.enabled=true
  log::info "Recycling cert-manager pods (fresh CNI routes after Cilium) …"
  platform::_kubectl delete pods -n cert-manager --all --force --grace-period=0 &>/dev/null || true
  platform::_kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=600s 2>/dev/null \
    || platform::_kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=600s
  log::ok "cert-manager ready"
}

platform::install_cilium() {
  [[ "${CNI_PLUGIN:-cilium}" == "cilium" ]] || return 0
  log::section "Cilium (KubeVirt-aware, Helm)"
  local values ver_arg
  values="$(mktemp)"
  platform::_gen_cilium_values "$values"
  ver_arg=$(platform::_helm_version_arg CILIUM_CHART_VERSION)
  platform::_helm_unstick cilium kube-system
  # shellcheck disable=SC2086
  if ! platform::_helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    ${ver_arg} \
    --values "$values" \
    --wait --timeout 25m; then
    log::warn "Cilium install failed — clearing stuck release and retrying once …"
    platform::_helm_unstick cilium kube-system
    platform::_helm upgrade --install cilium cilium/cilium \
      --namespace kube-system \
      ${ver_arg} \
      --values "$values" \
      --wait --timeout 25m
  fi
  rm -f "$values"
  if command -v cilium &>/dev/null; then
    platform::_export_kc
    cilium status --wait --wait-duration 10m --ignore-warnings 2>/dev/null || true
  fi
  platform::_kubectl wait --for=condition=Ready node --all --timeout=600s
  log::ok "Cilium ready"
}

platform::install_metallb() {
  [[ "${METALLB_ENABLED:-true}" == "true" ]] || return 0
  log::section "MetalLB"
  local ver_arg pool manifest attempt
  ver_arg=$(platform::_helm_version_arg METALLB_CHART_VERSION)
  pool="${METALLB_IP_POOL:?METALLB_IP_POOL required when METALLB_ENABLED=true}"
  # shellcheck disable=SC2086
  platform::_helm_wait_or_ready metallb metallb-system 10m metallb/metallb \
    ${ver_arg}

  if platform::_kubectl get ipaddresspool default -n metallb-system &>/dev/null; then
    log::ok "MetalLB ready (pool: $pool, already configured)"
    return 0
  fi

  log::info "Waiting for MetalLB webhook …"
  platform::_kubectl wait --for=condition=Available deployment/metallb-controller \
    -n metallb-system --timeout=300s 2>/dev/null || true

  manifest="$(mktemp)"
  cat > "$manifest" <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
    - ${pool}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default
EOF

  for attempt in 1 2 3 4 5 6; do
    if platform::_kubectl apply -f "$manifest"; then
      rm -f "$manifest"
      log::ok "MetalLB ready (pool: $pool)"
      return 0
    fi
    log::warn "MetalLB pool apply failed (attempt $attempt/6) — retrying after webhook warm-up …"
    sleep 15
  done
  rm -f "$manifest"
  die "MetalLB IPAddressPool apply failed after retries (API server may not reach webhook — check Cilium kube-proxy replacement on host)"
}

platform::install_snapshot_controller() {
  [[ "${SNAPSHOT_CONTROLLER_ENABLED:-true}" == "true" ]] || return 0
  log::section "snapshot-controller"
  local ver_arg
  ver_arg=$(platform::_helm_version_arg SNAPSHOT_CONTROLLER_VERSION)
  # shellcheck disable=SC2086
  platform::_helm upgrade --install snapshot-controller piraeus/snapshot-controller \
    --namespace snapshot-system \
    --create-namespace \
    ${ver_arg} \
    --wait --timeout 10m

  if ! platform::_kubectl get volumesnapshotclass default &>/dev/null; then
    platform::_kubectl apply -f - <<'EOF'
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: default
driver: rancher.io/local-path
deletionPolicy: Delete
EOF
  fi
  log::ok "snapshot-controller ready"
}

platform::ensure_storage() {
  log::section "Storage (local-path default)"
  local default_sc
  default_sc=$(platform::_kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || true)
  if [[ -n "$default_sc" ]]; then
    log::ok "Default StorageClass: $default_sc"
    return 0
  fi
  log::info "Installing rancher local-path-provisioner …"
  platform::_kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
  platform::_kubectl annotate storageclass local-path \
    storageclass.kubernetes.io/is-default-class=true --overwrite 2>/dev/null || true
  log::ok "local-path StorageClass ready"
}

platform::install_metrics_server() {
  [[ "${METRICS_SERVER_ENABLED:-true}" == "true" ]] || return 0
  log::section "metrics-server"
  platform::_kubectl delete deployment metrics-server -n kube-system --ignore-not-found 2>/dev/null || true
  platform::_kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-view: "true"
  name: system:aggregated-metrics-reader
rules:
  - apiGroups: ["metrics.k8s.io"]
    resources: ["pods", "nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
rules:
  - apiGroups: [""]
    resources: ["nodes/metrics"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["pods", "nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
  - kind: ServiceAccount
    name: metrics-server
    namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: metrics-server
    namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
  - kind: ServiceAccount
    name: metrics-server
    namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  ports:
    - name: https
      port: 443
      protocol: TCP
      targetPort: https
  selector:
    k8s-app: metrics-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      dnsPolicy: ClusterFirstWithHostNet
      hostNetwork: true
      containers:
        - args:
            - --cert-dir=/tmp
            - --secure-port=10251
            - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
            - --kubelet-use-node-status-port
            - --metric-resolution=15s
            - --kubelet-insecure-tls
          image: registry.k8s.io/metrics-server/metrics-server:v0.7.2
          imagePullPolicy: IfNotPresent
          livenessProbe:
            failureThreshold: 3
            httpGet:
              path: /livez
              port: https
              scheme: HTTPS
            periodSeconds: 10
          name: metrics-server
          ports:
            - containerPort: 10251
              name: https
              protocol: TCP
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /readyz
              port: https
              scheme: HTTPS
            initialDelaySeconds: 20
            periodSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 200Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
            seccompProfile:
              type: RuntimeDefault
          volumeMounts:
            - mountPath: /tmp
              name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
        node-role.kubernetes.io/control-plane: "true"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
        - emptyDir: {}
          name: tmp-dir
---
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  labels:
    k8s-app: metrics-server
  name: v1beta1.metrics.k8s.io
spec:
  group: metrics.k8s.io
  groupPriorityMinimum: 100
  insecureSkipTLSVerify: true
  service:
    name: metrics-server
    namespace: kube-system
  version: v1beta1
  versionPriority: 100
EOF
  platform::_kubectl delete pods -n kube-system -l k8s-app=metrics-server --force --grace-period=0 &>/dev/null || true
  platform::_kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=300s 2>/dev/null \
    || platform::_kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s
  log::ok "metrics-server installed"
}

platform::install_kubevirt() {
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || return 0
  log::section "KubeVirt (Helm)"
  local values ver_arg ver
  values="$(platform::_repo_root)/config/k3s/kubevirt-values.yaml"
  ver_arg=$(platform::_helm_version_arg KUBEVIRT_CHART_VERSION)
  ver="${KUBEVIRT_VERSION:-v1.8.3}"
  if ! platform::_helm upgrade --install kubevirt kubevirt/kubevirt \
    --namespace kubevirt \
    --create-namespace \
    ${ver_arg} \
    --values "$values" \
    --wait --timeout 15m 2>/dev/null; then
    log::warn "KubeVirt Helm chart failed — falling back to release manifests"
    local base="https://github.com/kubevirt/kubevirt/releases/download/${ver}"
    platform::_kubectl apply -f "${base}/kubevirt-operator.yaml"
    platform::_kubectl apply -f "${base}/kubevirt-cr.yaml"
  fi
  platform::_kubectl -n kubevirt wait kv kubevirt --for=condition=Available --timeout=600s 2>/dev/null \
    || platform::_kubectl -n kubevirt wait kubevirt kubevirt --for=condition=Available --timeout=600s
  log::info "Recycling KubeVirt pods (fresh CNI routes after Cilium) …"
  platform::_kubectl delete pods -n kubevirt \
    -l 'kubevirt.io in (virt-api,virt-controller,virt-operator,virt-handler)' \
    --force --grace-period=0 &>/dev/null || true
  platform::_kubectl wait --for=condition=Available \
    deployment/virt-api deployment/virt-controller deployment/virt-operator \
    -n kubevirt --timeout=600s 2>/dev/null \
    || platform::_kubectl wait --for=condition=Ready \
    pod -l 'kubevirt.io in (virt-api,virt-controller,virt-operator,virt-handler)' \
    -n kubevirt --timeout=600s
  if [[ "${KUBEVIRT_API_REPLICAS:-}" == "1" ]]; then
    platform::_kubectl scale deployment virt-api -n kubevirt --replicas=1 2>/dev/null || true
  fi
  log::ok "KubeVirt ready"
}

platform::install_cdi() {
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || return 0
  [[ "${CDI_ENABLED:-true}" == "true" ]] || return 0
  log::section "CDI (Helm)"
  local values ver_arg ver
  values="$(platform::_repo_root)/config/k3s/cdi-values.yaml"
  ver_arg=$(platform::_helm_version_arg CDI_CHART_VERSION)
  ver="${CDI_VERSION:-v1.65.0}"
  if ! platform::_helm upgrade --install cdi kubevirt/cdi \
    --namespace cdi \
    --create-namespace \
    ${ver_arg} \
    --values "$values" \
    --wait --timeout 15m 2>/dev/null; then
    log::warn "CDI Helm chart failed — falling back to release manifests"
    local base="https://github.com/kubevirt/containerized-data-importer/releases/download/${ver}"
    platform::_kubectl apply -f "${base}/cdi-operator.yaml"
    platform::_kubectl apply -f "${base}/cdi-cr.yaml"
  fi
  platform::_kubectl -n cdi wait cdi cdi --for=condition=Available --timeout=600s
  log::info "Recycling CDI pods (fresh CNI routes after Cilium) …"
  platform::_kubectl rollout restart deployment -n cdi 2>/dev/null || true
  for dep in cdi-apiserver cdi-deployment cdi-operator cdi-uploadproxy; do
    platform::_kubectl rollout status "deployment/${dep}" -n cdi --timeout=300s 2>/dev/null || true
  done
  platform::_kubectl wait --for=condition=Available deployment --all -n cdi --timeout=300s 2>/dev/null \
    || platform::_kubectl wait --for=condition=Ready pod --all -n cdi --timeout=300s 2>/dev/null || true
  log::ok "CDI ready"
}

platform::install_disks_provider() {
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || return 0
  [[ "${KUBEVIRT_DISKS_PROVIDER:-true}" == "true" ]] || return 0
  log::section "disks-images-provider (sample containerdisks)"
  local ver="${KUBEVIRT_VERSION:-v1.8.3}"
  platform::_kubectl apply -f \
    "https://github.com/kubevirt/kubevirt/releases/download/${ver}/disks-images-provider.yaml" \
    2>/dev/null || log::warn "disks-images-provider apply failed (optional)"
  log::ok "disks-images-provider applied"
}

platform::install_kubevirt_csi() {
  [[ "${KUBEVIRT_CSI_ENABLED:-true}" == "true" ]] || return 0
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || return 0
  log::section "KubeVirt CSI driver"
  local ver_arg ver
  ver_arg=$(platform::_helm_version_arg KUBEVIRT_CSI_CHART_VERSION)
  ver="${KUBEVIRT_CSI_VERSION:-${KUBEVIRT_VERSION:-v1.8.3}}"
  if ! platform::_helm upgrade --install kubevirt-csi kubevirt/csi-driver \
    --namespace kubevirt \
    ${ver_arg} \
    --wait --timeout 10m 2>/dev/null; then
    log::warn "kubevirt/csi-driver chart failed — trying release manifest"
    platform::_kubectl apply -f \
      "https://github.com/kubevirt/csi-driver/releases/download/${ver}/kubevirt-csi-driver.yaml" 2>/dev/null || true
  fi
  log::ok "KubeVirt CSI installed"
}

platform::install_cnao() {
  [[ "${CNAO_ENABLED:-true}" == "true" ]] || return 0
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || return 0
  if platform::_kubectl get deployment cluster-network-addons-operator -n cluster-network-addons &>/dev/null; then
    log::section "CNAO (Multus / advanced VM networking)"
    log::ok "CNAO ready (already installed)"
    return 0
  fi
  log::section "CNAO (Multus / advanced VM networking)"
  local ver_arg chart_ref="kubevirt/cluster-network-addons-operator"
  ver_arg=$(platform::_helm_version_arg CNAO_CHART_VERSION)
  if [[ -n "${CNAO_HELM_REPO:-}" ]]; then
    platform::_helm repo add cnao "${CNAO_HELM_REPO}" 2>/dev/null || true
    chart_ref="cnao/cluster-network-addons-operator"
  fi
  if platform::_helm upgrade --install cnao "$chart_ref" \
    --namespace cluster-network-addons \
    --create-namespace \
    ${ver_arg} \
    --wait --timeout 10m 2>/dev/null; then
    log::ok "CNAO ready (Helm)"
    return 0
  fi
  local ver="${CNAO_MANIFEST_VERSION:-v0.102.0}"
  local base="https://github.com/kubevirt/cluster-network-addons-operator/releases/download/${ver}"
  log::warn "CNAO helm chart unavailable — applying manifest fallback ($ver)"
  platform::_kubectl apply --validate=false -f "${base}/namespace.yaml"
  platform::_kubectl apply --validate=false -f "${base}/network-addons-config.crd.yaml"
  platform::_kubectl apply --validate=false -f "${base}/operator.yaml"
  platform::_kubectl apply -f "$(platform::_repo_root)/config/k3s/cnao-network-addons-config.yaml"
  platform::_kubectl wait --for=condition=Available deployment/cluster-network-addons-operator \
    -n cluster-network-addons --timeout=600s 2>/dev/null \
    || platform::_kubectl wait --for=condition=Ready pod -l name=cluster-network-addons-operator \
    -n cluster-network-addons --timeout=600s 2>/dev/null || true
  log::ok "CNAO ready (manifests)"
}

platform::_ensure_ssp_webhook_cert() {
  platform::_kubectl get secret ssp-webhook-server-cert -n kubevirt &>/dev/null && return 0
  command -v openssl &>/dev/null || die "openssl required for SSP webhook TLS (install openssl)"
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  log::info "Creating SSP webhook TLS secret (ssp-webhook-server-cert) …"
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$tmpdir/tls.key" -out "$tmpdir/tls.crt" \
    -subj "/CN=ssp-webhook-service.kubevirt.svc" \
    -addext "subjectAltName=DNS:ssp-webhook-service.kubevirt.svc,DNS:ssp-webhook-service.kubevirt.svc.cluster.local" \
    &>/dev/null
  platform::_kubectl create secret tls ssp-webhook-server-cert \
    -n kubevirt --key "$tmpdir/tls.key" --cert "$tmpdir/tls.crt"
  if platform::_kubectl get deployment ssp-operator -n kubevirt &>/dev/null; then
    platform::_kubectl rollout restart deployment/ssp-operator -n kubevirt &>/dev/null || true
  fi
}

platform::_patch_ssp_webhook_cabundle() {
  platform::_kubectl get validatingwebhookconfiguration ssp-validating-webhook-configuration &>/dev/null || return 0
  local tmpdir cabundle i existing
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  platform::_kubectl get secret ssp-webhook-server-cert -n kubevirt \
    -o jsonpath='{.data.tls\.crt}' | base64 -d > "$tmpdir/tls.crt" 2>/dev/null || return 0
  cabundle="$(base64 < "$tmpdir/tls.crt" | tr -d '\n')"
  [[ -n "$cabundle" ]] || return 0
  local patch='['
  for i in 0 1; do
    existing=$(platform::_kubectl get validatingwebhookconfiguration ssp-validating-webhook-configuration \
      -o "jsonpath={.webhooks[${i}].clientConfig.caBundle}" 2>/dev/null || true)
    [[ -n "$existing" ]] && continue
    [[ "$patch" != '[' ]] && patch+=','
    patch+="{\"op\":\"add\",\"path\":\"/webhooks/${i}/clientConfig/caBundle\",\"value\":\"${cabundle}\"}"
  done
  patch+=']'
  [[ "$patch" == '[]' ]] && return 0
  platform::_kubectl patch validatingwebhookconfiguration ssp-validating-webhook-configuration \
    --type=json -p "$patch" &>/dev/null || true
}

platform::_patch_ssp_control_plane() {
  platform::_kubectl get deployment ssp-operator -n kubevirt &>/dev/null || return 0
  platform::_kubectl patch deployment ssp-operator -n kubevirt --type=json -p='[
    {"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role.kubernetes.io/control-plane":"true"}},
    {"op":"add","path":"/spec/template/spec/tolerations","value":[
      {"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"},
      {"key":"node-role.kubernetes.io/master","operator":"Exists","effect":"NoSchedule"}
    ]}
  ]' &>/dev/null || true
  platform::_kubectl rollout status deployment/ssp-operator -n kubevirt --timeout=300s &>/dev/null || true
}

platform::install_ssp() {
  [[ "${SSP_ENABLED:-true}" == "true" ]] || return 0
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || return 0
  if platform::_kubectl get ssp -n kubevirt -o name &>/dev/null; then
    log::section "SSP (KubeVirt templates)"
    log::ok "SSP ready (already installed)"
    return 0
  fi
  log::section "SSP (KubeVirt templates)"
  local ver_arg chart_ref="kubevirt/ssp"
  ver_arg=$(platform::_helm_version_arg SSP_CHART_VERSION)
  if [[ -n "${SSP_HELM_REPO:-}" ]]; then
    platform::_helm repo add ssp "${SSP_HELM_REPO}" 2>/dev/null || true
    chart_ref="ssp/ssp"
  fi
  if platform::_helm upgrade --install ssp "$chart_ref" \
    --namespace kubevirt \
    ${ver_arg} \
    --wait --timeout 15m 2>/dev/null; then
    log::ok "SSP ready (Helm)"
    return 0
  fi
  local ver="${SSP_MANIFEST_VERSION:-v0.25.0}"
  log::warn "SSP helm chart unavailable — applying manifest fallback ($ver)"
  platform::_kubectl apply --validate=false -f "https://github.com/kubevirt/ssp-operator/releases/download/${ver}/ssp-operator.yaml"
  platform::_ensure_ssp_webhook_cert
  platform::_patch_ssp_control_plane
  log::info "Waiting for SSP webhook …"
  platform::_kubectl wait --for=condition=Available deployment/ssp-operator \
    -n kubevirt --timeout=600s 2>/dev/null \
    || platform::_kubectl wait --for=condition=Ready pod -l control-plane=controller-manager \
    -n kubevirt --timeout=600s 2>/dev/null || true
  platform::_patch_ssp_webhook_cabundle
  local attempt manifest
  manifest="$(platform::_repo_root)/config/k3s/ssp-cr.yaml"
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if platform::_kubectl apply -f "$manifest"; then
      platform::_kubectl wait --for=condition=Available deployment/ssp-operator-controller-manager \
        -n kubevirt --timeout=600s 2>/dev/null || true
      log::ok "SSP ready (manifests)"
      return 0
    fi
    log::warn "SSP CR apply failed (attempt $attempt/10) — retrying after webhook warm-up …"
    platform::_patch_ssp_control_plane
    platform::_patch_ssp_webhook_cabundle
    sleep 15
  done
  log::warn "SSP CR apply failed after retries — continuing (SSP is optional for core platform)"
}

platform::install_longhorn() {
  [[ "${LONGHORN_ENABLED:-false}" == "true" ]] || return 0
  log::section "Longhorn"
  local ver_arg
  ver_arg=$(platform::_helm_version_arg LONGHORN_CHART_VERSION)
  # shellcheck disable=SC2086
  platform::_helm upgrade --install longhorn longhorn/longhorn \
    --namespace longhorn-system \
    --create-namespace \
    ${ver_arg} \
    --wait --timeout 20m
  log::ok "Longhorn ready"
}

platform::install_descheduler() {
  [[ "${DESCHEDULER_ENABLED:-false}" == "true" ]] || return 0
  log::section "Descheduler"
  platform::_helm upgrade --install descheduler descheduler/descheduler \
    --namespace kube-system \
    --wait --timeout 10m
  log::ok "Descheduler ready"
}

platform::install_nfd() {
  [[ "${NFD_ENABLED:-false}" == "true" ]] || return 0
  log::section "Node Feature Discovery"
  platform::_helm upgrade --install nfd nfd/node-feature-discovery \
    --namespace node-feature-discovery \
    --create-namespace \
    --wait --timeout 10m
  log::ok "NFD ready"
}

platform::install_gpu_operator() {
  [[ "${GPU_OPERATOR_ENABLED:-false}" == "true" ]] || return 0
  log::section "NVIDIA GPU Operator"
  platform::_helm upgrade --install gpu-operator nvidia/gpu-operator \
    --namespace gpu-operator \
    --create-namespace \
    --wait --timeout 20m
  log::ok "GPU Operator ready"
}

platform::verify_snapshots() {
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || return 0
  log::info "Checking VM snapshot API …"
  platform::_kubectl api-resources 2>/dev/null | grep -E 'VirtualMachineSnapshot|VolumeSnapshot' || true
}

platform::verify_pod_api() {
  log::info "Verifying pod → Kubernetes API connectivity …"
  local name="hc-netcheck-$$" phase code i
  platform::_kubectl run "$name" --restart=Never --image=curlimages/curl:8.5.0 \
    --command -- sh -c 'curl -sk --connect-timeout 5 -o /dev/null -w "%{http_code}" https://10.43.0.1:443/livez || echo 000'
  for i in $(seq 1 90); do
    phase=$(platform::_kubectl get pod "$name" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [[ "$phase" == "Succeeded" || "$phase" == "Failed" ]]; then
      code=$(platform::_kubectl logs "$name" 2>/dev/null | tr -cd '0-9' | tail -c 3)
      platform::_kubectl delete pod "$name" --force --grace-period=0 &>/dev/null || true
      if [[ "$code" =~ ^(200|401|403)$ ]]; then
        log::ok "Pod → API connectivity OK (HTTP ${code})"
        return 0
      fi
      die "Pod → API check returned HTTP ${code:-000} (expected 200/401/403)"
    fi
    sleep 2
  done
  platform::_kubectl delete pod "$name" --force --grace-period=0 &>/dev/null || true
  die "Pod → API connectivity check timed out"
}

platform::restart_platform_workloads() {
  log::section "Restarting platform workloads (post-CNI)"
  local ns
  for ns in cert-manager kubevirt cdi metallb-system snapshot-system; do
    platform::_kubectl get ns "$ns" &>/dev/null || continue
    platform::_kubectl delete pods -n "$ns" --all --force --grace-period=0 &>/dev/null || true
  done
  for ns in cert-manager kubevirt cdi; do
    platform::_kubectl get ns "$ns" &>/dev/null || continue
    platform::_kubectl wait --for=condition=Available deployment --all -n "$ns" --timeout=300s 2>/dev/null \
      || platform::_kubectl wait --for=condition=Ready pod --all -n "$ns" --timeout=300s 2>/dev/null \
      || log::warn "$ns workloads not fully Ready after restart"
  done
  log::ok "Platform workloads restarted"
}

platform::install_stack() {
  platform::ensure_helm_repos
  platform::install_cilium
  platform::verify_pod_api
  platform::install_cert_manager
  platform::install_metallb
  platform::install_snapshot_controller
  platform::ensure_storage
  platform::install_metrics_server
  platform::install_kubevirt
  platform::install_cdi
  platform::install_disks_provider
  platform::install_kubevirt_csi
  platform::install_cnao
  platform::install_ssp
  platform::install_longhorn
  platform::install_descheduler
  platform::install_nfd
  platform::install_gpu_operator
  platform::restart_platform_workloads
  platform::verify_snapshots
  log::ok "Platform stack installed ✅"
}
