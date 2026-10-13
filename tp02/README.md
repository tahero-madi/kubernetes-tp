# TP2 — Initialiser le cluster, installer Calico, joindre les workers

**Jour 1, 13:15 · 75 min.** Objectif : obtenir un cluster de 3 nœuds `Ready`, avec réseau des pods et DNS interne fonctionnels. Support : sections 4.5 à 4.11.

## Étape 1 — Initialiser le control plane

**Pourquoi.** `kubeadm init` transforme `k8s-cp` en control plane : il crée les certificats du cluster, démarre etcd, l'API server, le scheduler et le controller-manager, puis prépare la commande qui permettra aux workers de rejoindre le cluster.

```bash
# [cp] avec l'IP privée de k8s-cp
hostname        # doit afficher k8s-cp : le nœud prendra ce nom, et il ne changera plus
sudo kubeadm init --apiserver-advertise-address=10.10.0.10 --pod-network-cidr=10.244.0.0/16
```

**Ligne par ligne.**

- `hostname` : dernière vérification du nom, que le nœud gardera.
- `sudo kubeadm init` : initialise le control plane ; `sudo` car il écrit dans `/etc/kubernetes` et démarre des services.
- `--apiserver-advertise-address=10.10.0.10` : l'adresse sur laquelle l'API server écoute et que les autres nœuds utiliseront. Sans elle, kubeadm prend l'interface réseau par défaut, pas forcément la bonne.
- `--pod-network-cidr=10.244.0.0/16` : la plage d'adresses réservée aux pods. Elle ne doit pas recouvrir le réseau des VM ; Calico la reprendra à l'étape 3.

La commande dure 1 à 3 minutes. À la fin, **copiez la commande `kubeadm join ...` affichée** dans un fichier texte : elle servira à l'étape 4.

## Étape 2 — Configurer kubectl et observer

