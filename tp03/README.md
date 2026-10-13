# TP3 — Gérer les nœuds, premier déploiement

**Jour 1, 14:35 · 60 min.** Objectif : décrire et étiqueter les nœuds, déployer et exposer une première application, puis faire une maintenance de nœud sans interruption. Support : sections 5.1 à 5.6.

## Étape 1 — Confort de travail

**Pourquoi.** Vous allez taper `kubectl` des centaines de fois. La touche Tab complète les commandes, les options et même les noms d'objets ; l'alias `k` raccourcit la frappe.

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
k get nodes                        # l'alias fonctionne ; la touche Tab complète les noms
```

**Ligne par ligne.**

- `echo 'source <(kubectl completion bash)' >> ~/.bashrc` : à chaque ouverture de session, charge le script de complétion que kubectl sait générer ; `>>` ajoute la ligne à la fin du fichier sans l'écraser.
- `echo 'alias k=kubectl' >> ~/.bashrc` : `k` devient un synonyme de `kubectl`.
- `echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc` : branche aussi la complétion sur l'alias `k`.
- `source ~/.bashrc` : relit le fichier dans la session en cours, sans vous reconnecter.

## Étape 2 — Explorer et étiqueter les nœuds

**Pourquoi.** Avant de déployer, on regarde de quoi l'on dispose. `describe node` donne l'état et la capacité d'un nœud. Les labels sont des étiquettes clé=valeur posées sur les objets : ils servent à les trier et à les sélectionner, par exemple pour envoyer certains pods sur certains nœuds. La taint, elle, repousse les pods d'un nœud.

```bash
kubectl describe node k8s-w1                          # repérez Conditions, Allocatable, Allocated resources
kubectl label node k8s-w1 node-role.kubernetes.io/worker=
kubectl label node k8s-w2 node-role.kubernetes.io/worker=
kubectl label node k8s-w2 disque=ssd
kubectl get nodes -L disque                           # colonnes ROLES et DISQUE
kubectl describe node -l node-role.kubernetes.io/control-plane | grep -i taint          # la taint du control plane
```

**Ligne par ligne.**

- `kubectl describe node k8s-w1` : Conditions (mémoire, disque, `Ready`), Allocatable (ce qui est disponible pour les pods) et Allocated resources (ce qui est déjà réservé).
- `kubectl label node k8s-w1 node-role.kubernetes.io/worker=` : ajoute un label sans valeur ; `kubectl get nodes` l'affiche dans la colonne ROLES.
- `kubectl label node k8s-w2 disque=ssd` : un label libre, qui servira au Bonus pour choisir le nœud.
- `kubectl get nodes -L disque` : `-L` ajoute une colonne avec la valeur du label.
- `kubectl describe node -l node-role.kubernetes.io/control-plane | grep -i taint` : `-l` sélectionne le nœud par label plutôt que par nom ; `grep -i taint` ne garde que la ligne Taints, sans tenir compte des majuscules.

## Étape 3 — Premier déploiement, première exposition

**Pourquoi.** Un Deployment décrit une application : quelle image, combien de copies (réplicas). Kubernetes crée les pods et les répartit sur les nœuds. Un Service donne ensuite un point d'entrée stable vers ces pods ; le type NodePort ouvre un port sur chaque nœud pour y accéder depuis l'extérieur du cluster.

```bash
kubectl create deployment hello --image=mirror.gcr.io/library/nginx:1.27 --replicas=4
kubectl get pods -o wide                              # répartis sur k8s-w1 et k8s-w2
kubectl expose deployment hello --port=80 --type=NodePort
kubectl get svc hello                                 # notez le port 3xxxx
curl -s http://k8s-w1:<NodePort> | grep title         # <title>Welcome to nginx!</title>
```

**Ligne par ligne.**

- `kubectl create deployment hello --image=…nginx:1.27 --replicas=4` : crée le Deployment `hello`, qui demande 4 pods nginx.
- `kubectl get pods -o wide` : la colonne NODE montre la répartition sur les workers.
- `kubectl expose deployment hello --port=80 --type=NodePort` : crée un Service qui vise les pods du Deployment sur leur port 80, et ouvre un port entre 30000 et 32767 sur chaque nœud.
- `kubectl get svc hello` : la colonne PORT(S) affiche `80:3xxxx/TCP` ; le second nombre est le NodePort.
- `curl -s http://k8s-w1:<NodePort> | grep title` : appelle le Service par un nœud ; `grep title` ne garde que le titre de la page.

Un NodePort répond sur **tous** les nœuds, même là où aucun pod `hello` ne tourne : essayez aussi `curl -s http://k8s-cp:<NodePort> | grep title`.

## Étape 4 — Auto-réparation

