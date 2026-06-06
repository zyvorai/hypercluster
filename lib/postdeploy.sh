#!/usr/bin/env bash
# Post-deploy next-step hints — source this file.

postdeploy::_kc() {
  echo "${KUBECONFIG_OUTPUT/#\~/$HOME}"
}

postdeploy::_first_cp_ip() {
  echo "$CONTROL_PLANE_IPS" | awk '{print $1}'
}

postdeploy::print_hints() {
  local kc cp_ip
  kc=$(postdeploy::_kc)
  cp_ip=$(postdeploy::_first_cp_ip)

  log::section "Next steps — cluster ready"
  echo ""
  printf "  \033[1mkubeconfig\033[0m\n"
  printf "    export KUBECONFIG=%s\n" "$kc"
  printf "    kubectl get nodes -o wide\n"
  echo ""

  printf "  \033[1mCluster status\033[0m\n"
  printf "    ./hypercluster -c %s status\n" "${CONFIG_FILE:-./cluster.conf}"
  echo ""

  case "${CNI_PLUGIN:-cilium}" in
    cilium)
      printf "  \033[1mCilium / Hubble\033[0m\n"
      if command -v cilium &>/dev/null; then
        printf "    cilium status --wait\n"
        printf "    cilium hubble ui\n"
      else
        printf "    kubectl -n kube-system get pods -l k8s-app=cilium\n"
        printf "    # Hubble UI (when hubble-ui service exists):\n"
        printf "    kubectl -n kube-system port-forward svc/hubble-ui 12000:80\n"
        printf "    # open http://127.0.0.1:12000\n"
      fi
      echo ""
      ;;
    calico)
      printf "  \033[1mCalico\033[0m\n"
      printf "    kubectl -n kube-system get pods -l k8s-app=calico-node\n"
      echo ""
      ;;
  esac

  if [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    printf "  \033[1mKubeVirt platform\033[0m\n"
    printf "    kubectl get kubevirt -n kubevirt\n"
    printf "    kubectl get cdi -n cdi\n"
    printf "    kubectl api-resources | grep -E 'VirtualMachineSnapshot|VolumeSnapshot'\n"
    if command -v virtctl &>/dev/null; then
      printf "    virtctl version\n"
    fi
    echo ""
  fi

  if [[ "${K8S_DISTRO:-kubespray}" == "k3s" ]]; then
    printf "  \033[1mRemote node\033[0m\n"
    printf "    ssh %s@%s\n" "${SSH_USER:-root}" "$cp_ip"
    printf "    cluster-info        # kubectl summary on the server\n"
    printf "    kubectl get nodes   # uses ~/.kube/config on the server\n"
    echo ""
    printf "  \033[1mVerify platform\033[0m\n"
    printf "    ./hypercluster -c %s test\n" "${CONFIG_FILE:-./cluster.conf}"
    echo ""
    printf "  \033[1mLab ops (single-node)\033[0m\n"
    printf "    ./hypercluster -c %s lab storage --status\n" "${CONFIG_FILE:-./cluster.conf}"
    printf "    ./hypercluster -c %s lab storage   # after LAB_SECONDARY_DISK in cluster.conf\n" "${CONFIG_FILE:-./cluster.conf}"
    printf "    ./hypercluster -c %s lab tune\n" "${CONFIG_FILE:-./cluster.conf}"
    printf "    ./hypercluster -c %s lab setup     # storage + tune from cluster.conf\n" "${CONFIG_FILE:-./cluster.conf}"
    echo ""
    if [[ "${METALLB_ENABLED:-true}" == "true" && -z "${METALLB_IP_POOL:-}" ]]; then
      printf "  \033[1mMetalLB\033[0m\n"
      printf "    # Set METALLB_IP_POOL in cluster.conf and re-run deploy for LoadBalancer IPs\n"
      echo ""
    fi
  fi

  if [[ "${DASHBOARD_ENABLED:-false}" == "true" ]]; then
    printf "  \033[1mKubernetes Dashboard\033[0m\n"
    printf "    kubectl -n kubernetes-dashboard create token admin-user --duration=24h\n"
    printf "    kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443\n"
    echo ""
  fi

  if [[ "${INGRESS_NGINX_ENABLED:-false}" == "true" ]]; then
    printf "  \033[1mIngress NGINX\033[0m\n"
    printf "    kubectl -n ingress-nginx get pods\n"
    echo ""
  fi

  printf "  \033[1mAPI server\033[0m\n"
  printf "    https://%s:6443\n" "$cp_ip"
  echo ""
}
