# TP1 — Préparer les 3 nœuds, premiers conteneurs avec ctr

**Jour 1, 10:50 · 70 min.** Objectif : rendre les 3 VM capables d'accueillir Kubernetes 1.37, et vérifier de vos yeux qu'un conteneur n'est qu'un processus. Vous tapez les étapes 1 à 6 sur `k8s-cp` ; un script applique les mêmes commandes aux deux workers. Support : sections 1.8 et 4.2 à 4.4.

Connectez-vous en SSH à `k8s-cp`, puis récupérez l'archive des TP dans `~/tp` (voir [Avant de commencer](../avant-de-commencer.md)).

## Étape 1 — Nom d'hôte et résolution des nœuds

**Pourquoi.** Kubernetes nomme chaque nœud d'après le nom d'hôte de la machine au moment où elle entre dans le cluster, et ce nom ne change plus ensuite : il faut donc le fixer avant tout. Les trois nœuds doivent aussi pouvoir se joindre par leur nom : on ajoute leurs adresses dans `/etc/hosts`, le carnet d'adresses local de Linux.

```bash
# [cp]
sudo hostnamectl set-hostname k8s-cp
printf 'preserve_hostname: true\nmanage_etc_hosts: false\n' | sudo tee /etc/cloud/cloud.cfg.d/99-formation.cfg   # VM cloud : garder ce nom et /etc/hosts au redémarrage
echo "10.10.0.10 k8s-cp" | sudo tee -a /etc/hosts
echo "10.10.0.20 k8s-w1" | sudo tee -a /etc/hosts
echo "10.10.0.30 k8s-w2" | sudo tee -a /etc/hosts
ping -c 1 k8s-w1                           # 1 packets transmitted, 1 received
```

**Ligne par ligne.**

- `hostnamectl set-hostname k8s-cp` : change le nom de la machine, immédiatement et de façon permanente.
- `printf … | sudo tee /etc/cloud/cloud.cfg.d/99-formation.cfg` : sur une VM cloud, cloud-init peut remettre le nom d'origine et réécrire `/etc/hosts` à chaque démarrage ; ce fichier le lui interdit. `tee` sert à écrire dans un fichier réservé à root, ce que la redirection `>` ne sait pas faire avec `sudo`.
- `echo "10.10.0.10 k8s-cp" | sudo tee -a /etc/hosts` : ajoute (`-a`, comme append) une correspondance adresse et nom ; une ligne par nœud.
- `ping -c 1 k8s-w1` : envoie un seul paquet (`-c 1`) pour vérifier que le nom se traduit en adresse et que la machine répond.

## Étape 2 — Désactiver le swap

**Pourquoi.** Le swap déplace sur disque une partie de la mémoire quand elle manque. Kubernetes compte la mémoire pour placer les pods et faire respecter leurs limites : avec du swap, ces calculs deviennent faux. Par défaut, le kubelet refuse donc de démarrer si le swap est actif.

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab   # reste désactivé après redémarrage
swapon --show                              # aucune ligne
```

**Ligne par ligne.**

- `swapoff -a` : désactive tout le swap immédiatement, jusqu'au prochain redémarrage.
- `sed -i '/ swap / s/^/#/' /etc/fstab` : met en commentaire (un `#` en début de ligne) la ligne du swap dans `/etc/fstab`, le fichier des montages lus au démarrage ; `-i` modifie le fichier sur place. Le swap ne reviendra pas après un redémarrage.
- `swapon --show` : liste le swap actif ; une sortie vide confirme qu'il n'y en a plus.

## Étape 3 — Modules noyau et paramètres réseau

**Pourquoi.** Les conteneurs et le réseau des pods s'appuient sur deux modules du noyau Linux : `overlay`, le système de fichiers en couches des images, et `br_netfilter`, qui fait passer le trafic des ponts réseau virtuels par le pare-feu du noyau, là où kube-proxy écrit ses règles. Le nœud doit aussi accepter de faire transiter des paquets d'une interface à une autre (`ip_forward`), comme un routeur.