**Pourquoi.** C'est le cœur de Kubernetes : vous déclarez un état voulu (4 pods), et des contrôleurs le maintiennent en permanence. Ici, le contrôleur du ReplicaSet compare sans cesse le nombre de pods réels au nombre demandé.

> **Prédiction.** Vous allez supprimer un pod `hello` à la main. Combien de pods `hello` y aura-t-il dans 10 secondes ?

```bash
kubectl delete pod <un-pod-hello>
kubectl get pods -w                                   # un nouveau pod apparaît ; Ctrl+C pour sortir
```

**Ligne par ligne.**

- `kubectl delete pod <un-pod-hello>` : supprime un pod ; prenez un nom dans `kubectl get pods`, la touche Tab le complète.
- `kubectl get pods -w` : `-w` (watch) garde la commande ouverte et affiche chaque changement en direct.

## Étape 5 — Maintenance d'un nœud

**Pourquoi.** Pour intervenir sur un nœud (mise à jour, redémarrage), on le vide d'abord proprement : ses pods sont recréés ailleurs avant l'arrêt, et le service continue.

```bash
kubectl drain k8s-w2 --ignore-daemonsets --delete-emptydir-data
kubectl get nodes                                     # k8s-w2 : SchedulingDisabled
kubectl get pods -o wide                              # tous les pods hello sont sur k8s-w1
kubectl uncordon k8s-w2
```

**Ligne par ligne.**

- `kubectl drain k8s-w2 --ignore-daemonsets --delete-emptydir-data` : marque le nœud non planifiable, puis évince ses pods. `--ignore-daemonsets` laisse en place les pods présents par construction sur chaque nœud (Calico, kube-proxy) ; `--delete-emptydir-data` accepte de perdre leurs volumes temporaires.
- `kubectl get nodes` : `SchedulingDisabled`, plus aucun nouveau pod n'y sera placé.
- `kubectl get pods -o wide` : tous les pods `hello` sont sur `k8s-w1`.
- `kubectl uncordon k8s-w2` : remet le nœud en service. Les pods déplacés ne reviennent pas d'eux-mêmes ; seuls les nouveaux pourront y aller.

## Étape 6 — Taint et tolérance

**Pourquoi.** Une taint est une marque posée sur un nœud pour en écarter les pods ; seuls ceux qui portent la toleration correspondante l'acceptent. C'est ainsi que le control plane est réservé, et c'est l'outil pour dédier des nœuds à un usage (GPU, équipe, maintenance).

> **Prédiction.** Après la taint, où iront les 2 pods ajoutés par le `scale` ? Les pods déjà présents sur `k8s-w2` partiront-ils ?

```bash
kubectl taint nodes k8s-w2 maintenance=oui:NoSchedule
kubectl scale deployment hello --replicas=6
kubectl get pods -o wide                              # les nouveaux pods évitent k8s-w2
kubectl taint nodes k8s-w2 maintenance=oui:NoSchedule-   # le tiret final retire la taint
```

**Ligne par ligne.**

- `kubectl taint nodes k8s-w2 maintenance=oui:NoSchedule` : pose une taint de clé `maintenance`, de valeur `oui`, avec l'effet `NoSchedule` : plus aucun nouveau pod sans toleration, mais ceux déjà là restent.
- `kubectl scale deployment hello --replicas=6` : demande 2 pods de plus.
- `kubectl get pods -o wide` : les nouveaux pods évitent `k8s-w2`.
- `kubectl taint nodes k8s-w2 maintenance=oui:NoSchedule-` : le tiret final retire la taint.

## À vous, sans pas-à-pas

Passez le Deployment `hello` à 0 pod et interrogez son NodePort avec `curl` : que répond-il, et pourquoi ? Remettez 4 pods et vérifiez que le NodePort répond de nouveau.

Indice : comparez la liste des EndpointSlices dans les deux situations.

## Point de contrôle

- [ ] nginx répond à curl par le NodePort.
- [ ] Un pod supprimé à la main a été remplacé.
- [ ] `kubectl get nodes` ne montre plus `SchedulingDisabled` et `k8s-w2` n'a plus de taint `maintenance`.

## Pour comprendre

1. Pourquoi aucun pod `hello` ne tourne-t-il sur `k8s-cp` ?
2. Que devient un pod supprimé à la main, et quel composant en décide ?

## Bonus

Ajoutez un `nodeSelector` `disque: ssd` au Deployment (`kubectl edit deployment hello`, sous `spec.template.spec`) et observez où vont les pods.

## Fin du TP

```bash
kubectl delete deployment,svc hello
```

`kubectl delete deployment,svc hello` supprime les deux objets d'un coup ; les pods disparaissent avec leur Deployment.


---

[← TP2](../tp02/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP4 →](../tp04/README.md)
