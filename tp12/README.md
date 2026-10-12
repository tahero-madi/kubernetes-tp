# TP12 — Rendre Redis persistant

**Jour 3, 14:15 · 45 min.** Objectif : que les données du cache survivent à la perte du pod Redis, grâce à un volume local sur k8s-w1 réservé par un PersistentVolumeClaim. Support : sections 16.1 à 16.5.

## Étape 1 — Constater la perte des données

**Pourquoi.** Le système de fichiers d'un conteneur disparaît avec lui. Redis garde ses données en mémoire et dans son dossier `/data`, à l'intérieur du conteneur : vous allez constater qu'un simple remplacement du pod efface le cache.

```bash
curl -X POST -d 'avant' http://k8s-w1:30080/cache/persistance   # écrit dans Redis
curl http://k8s-w1:30080/cache/persistance                       # avant
kubectl delete pod -l app=redis -n fil-rouge                     # le Deployment recrée un pod Redis neuf
kubectl wait --for=condition=Ready pod -l app=redis -n fil-rouge --timeout=60s
curl -i http://k8s-w1:30080/cache/persistance                    # 404 Not Found : la clé a disparu avec le conteneur
# une erreur 500 ? podinfo rétablit sa connexion à Redis : relancez la commande
```

**Ligne par ligne.**

- `curl -X POST -d 'avant' …/cache/persistance` : écrit la clé `persistance`.
- `kubectl delete pod -l app=redis -n fil-rouge` : supprime le pod Redis, désigné par son label ; le Deployment en recrée aussitôt un neuf.
- `kubectl wait --for=condition=Ready pod -l app=redis …` : attend que le nouveau pod soit prêt avant de tester.
- `curl -i …` : `-i` affiche aussi le code de réponse HTTP ; 404 signifie que la clé n'existe plus.

## Étape 2 — Préparer le répertoire sur k8s-w1

**Pourquoi.** Un volume local est un dossier d'un nœud précis, que Kubernetes ne crée pas lui-même : on le prépare à la main sur `k8s-w1`.

```bash
# [w1]
sudo mkdir -p /mnt/data/redis
sudo chmod 777 /mnt/data/redis
```

**Ligne par ligne.** `mkdir -p /mnt/data/redis` crée le dossier et ses parents ; `chmod 777` donne tous les droits, car Redis écrit sous son propre utilisateur et non en root. C'est un réglage de labo : en production, on ajuste plutôt le propriétaire.

## Étape 3 — Créer la StorageClass, le PV et le PVC

**Pourquoi.** Trois objets séparent le besoin de sa réalisation : la StorageClass décrit une catégorie de stockage, le PersistentVolume (PV) est un volume réel, le PersistentVolumeClaim (PVC) est la demande d'une application. Le pod ne référence que le PVC ; il ignore où se trouvent réellement les données.

Repérez dans le fichier : la StorageClass sans provisionnement automatique, le chemin sur le disque de k8s-w1, et la contrainte qui attache le volume à ce nœud.

```bash
cat ~/tp/tp12/95-stockage.yaml
kubectl apply -f ~/tp/tp12/95-stockage.yaml
kubectl get storageclass,pv                  # redis-pv : Available
kubectl get pvc -n fil-rouge                 # redis-data : Pending, c'est normal (question 1)
```

**Ligne par ligne.**

- `kubectl apply -f ~/tp/tp12/95-stockage.yaml` : crée les trois objets ; la StorageClass et le PV appartiennent au cluster entier, le PVC au namespace `fil-rouge`.
- `kubectl get storageclass,pv` : le PV est `Available`, libre.
- `kubectl get pvc -n fil-rouge` : `Pending`, en attente d'un pod qui l'utilise (mode `WaitForFirstConsumer`).

## Étape 4 — Brancher le volume sur Redis

**Pourquoi.** Le Deployment Redis doit maintenant monter le volume réservé par le PVC à l'endroit où Redis écrit, activer l'écriture sur disque, et ne jamais faire tourner deux Redis à la fois sur les mêmes fichiers.

Dans `~/tp/fil-rouge/10-redis.yaml`, faites les quatre ajouts marqués `# NOUVEAU`. Le Service, en bas du fichier, ne change pas.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: fil-rouge
  labels:
    app: redis
spec:
  replicas: 1
  strategy:                                # NOUVEAU : jamais deux Redis sur les mêmes fichiers
    type: Recreate
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: mirror.gcr.io/library/redis:7-alpine
          args: ["--appendonly", "yes"]      # NOUVEAU : chaque écriture est journalisée sur disque
          ports:
            - containerPort: 6379
          volumeMounts:                    # NOUVEAU : /data, le répertoire de travail de Redis
            - name: data
              mountPath: /data
      volumes:                             # NOUVEAU : le volume vient du PVC
        - name: data
          persistentVolumeClaim:
            claimName: redis-data
