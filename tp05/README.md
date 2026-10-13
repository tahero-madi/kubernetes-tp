# TP5 — Application fil rouge podinfo + Redis

**Jour 2, 10:30 · 70 min.** Objectif : déployer l'application qui vous suivra jusqu'au jour 3 : un cache Redis, l'application web podinfo en 3 réplicas, leur configuration et leurs Services. Support : sections 7.3 à 7.8 et 8.2 à 8.6.

## Étape 1 — Redis et son Service

**Pourquoi.** On commence par le composant dont les autres dépendent : Redis, le cache de podinfo. Un Deployment le fait tourner ; un Service lui donne un nom et une adresse stables, alors que le pod, lui, peut être remplacé à tout moment avec une nouvelle IP.

> **Prédiction.** Le pod Redis peut être remplacé à tout moment, et son adresse IP change alors. Comment podinfo pourra-t-il le joindre de façon stable ? Notez votre réponse avant de continuer.

```bash
cd ~/tp/fil-rouge
cat 10-redis.yaml                      # un Deployment et un Service : repérez le label app: redis
kubectl apply -f 10-redis.yaml
kubectl get pods -l app=redis -o wide  # l'IP du pod
kubectl get svc redis                  # une ClusterIP stable, joignable sous le nom redis
kubectl get endpointslices -l kubernetes.io/service-name=redis   # l'IP du pod derrière le Service
kubectl run test-redis --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- sh -c 'echo PING | nc -w 3 redis 6379'   # +PONG
```

**Ligne par ligne.**

- `cat 10-redis.yaml` : le fichier contient deux objets, séparés par `---`.
- `kubectl apply -f 10-redis.yaml` : crée le Deployment et le Service.
- `kubectl get pods -l app=redis -o wide` : `-l` filtre par label ; notez l'IP du pod.
- `kubectl get svc redis` : la ClusterIP, une adresse virtuelle stable, joignable seulement depuis le cluster.
- `kubectl get endpointslices -l kubernetes.io/service-name=redis` : la liste des adresses de pods derrière le Service, tenue à jour par Kubernetes.
- `kubectl run test-redis … -- sh -c 'echo PING | nc -w 3 redis 6379'` : un pod jetable envoie la commande Redis `PING` au Service `redis` avec `nc` (netcat) ; `-w 3` abandonne après 3 secondes. `+PONG` prouve que le nom, le Service et le pod fonctionnent ensemble.

Le lien entre le Service et son pod est un sélecteur de labels.

> **Prédiction.** Que se passera-t-il si le sélecteur du Service vise `app: redis2` ?

```bash
kubectl patch service redis -p '{"spec":{"selector":{"app":"redis2"}}}'
kubectl get endpointslices -l kubernetes.io/service-name=redis   # plus aucune adresse
kubectl apply -f 10-redis.yaml                                   # le fichier rétablit le bon sélecteur
kubectl get endpointslices -l kubernetes.io/service-name=redis   # l'adresse est revenue
```

**Ligne par ligne.**

- `kubectl patch service redis -p '…'` : modifie un seul champ de l'objet dans le cluster, ici le sélecteur.
- `kubectl get endpointslices …` : aucun pod ne porte `app: redis2`, la liste est vide.
- `kubectl apply -f 10-redis.yaml` : le fichier fait foi ; en le réappliquant, le sélecteur d'origine revient.

## Étape 2 — La configuration : ConfigMap et Secret

**Pourquoi.** On sépare la configuration de l'image : la même image servira en recette et en production, seules changeront les ConfigMaps (paramètres) et les Secrets (mots de passe, jetons). podinfo recevra leurs clés comme variables d'environnement.

```bash
cat 20-config.yaml                     # deux variables : PODINFO_UI_MESSAGE et PODINFO_UI_COLOR
kubectl apply -f 20-config.yaml
kubectl create secret generic podinfo-secret -n fil-rouge --from-literal=API_TOKEN=s3cr3t-insee --dry-run=client -o yaml > 21-secret.yaml
cat 21-secret.yaml                     # la valeur est en base64
echo czNjcjN0LWluc2Vl | base64 -d      # ... et se décode sans aucune clé
kubectl apply -f 21-secret.yaml
kubectl get configmap,secret
```

**Ligne par ligne.**

- `cat 20-config.yaml` : deux clés, le message et la couleur de la page de podinfo.
- `kubectl apply -f 20-config.yaml` : crée la ConfigMap `podinfo-config`.
- `kubectl create secret generic … --from-literal=API_TOKEN=… --dry-run=client -o yaml > 21-secret.yaml` : génère le manifeste d'un Secret sans le créer ; `--from-literal` donne la clé et sa valeur en clair, kubectl l'encode.
- `cat 21-secret.yaml` puis `base64 -d` : la valeur est seulement encodée en base64, pas chiffrée ; n'importe qui la décode.
- `kubectl apply -f 21-secret.yaml` : crée le Secret.
- `kubectl get configmap,secret` : les deux objets, plus le certificat racine que Kubernetes place dans chaque namespace (`kube-root-ca.crt`).

## Étape 3 — podinfo et son Service

**Pourquoi.** podinfo est l'application web : 3 réplicas pour la disponibilité, et un Service NodePort pour y accéder depuis l'extérieur. Son fichier relie tout ce qui précède : il cherche Redis sous le nom `redis` et lit la ConfigMap et le Secret.

