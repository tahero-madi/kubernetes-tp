#!/usr/bin/env bash
# prep-node.sh — Prépare un nœud Kubernetes : étapes 1 à 5 du TP1
# Formation Kubernetes – Mise en œuvre (INSEE, 14–16 octobre 2026)
#
# Usage   : sudo bash prep-node.sh <nom-du-noeud> <IP-k8s-cp> <IP-k8s-w1> <IP-k8s-w2>
# Exemple : sudo bash prep-node.sh k8s-w1 10.10.0.10 10.10.0.20 10.10.0.30
# Cible   : Ubuntu Server 24.04 LTS, Kubernetes 1.37, containerd 2.x (dépôt Docker)
set -euo pipefail

KUBE_VERSION="v1.37"

if [[ $EUID -ne 0 ]]; then
  echo "À lancer avec sudo." >&2
  exit 1
fi
if [[ $# -ne 4 ]]; then
  echo "Usage : sudo bash $0 <nom-du-noeud> <IP-k8s-cp> <IP-k8s-w1> <IP-k8s-w2>" >&2
  exit 1
fi
NOM="$1"; IP_CP="$2"; IP_W1="$3"; IP_W2="$4"

etape() { echo; echo "==> $*"; }

etape "1. Nom d'hôte ($NOM) et résolution des 3 nœuds"
hostnamectl set-hostname "$NOM"
# VM cloud : empêcher cloud-init de rétablir le nom et /etc/hosts au redémarrage
if [[ -d /etc/cloud/cloud.cfg.d ]]; then
  printf 'preserve_hostname: true\nmanage_etc_hosts: false\n' > /etc/cloud/cloud.cfg.d/99-formation.cfg
fi
sed -i -E '/[[:space:]]k8s-(cp|w1|w2)$/d' /etc/hosts
printf '%s k8s-cp\n%s k8s-w1\n%s k8s-w2\n' "$IP_CP" "$IP_W1" "$IP_W2" >> /etc/hosts

etape "2. Désactivation du swap"
swapoff -a
sed -i -E '/[[:space:]]swap[[:space:]]/ s/^([^#])/#\1/' /etc/fstab

etape "3. Modules noyau et paramètres réseau"
printf 'overlay\nbr_netfilter\n' > /etc/modules-load.d/k8s.conf
modprobe overlay
modprobe br_netfilter
printf 'net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1\n' > /etc/sysctl.d/k8s.conf
sysctl --system > /dev/null

etape "4. containerd 2.x depuis le dépôt Docker"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q ca-certificates curl gpg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -q
apt-get install -y -q containerd.io
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
if ! grep -q 'SystemdCgroup = true' /etc/containerd/config.toml; then
  echo "SystemdCgroup = true introuvable dans /etc/containerd/config.toml" >&2
  exit 1
fi
systemctl restart containerd
systemctl enable containerd

etape "5. kubeadm, kubelet, kubectl ${KUBE_VERSION} et crictl (cri-tools)"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${KUBE_VERSION}/deb/Release.key" \
  | gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBE_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -q
# cri-tools fournit crictl : les paquets kubeadm récents ne l'installent plus automatiquement
apt-get install -y -q kubelet kubeadm kubectl cri-tools
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet
# Équivaut à "crictl config --set runtime-endpoint=..." sans son avertissement de premier lancement
printf 'runtime-endpoint: unix:///run/containerd/containerd.sock\n' > /etc/crictl.yaml

etape "Contrôle (point de contrôle du TP1)"
echo "containerd : $(containerd --version | awk '{print $3}')   (attendu : 2.x)"
echo "kubeadm    : $(kubeadm version -o short)   (attendu : v1.37.x)"
echo "crictl     : $(crictl --version | awk '{print $3}')   (attendu : v1.37.x ou proche)"
echo "nom d'hôte : $(hostname)   (attendu : ${NOM})"
echo "swap actif : $(swapon --show --noheadings | wc -l) zone(s)   (attendu : 0)"
echo "ip_forward : $(sysctl -n net.ipv4.ip_forward)   (attendu : 1)"
echo
echo "Nœud ${NOM} prêt. kubelet redémarre en boucle jusqu'au 'kubeadm join' : c'est normal."