```

**Champ par champ, pour les ajouts.**

- `strategy: type: Recreate` : arrête l'ancien pod avant de créer le nouveau. Avec la mise à jour progressive par défaut, deux Redis écriraient un instant dans les mêmes fichiers.
- `args: ["--appendonly", "yes"]` : active le journal de Redis, qui enregistre chaque écriture sur disque au lieu de tout garder en mémoire.
- `volumeMounts` : monte le volume nommé `data` dans `/data`, le dossier où Redis range ses fichiers.
- `volumes` : déclare le volume `data` et indique qu'il est fourni par le PVC `redis-data`.

## Étape 5 — Redéployer Redis

**Pourquoi.** On recrée Redis avec sa nouvelle définition, puis on vérifie que le PVC s'est lié à un volume et que le pod est allé sur le seul nœud possible.

Un `kubectl apply` seul refuse de passer de la stratégie RollingUpdate à Recreate (`spec.strategy.rollingUpdate: Forbidden`) : supprimez d'abord le Deployment.

```bash
cd ~/tp/fil-rouge
kubectl delete deployment redis -n fil-rouge
kubectl apply -f 10-redis.yaml
kubectl rollout status deployment redis -n fil-rouge
kubectl get pvc,pv -n fil-rouge                   # redis-data : Bound à redis-pv
kubectl get pod -l app=redis -n fil-rouge -o wide # NODE : k8s-w1, imposé par le PV
```

**Ligne par ligne.**

- `kubectl delete deployment redis` puis `kubectl apply -f 10-redis.yaml` : recrée Redis avec la stratégie Recreate et son volume.
- `kubectl rollout status deployment redis -n fil-rouge` : attend que le nouveau pod soit prêt.
- `kubectl get pvc,pv -n fil-rouge` : le PVC est maintenant `Bound`, lié au PV.
- `kubectl get pod -l app=redis -n fil-rouge -o wide` : le pod tourne sur `k8s-w1`, le seul nœud où le volume existe.

## Étape 6 — Vérifier que la donnée survit

**Pourquoi.** C'est le test qui compte : la même opération qu'à l'étape 1, cette fois avec un volume persistant.

> **Prédiction.** Cette fois, la clé survivra-t-elle à la suppression du pod ? D'où Redis la relira-t-il ?

```bash
curl -X POST -d 'apres' http://k8s-w1:30080/cache/persistance
kubectl delete pod -l app=redis -n fil-rouge
kubectl wait --for=condition=Ready pod -l app=redis -n fil-rouge --timeout=60s
curl http://k8s-w1:30080/cache/persistance       # apres : relu depuis le disque de k8s-w1
```

**Ligne par ligne.** Vous écrivez `apres`, supprimez le pod, attendez son remplaçant, puis relisez la clé : Redis l'a retrouvée sur le disque de `k8s-w1`, que le nouveau pod a monté à son tour sous `/data`.

```bash
# [w1]
ls -l /mnt/data/redis                          # appendonlydir : le journal des écritures de Redis
```

**Ligne par ligne.** Le dossier `appendonlydir` contient le journal de Redis : chaque écriture y est ajoutée, et Redis le rejoue à chaque démarrage pour reconstituer ses données.

## À vous, sans pas-à-pas

Écrivez une deuxième clé, puis supprimez le Deployment Redis entier, pas seulement son pod, et recréez-le depuis `10-redis.yaml`. La clé est-elle toujours là ? Expliquez ensuite, sans le faire, ce qui se passerait si l'on supprimait le PVC `redis-data`.

Indice : regardez `persistentVolumeReclaimPolicy` dans `95-stockage.yaml`.

## Point de contrôle

- [ ] `redis-data` est `Bound` et le pod Redis tourne sur k8s-w1.
- [ ] La clé `persistance` vaut `apres` après la suppression du pod Redis.
- [ ] `/mnt/data/redis` sur k8s-w1 contient les fichiers de Redis.

## Pour comprendre

1. Pourquoi le PVC est-il resté `Pending` jusqu'au redéploiement de Redis ?
2. Pourquoi passer le Deployment Redis en stratégie `Recreate` ?

## Bonus : et si k8s-w1 tombe ?

Simulez l'arrêt de k8s-w1 en le vidant, observez le pod Redis, puis remettez le nœud en service.

```bash
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data
kubectl get pods -l app=redis -n fil-rouge       # Pending
kubectl describe pod -l app=redis -n fil-rouge   # Events : volume node affinity conflict
kubectl uncordon k8s-w1
kubectl get pods -l app=redis -n fil-rouge -o wide   # de retour sur k8s-w1, la clé est toujours là
```

**Ligne par ligne.** `kubectl drain k8s-w1` vide le nœud comme au TP3. Le pod Redis recréé ne peut aller nulle part ailleurs, car son volume n'existe que sur `k8s-w1` : il reste `Pending`. `kubectl uncordon k8s-w1` rend le nœud, et le pod y démarre.

Un volume local lie le pod à son nœud : si le nœud tombe, l'application attend son retour. En production, on choisit un stockage réseau fourni par un pilote CSI (section 16.4).


---

[← TP11](../tp11/README.md) · [Sommaire](../README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP13 →](../tp13/README.md)