> **Prédiction.** Le Service `podinfo` est de type NodePort, sur le port 30080. Pourrez-vous joindre l'application seulement par les nœuds où tourne un pod podinfo, ou par tous ?

```bash
cat 30-podinfo.yaml                    # repérez --cache-server, envFrom et nodePort
kubectl apply -f 30-podinfo.yaml
kubectl rollout status deployment podinfo
kubectl get pods -o wide               # 3 pods podinfo répartis sur les workers
curl -s http://k8s-cp:30080 | head -5  # réponse aussi par le control plane, où aucun pod podinfo ne tourne
```

**Ligne par ligne.**

- `cat 30-podinfo.yaml` : `--cache-server=tcp://redis:6379` désigne Redis par le nom de son Service ; `envFrom` charge toutes les clés de la ConfigMap et du Secret comme variables ; `nodePort: 30080` fixe le port ouvert sur les nœuds.
- `kubectl apply -f 30-podinfo.yaml` : crée le Deployment et le Service.
- `kubectl rollout status deployment podinfo` : attend que les 3 pods soient prêts.
- `kubectl get pods -o wide` : la répartition sur les nœuds.
- `curl -s http://k8s-cp:30080 | head -5` : le port 30080 est ouvert sur tous les nœuds, même ceux sans pod podinfo ; kube-proxy fait suivre la requête.

## Étape 4 — Tester l'application

**Pourquoi.** On vérifie chaque maillon : l'accès depuis l'extérieur, le cache Redis, les variables reçues par le conteneur et l'accès interne par le DNS du cluster.

```bash
curl http://k8s-w1:30080                                    # JSON avec le message de la ConfigMap
curl -X POST -d 'bonjour' http://k8s-w1:30080/cache/test    # écrit dans Redis
curl http://k8s-w1:30080/cache/test                         # "bonjour", relu dans Redis
kubectl exec deploy/podinfo -- env | grep -E 'PODINFO|API_TOKEN'
kubectl run client --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- wget -qO- http://podinfo.fil-rouge.svc.cluster.local:9898
```

**Ligne par ligne.**

- `curl http://k8s-w1:30080` : la réponse JSON de podinfo, par le NodePort.
- `curl -X POST -d 'bonjour' …/cache/test` : `-X POST` envoie une requête d'écriture, `-d` son contenu ; podinfo l'enregistre dans Redis sous la clé `test`.
- `curl …/cache/test` : relit la clé depuis Redis.
- `kubectl exec deploy/podinfo -- env | grep -E 'PODINFO|API_TOKEN'` : exécute `env` dans un pod du Deployment et ne garde que les variables venues de la ConfigMap et du Secret ; dans le conteneur, le Secret est en clair.
- `kubectl run client … -- wget -qO- http://podinfo.fil-rouge.svc.cluster.local:9898` : depuis un pod, le nom DNS complet d'un Service s'écrit `<service>.<namespace>.svc.cluster.local`.

Les champs `message` et `color` de la réponse JSON viennent de la ConfigMap : ce sont eux qu'afficherait la page web de podinfo.

## Étape 5 — Réappliquer le dossier entier

**Pourquoi.** En production, on ne crée pas les objets un par un : on applique un dossier de fichiers, gardé sous contrôle de version, et l'on doit pouvoir le rejouer à tout moment sans risque.

```bash
kubectl apply -f .                     # tout est « unchanged » : le dossier décrit exactement l'état du cluster
```

Ce dossier suffit à reconstruire l'application sur n'importe quel cluster : c'est tout l'intérêt du déclaratif.

## À vous, sans pas-à-pas

Créez un second Service `podinfo-interne`, de type ClusterIP, qui envoie le port 80 vers le port 9898 des pods podinfo. Joignez-le par son nom depuis un pod busybox, puis supprimez-le.

Indice : `kubectl expose` crée un Service à partir d'un Deployment ; cherchez `--port` et `--target-port` dans `kubectl expose --help`.

## Point de contrôle

- [ ] 3 pods podinfo et 1 pod redis sont `Running`.
- [ ] podinfo répond à `curl` sur le port 30080, y compris par `k8s-cp`.
- [ ] L'écriture puis la lecture dans le cache fonctionnent.

## Pour comprendre

1. Comment podinfo trouve-t-il Redis, alors que l'adresse IP du pod Redis change à chaque redémarrage ?
2. À l'étape Bonus, pourquoi la modification de la ConfigMap reste-t-elle invisible jusqu'au redémarrage ?

## Bonus

Dans `20-config.yaml`, changez le message, puis :

```bash
kubectl apply -f 20-config.yaml
curl -s http://k8s-w1:30080 | grep message      # toujours l'ancien message
kubectl rollout restart deployment podinfo
kubectl rollout status deployment podinfo
curl -s http://k8s-w1:30080 | grep message      # le nouveau message
```

**Ligne par ligne.**

- `kubectl apply -f 20-config.yaml` : met à jour la ConfigMap dans le cluster.
- premier `curl … | grep message` : toujours l'ancien message, car les variables d'environnement ne sont lues qu'au démarrage du conteneur.
- `kubectl rollout restart deployment podinfo` : recrée les pods un par un, sans coupure ; les nouveaux lisent la nouvelle valeur.
- `kubectl rollout status` puis second `curl` : le nouveau message s'affiche.


---

[← TP4](../tp04/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP6 →](../tp06/README.md)