```bash
printf "overlay\nbr_netfilter\n" | sudo tee /etc/modules-load.d/k8s.conf
sudo modprobe overlay && sudo modprobe br_netfilter
printf "net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1\n" | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system
sysctl net.ipv4.ip_forward                 # net.ipv4.ip_forward = 1
```

**Ligne par ligne.**

- `printf … | sudo tee /etc/modules-load.d/k8s.conf` : liste les deux modules à charger automatiquement à chaque démarrage.
- `modprobe overlay && modprobe br_netfilter` : les charge tout de suite ; `&&` n'exécute la seconde commande que si la première a réussi.
- `printf … | sudo tee /etc/sysctl.d/k8s.conf` : fixe trois paramètres du noyau. Les deux `bridge-nf-call` soumettent le trafic des ponts au pare-feu (IPv4 et IPv6) ; `ip_forward=1` autorise le routage.
- `sysctl --system` : relit tous les fichiers de paramètres et les applique immédiatement.
- `sysctl net.ipv4.ip_forward` : affiche la valeur active, qui doit valoir 1.

## Étape 4 — Installer containerd 2.x

**Pourquoi.** Kubernetes ne lance pas les conteneurs lui-même : il délègue à un runtime compatible CRI, ici containerd. Kubernetes 1.37 exige containerd 2, or le paquet `containerd` d'Ubuntu 24.04 est encore en 1.7 : on ajoute le dépôt de paquets de Docker, qui fournit `containerd.io` en version 2. Il faut enfin régler containerd pour qu'il confie les cgroups à systemd, comme le fait le kubelet : deux gestionnaires de cgroups différents sur un même nœud le rendent instable.

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update && sudo apt-get install -y containerd.io
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
grep SystemdCgroup /etc/containerd/config.toml   # SystemdCgroup = true
sudo systemctl restart containerd && sudo systemctl enable containerd
containerd --version                             # containerd.io 2.x
```

**Ligne par ligne.**

- `apt-get install -y ca-certificates curl gpg` : les outils pour télécharger en HTTPS et vérifier la signature des dépôts ; `-y` répond oui aux questions.
- `install -m 0755 -d /etc/apt/keyrings` : crée le dossier où l'on range les clés des dépôts.
- `curl … -o /etc/apt/keyrings/docker.asc` : télécharge la clé publique de Docker ; apt s'en sert pour vérifier que les paquets viennent bien de Docker.
- `echo "deb [… signed-by=…] https://download.docker.com/… stable" | sudo tee …/docker.list` : déclare le dépôt Docker pour votre architecture (`dpkg --print-architecture`) et votre version d'Ubuntu (`VERSION_CODENAME`, ici noble).
- `apt-get update && apt-get install -y containerd.io` : relit la liste des paquets disponibles, dépôt Docker compris, puis installe containerd 2.
- `containerd config default | sudo tee /etc/containerd/config.toml > /dev/null` : écrit la configuration par défaut complète dans le fichier que containerd lit au démarrage ; `> /dev/null` évite de l'afficher à l'écran.
- `sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' …` : remplace la valeur dans ce fichier.
- `grep SystemdCgroup …` : vérifie le remplacement.
- `systemctl restart containerd && systemctl enable containerd` : redémarre containerd pour qu'il lise sa configuration, et l'active au démarrage de la machine.
- `containerd --version` : contrôle la version installée.

## Étape 5 — Installer kubeadm, kubelet et kubectl 1.37

**Pourquoi.** Trois programmes forment la base de chaque nœud : `kubeadm` installe et assemble le cluster, `kubelet` est l'agent qui fait tourner les pods sur le nœud, `kubectl` est le client avec lequel vous parlez au cluster. Ils viennent du dépôt officiel `pkgs.k8s.io`, qui propose un dépôt par version mineure : en visant `v1.37`, on ne peut pas passer par erreur à une autre version. `crictl`, l'outil de diagnostic des conteneurs côté nœud, s'installe à part avec le paquet `cri-tools`.