**Pourquoi.** `kubectl` a besoin d'un fichier kubeconfig : l'adresse de l'API server, le certificat de l'autorité du cluster et votre identité. kubeadm a créé celui de l'administrateur dans `/etc/kubernetes/admin.conf`, lisible par root seulement ; on le copie dans votre dossier personnel, à l'emplacement que kubectl lit par défaut.

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes                  # k8s-cp NotReady
kubectl get pods -n kube-system    # coredns en Pending
ls /etc/kubernetes/manifests       # 4 fichiers : les pods statiques du control plane
ls /etc/kubernetes/pki             # les certificats du cluster
```

**Ligne par ligne.**

- `mkdir -p $HOME/.kube` : crée le dossier ; `-p` évite une erreur s'il existe déjà.
- `sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config` : copie le kubeconfig administrateur.
- `sudo chown $(id -u):$(id -g) $HOME/.kube/config` : vous en rend propriétaire, pour que kubectl puisse le lire sans sudo ; `$(id -u)` et `$(id -g)` sont vos numéros d'utilisateur et de groupe.
- `kubectl get nodes` : `NotReady`, car aucun réseau de pods n'est encore installé.
- `kubectl get pods -n kube-system` : les composants du cluster ; CoreDNS attend le réseau, d'où `Pending`.
- `ls /etc/kubernetes/manifests` : les 4 fichiers des pods statiques (etcd, API server, controller-manager, scheduler), que le kubelet lance lui-même sans passer par l'API.
- `ls /etc/kubernetes/pki` : les certificats et clés créés par kubeadm.

## Étape 3 — Installer Calico

**Pourquoi.** Kubernetes définit comment les pods doivent communiquer, mais ne fournit pas le réseau lui-même : c'est le rôle d'un plugin réseau (CNI), ici Calico. Calico s'installe par son opérateur, un programme qui tourne dans le cluster et le configure pour vous. On installe d'abord les nouveaux types d'objets qu'il comprend (les CRD), puis l'opérateur, puis un objet `Installation` qui décrit le réseau voulu : l'opérateur lit cet objet et déploie Calico en conséquence.

```bash
CALICO=v3.31.6
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO/manifests/operator-crds.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO/manifests/tigera-operator.yaml
cat ~/tp/tp02/calico-installation.yaml    # plage 10.244.0.0/16, encapsulation VXLAN
kubectl create -f ~/tp/tp02/calico-installation.yaml
watch kubectl get pods -n calico-system   # attendre que tout soit Running (2 à 4 min), puis Ctrl+C
kubectl get nodes                         # k8s-cp passe Ready
```

**Ligne par ligne.**

- `CALICO=v3.31.6` : la version de Calico, réutilisée dans les adresses qui suivent.
- `kubectl create -f …/operator-crds.yaml` : ajoute à l'API les types d'objets de Calico (Installation, IPPool…). On utilise `create` et non `apply`, car ces fichiers sont trop gros pour l'annotation que `apply` ajoute à chaque objet.
- `kubectl create -f …/tigera-operator.yaml` : déploie l'opérateur Tigera dans le namespace `tigera-operator`.
- `cat ~/tp/tp02/calico-installation.yaml` : lisez l'objet avant de l'envoyer : la plage 10.244.0.0/16, la même qu'au `kubeadm init`, et l'encapsulation VXLAN, qui transporte le trafic des pods entre nœuds dans des paquets UDP.
- `kubectl create -f ~/tp/tp02/calico-installation.yaml` : remet l'objet à l'opérateur, qui crée le namespace `calico-system` et ses pods.
- `watch kubectl get pods -n calico-system` : relance la commande toutes les 2 secondes ; attendez que tout soit `Running`.
- `kubectl get nodes` : `k8s-cp` passe `Ready` dès que le réseau fonctionne.

## Étape 4 — Joindre les workers

**Pourquoi.** Un worker rejoint le cluster avec un jeton, qui prouve qu'il est invité, et l'empreinte du certificat de l'autorité du cluster, qui prouve qu'il parle au bon control plane et non à un imposteur. `kubeadm join` configure ensuite son kubelet, qui s'inscrit auprès de l'API server.

> **Prédiction.** Juste après le `kubeadm join`, dans quel état `kubectl get nodes` montrera-t-il les workers, et pourquoi ?

Collez sur chaque worker la commande copiée à l'étape 1, précédée de `sudo` :

```bash
# [w1] puis [w2]
sudo kubeadm join 10.10.0.10:6443 --token <jeton> --discovery-token-ca-cert-hash sha256:<empreinte>
```

**Ligne par ligne.**

- `kubeadm join 10.10.0.10:6443` : l'adresse et le port de l'API server.
- `--token` : le jeton d'invitation, valable 24 heures.
- `--discovery-token-ca-cert-hash sha256:…` : l'empreinte du certificat de l'autorité ; le worker refuse de se joindre si le certificat présenté ne correspond pas.

Commande perdue ou jeton expiré ? Sur `k8s-cp` : `kubeadm token create --print-join-command`.

## Étape 5 — Vérifier le cluster

**Pourquoi.** Un cluster utilisable, ce sont trois nœuds prêts, tous les composants en marche et un DNS interne qui répond : c'est par le DNS que les applications se trouvent entre elles.

```bash
# [cp]
kubectl get nodes -o wide          # 3 nœuds Ready, v1.37.x, containerd://2.x
kubectl get pods -A                # tout en Running
kubectl run test-dns --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local
```

**Ligne par ligne.**

- `kubectl get nodes -o wide` : `-o wide` ajoute l'adresse IP, le système, le noyau et le runtime de chaque nœud.
- `kubectl get pods -A` : les pods de tous les namespaces (`-A`).
- `kubectl run test-dns --image=…busybox:1.36 --rm -it --restart=Never -- nslookup …` : crée un pod jetable. `--rm` le supprime à la fin, `-it` vous montre sa sortie, `--restart=Never` en fait un pod simple ; ce qui suit `--` est la commande exécutée dans le pod.

Le `nslookup` doit répondre avec l'adresse 10.96.0.1 : c'est le Service de l'API server.

## À vous, sans pas-à-pas

Retrouvez sur quel nœud tourne chaque pod CoreDNS et quelle est son adresse IP, puis vérifiez que cette adresse appartient bien au réseau des pods choisi au `kubeadm init`.

Indice : les pods CoreDNS portent le label `k8s-app=kube-dns` ; l'option `-o wide` affiche l'IP et le nœud.

## Point de contrôle

- [ ] `kubectl get nodes` affiche 3 nœuds `Ready`.
- [ ] Tous les pods de `kube-system` et `calico-system` sont `Running`.
- [ ] Le test DNS répond.

## Pour comprendre

1. Pourquoi les nœuds restent-ils `NotReady` tant que Calico n'est pas installé ?
2. Où se trouvent les définitions de l'API server, d'etcd et du scheduler, et qui les lance ?

## Bonus

```bash
sudo kubeadm certs check-expiration        # durée de vie des certificats
sudo ctr -n k8s.io containers ls | head    # les conteneurs lancés par Kubernetes
kubectl get tigerastatus                   # état de Calico vu par son opérateur
```

**Ligne par ligne.**

- `kubeadm certs check-expiration` : la date d'expiration de chaque certificat du cluster, un an par défaut ; un cluster dont les certificats expirent cesse de fonctionner.
- `ctr -n k8s.io containers ls | head` : les conteneurs créés par Kubernetes, que containerd range dans son espace `k8s.io`, séparé de celui où vous avez lancé nginx au TP1.
- `kubectl get tigerastatus` : l'état de Calico vu par son opérateur.


---

[← TP1](../tp01/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP3 →](../tp03/README.md)