```bash
KUBE=v1.37
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBE/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBE/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl cri-tools   # cri-tools fournit crictl
sudo apt-mark hold kubelet kubeadm kubectl       # aucune mise à jour automatique
sudo systemctl enable --now kubelet
sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock
# WARN "/etc/crictl.yaml does not exist" : normal la première fois, la commande crée ce fichier
cat /etc/crictl.yaml                             # runtime-endpoint: unix:///run/containerd/containerd.sock
sudo crictl ps                                   # en-têtes seuls, plus aucun WARN
kubeadm version -o short                         # v1.37.x
```

**Ligne par ligne.**

- `KUBE=v1.37` : une variable du shell, réutilisée dans les deux commandes suivantes sous la forme `$KUBE`.
- `curl … Release.key | sudo gpg --dearmor -o …` : télécharge la clé de signature du dépôt Kubernetes et la convertit au format attendu par apt.
- `echo "deb [signed-by=…] https://pkgs.k8s.io/core:/stable:/$KUBE/deb/ /" | sudo tee …` : déclare le dépôt de la version 1.37.
- `apt-get install -y kubelet kubeadm kubectl cri-tools` : installe les trois programmes et crictl.
- `apt-mark hold kubelet kubeadm kubectl` : bloque leur version. Une mise à jour automatique pourrait sinon changer le kubelet sous un cluster en service ; on met un cluster à jour volontairement, avec `kubeadm upgrade`.
- `systemctl enable --now kubelet` : démarre le kubelet et l'active au démarrage. Il redémarre en boucle tant que le cluster n'existe pas, voir ci-dessous.
- `crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock` : indique à crictl le socket, c'est-à-dire le point de contact local, de containerd.
- `cat /etc/crictl.yaml` et `crictl ps` : vérifient ce réglage ; crictl liste les conteneurs, aucun pour l'instant.
- `kubeadm version -o short` : contrôle la version.

`systemctl status kubelet` affiche « activating (auto-restart) » : c'est normal, le kubelet attend le `kubeadm init` du TP2.

## Étape 6 — Un conteneur n'est qu'un processus

**Pourquoi.** Avant de confier des conteneurs à Kubernetes, voyez ce qu'est vraiment un conteneur. containerd est installé, pas Docker : on le pilote ici avec `ctr`, son outil de bas niveau. Vous allez lancer nginx, puis le retrouver comme un simple processus de la VM, avec ses namespaces (ce qu'il voit) et son cgroup (ce qu'il peut consommer).

> **Prédiction.** Le conteneur nginx tournera-t-il dans une petite machine virtuelle ? Que verrez-vous si vous cherchez son processus avec `ps` sur la VM ?

```bash
sudo ctr images pull mirror.gcr.io/library/nginx:1.27
sudo ctr run -d --net-host mirror.gcr.io/library/nginx:1.27 web
curl -s http://localhost | head -4        # nginx répond sur le port 80 de la VM
sudo ctr tasks ls                         # notez le PID du conteneur
ps -o pid,user,cmd -p <PID>               # un processus comme les autres
sudo lsns -p <PID>                        # ses namespaces
cat /proc/<PID>/cgroup                    # son cgroup
sudo ctr tasks exec -t --exec-id shell web sh
```

**Ligne par ligne.**

- `ctr images pull mirror.gcr.io/library/nginx:1.27` : télécharge l'image depuis le registre (ici le miroir de Google pour Docker Hub) dans le stock local de containerd.
- `ctr run -d --net-host … web` : crée et démarre un conteneur nommé `web`, en arrière-plan (`-d`). `--net-host` lui fait partager le réseau de la VM : nginx écoute directement sur le port 80 de la VM.
- `curl -s http://localhost | head -4` : interroge nginx ; `-s` masque la progression, les 4 premières lignes suffisent à prouver qu'il répond.
- `ctr tasks ls` : une tâche est le processus en cours d'un conteneur ; la commande affiche son PID, son numéro de processus côté VM.
- `ps -o pid,user,cmd -p <PID>` : le même processus vu par Linux, comme n'importe quel programme.
- `lsns -p <PID>` : ses namespaces (réseau, montages, processus, nom d'hôte…), c'est-à-dire ce qu'il a le droit de voir.
- `cat /proc/<PID>/cgroup` : le cgroup dans lequel le noyau le range pour limiter ses ressources.
- `ctr tasks exec -t --exec-id shell web sh` : ouvre un shell à l'intérieur du conteneur ; `-t` donne un terminal interactif, `--exec-id` est un nom libre pour ce processus supplémentaire.

Dans le conteneur, tapez `cat /etc/os-release`, puis `uname -r`, puis `exit`. Nettoyez ensuite :

```bash
sudo ctr tasks kill -s SIGKILL web && sleep 1
sudo ctr tasks delete web
sudo ctr containers delete web
```

**Ligne par ligne.**

- `ctr tasks kill -s SIGKILL web` : envoie au processus le signal d'arrêt immédiat ; `sleep 1` lui laisse le temps de s'arrêter.
- `ctr tasks delete web` puis `ctr containers delete web` : supprime la tâche terminée, puis le conteneur lui-même. L'image reste en stock.

## Étape 7 — Préparer les deux workers

**Pourquoi.** Les deux workers ont besoin exactement de la même préparation que `k8s-cp`. Vous venez de la faire à la main pour comprendre chaque étape ; la refaire deux fois n'apprendrait rien de plus. Un script la rejoue à l'identique : c'est ce qu'on fait aussi en production, avec des scripts ou des outils comme Ansible.

Le script `prep-node.sh` enchaîne les étapes 1 à 5. Ses arguments : le nom du nœud, puis les IP de `k8s-cp`, `k8s-w1` et `k8s-w2`, dans cet ordre.

```bash
# [cp] copier le script sur les workers
scp ~/tp/tp01/prep-node.sh k8s-w1:
scp ~/tp/tp01/prep-node.sh k8s-w2:
# [w1]
sudo bash prep-node.sh k8s-w1 10.10.0.10 10.10.0.20 10.10.0.30
# [w2]
sudo bash prep-node.sh k8s-w2 10.10.0.10 10.10.0.20 10.10.0.30
```

**Ligne par ligne.**

- `scp ~/tp/tp01/prep-node.sh k8s-w1:` : copie le script dans le dossier personnel de `k8s-w1`, par SSH ; les deux-points désignent la machine distante.
- `sudo bash prep-node.sh k8s-w1 10.10.0.10 10.10.0.20 10.10.0.30` : exécute le script avec les droits administrateur. Le premier argument est le nom à donner au nœud, les trois suivants les IP de `k8s-cp`, `k8s-w1` et `k8s-w2`. Lisez sa sortie : chaque étape s'annonce par une ligne `==>`.

Si `scp` entre VM n'est pas possible, récupérez l'archive sur chaque worker comme sur `k8s-cp`. Le script se termine par un contrôle de ses résultats.

## À vous, sans pas-à-pas

Pendant que le script tourne sur les workers : lancez avec `ctr` un conteneur `mirror.gcr.io/library/busybox:1.36` nommé `dodo` qui exécute `sleep 600`. Retrouvez son PID côté VM et arrêtez-le avec `kill`, sans passer par `ctr`. Que montre ensuite `sudo ctr tasks ls` ? Nettoyez.

Indice : `ctr run -d <image> <nom> <commande>`, après un `ctr images pull`.

## Point de contrôle

- [ ] Sur les 3 nœuds, `containerd --version` affiche 2.x.
- [ ] Sur les 3 nœuds, `kubeadm version -o short` affiche v1.37.x.
- [ ] `swapon --show` ne renvoie rien et `sysctl net.ipv4.ip_forward` vaut 1.
- [ ] Vous avez vu le conteneur nginx comme un processus de la VM.

## Pour comprendre

1. Pourquoi faut-il désactiver le swap et activer `ip_forward` ?
2. À l'étape 6, `cat /etc/os-release` et `uname -r` donnent-ils le système de l'image ou celui de la VM ? Qu'en concluez-vous ?


---

[Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP2 →](../tp02/README.md)
