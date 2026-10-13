# TP6 — Mettre à jour, revenir en arrière, sonder

**Jour 2, 13:00 · 70 min.** Objectif : mettre à jour podinfo sans coupure, rattraper une mise à jour ratée, puis ajouter des probes et observer leur effet. Support : sections 9.1 à 9.4.

## Étape 1 — Mise à jour progressive

**Pourquoi.** Changer de version sans interrompre le service, c'est la mise à jour progressive (rolling update). Kubernetes crée un nouveau ReplicaSet pour la nouvelle version, y ajoute des pods un par un et retire les anciens au fur et à mesure. Le terminal 2 vous montre ce que voit un utilisateur pendant ce temps.

Ouvrez un **second terminal** sur `k8s-cp` pour observer l'application pendant toute l'étape (deuxième connexion ou tmux, voir [Accès par la console web](../avant-de-commencer.md#accès-par-la-console-web)) :

```bash
# terminal 2 : laisser tourner
while true; do curl -s http://k8s-w1:30080/version; echo; sleep 0.5; done
```

**Ligne par ligne.** `while true; do curl -s …/version; echo; sleep 0.5; done` est une boucle sans fin qui demande la version deux fois par seconde ; `echo` passe à la ligne après chaque réponse. Ctrl+C l'arrêtera.

```bash
# terminal 1
kubectl set image deployment/podinfo podinfo=ghcr.io/stefanprodan/podinfo:6.7.1
kubectl annotate deployment/podinfo kubernetes.io/change-cause="passage en 6.7.1" --overwrite
kubectl rollout status deployment/podinfo
kubectl get rs                           # l'ancien ReplicaSet à 0, le nouveau à 3
kubectl rollout history deployment/podinfo
```

**Ligne par ligne.**

- `kubectl set image deployment/podinfo podinfo=…:6.7.1` : change l'image du conteneur nommé `podinfo` dans le Deployment, ce qui déclenche la mise à jour.
- `kubectl annotate … kubernetes.io/change-cause="passage en 6.7.1" --overwrite` : note la raison du changement ; elle apparaîtra dans l'historique.
- `kubectl rollout status deployment/podinfo` : suit la mise à jour jusqu'à la fin.
- `kubectl get rs` : deux ReplicaSets, l'ancien réduit à 0 et gardé pour un retour arrière, le nouveau à 3.
- `kubectl rollout history deployment/podinfo` : les révisions successives et leur cause.

Dans le terminal 2, la version passe de 6.7.0 à 6.7.1 sans interruption.

## Étape 2 — Une mise à jour ratée, puis le retour arrière

**Pourquoi.** Une mise à jour finit toujours par échouer un jour : image introuvable, application qui ne démarre pas. Vous allez voir que Kubernetes protège le service pendant l'échec, puis revenir à la version précédente en une commande.

> **Prédiction.** La version 6.99.99 n'existe pas. Pendant cette mise à jour, l'application va-t-elle cesser de répondre ? Gardez un œil sur le terminal 2.

```bash
kubectl set image deployment/podinfo podinfo=ghcr.io/stefanprodan/podinfo:6.99.99
kubectl rollout status deployment/podinfo --timeout=60s   # échoue au bout de 60 s
kubectl get pods                                          # ImagePullBackOff... et pourtant l'application répond
kubectl rollout undo deployment/podinfo
kubectl rollout status deployment/podinfo
```

**Ligne par ligne.**

- `kubectl set image …:6.99.99` : demande une version qui n'existe pas.
- `kubectl rollout status … --timeout=60s` : attend au plus 60 secondes, puis signale l'échec.
- `kubectl get pods` : le nouveau pod est en `ImagePullBackOff` (l'image ne peut pas être téléchargée) ; les anciens tournent toujours.
- `kubectl rollout undo deployment/podinfo` : revient à la révision précédente.
- `kubectl rollout status deployment/podinfo` : confirme le retour.

## Étape 3 — Remettre le fichier en accord avec le cluster

**Pourquoi.** Vos commandes `set image` ont modifié le cluster, pas le fichier : le prochain `apply` les annulerait, et une reconstruction repartirait de l'ancienne version. Le fichier doit rester la référence. On en profite pour fixer la stratégie de mise à jour et ajouter les probes. Dans `~/tp/fil-rouge/30-podinfo.yaml`, modifiez le Deployment comme ci-dessous (lignes marquées `NOUVEAU` ou `MODIFIÉ`) :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: fil-rouge
  labels:
    app: podinfo
spec:
  replicas: 3
  strategy:                          # NOUVEAU : jamais moins de 3 pods prêts
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.7.1    # MODIFIÉ
          command:
            - ./podinfo
            - --port=9898
            - --cache-server=tcp://redis:6379
          ports:
            - containerPort: 9898
          envFrom:
            - configMapRef:
                name: podinfo-config
            - secretRef:
                name: podinfo-secret
          readinessProbe:            # NOUVEAU : prêt à recevoir du trafic ?
            httpGet:
              path: /readyz
              port: 9898
            periodSeconds: 5
          livenessProbe:             # NOUVEAU : encore vivant ?
            httpGet:
              path: /healthz
              port: 9898
            initialDelaySeconds: 5
            periodSeconds: 10
```

**Champ par champ, pour les lignes nouvelles.**

- `strategy.rollingUpdate.maxSurge: 1` : au plus 1 pod de plus que le nombre demandé pendant la mise à jour.
- `maxUnavailable: 0` : jamais moins de 3 pods prêts ; un ancien pod ne s'arrête que lorsqu'un nouveau est prêt.
- `readinessProbe` : toutes les 5 secondes, le kubelet appelle `/readyz` ; tant que la réponse n'est pas bonne, le pod ne reçoit pas de trafic.
- `livenessProbe` : toutes les 10 secondes, après 5 secondes de démarrage, il appelle `/healthz` ; après 3 échecs de suite, il redémarre le conteneur.

```bash
cd ~/tp/fil-rouge
kubectl diff -f 30-podinfo.yaml           # ce que l'apply va changer
kubectl apply -f 30-podinfo.yaml
kubectl rollout status deployment/podinfo
```

**Ligne par ligne.**

- `kubectl diff -f 30-podinfo.yaml` : affiche ce que l'`apply` changerait dans le cluster, sans rien changer.
- `kubectl apply -f 30-podinfo.yaml` : applique. Ajouter les probes modifie le modèle des pods, donc une nouvelle mise à jour progressive démarre.
- `kubectl rollout status deployment/podinfo` : attend sa fin.

## Étape 4 — Readiness : retirer un pod du trafic sans le tuer

**Pourquoi.** Une readiness en échec signifie « je suis vivant, mais ne m'envoyez pas de trafic » : c'est utile pendant un démarrage long ou une maintenance. podinfo permet de simuler cet état à la demande.

```bash
kubectl get pods -o wide                         # notez l'IP d'un pod podinfo
curl -X POST http://<IP-pod>:9898/readyz/disable
kubectl get pods -w                              # READY 0/1, mais toujours Running ; Ctrl+C
kubectl get endpointslices -l kubernetes.io/service-name=podinfo -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"  ready="}{.conditions.ready}{"\n"}{end}'
# le pod reste listé, mais avec ready=false : le Service ne lui envoie plus de trafic
curl -X POST http://<IP-pod>:9898/readyz/enable
```

**Ligne par ligne.**

- `curl -X POST http://<IP-pod>:9898/readyz/disable` : demande à ce pod de répondre en échec à sa readiness.
- `kubectl get pods -w` : `READY 0/1`, mais le pod reste `Running` et n'est pas redémarré.
- `kubectl get endpointslices … -o jsonpath='…'` : `-o jsonpath` extrait des champs précis de l'objet, ici l'adresse de chaque pod et son état `ready`.
- `curl -X POST …/readyz/enable` : rétablit le pod, qui revient dans le Service.

## Étape 5 — Liveness : une probe qui tue

**Pourquoi.** Une liveness en échec signifie « je suis bloqué, redémarrez-moi ». Mal réglée, elle fait redémarrer en boucle une application en bonne santé : vous allez le provoquer exprès.

Dans `30-podinfo.yaml`, remplacez `/healthz` par `/healthzz`, puis :

> **Prédiction.** Avec un chemin de liveness faux, les pods seront-ils retirés du Service, redémarrés, ou les deux ?

```bash
kubectl apply -f 30-podinfo.yaml
kubectl get pods -w                              # la colonne RESTARTS grimpe ; Ctrl+C
kubectl describe pod <un-pod-podinfo>            # "Liveness probe failed: HTTP probe failed with statuscode: 404"
```

**Ligne par ligne.**

- `kubectl apply -f 30-podinfo.yaml` : déploie la probe erronée.
- `kubectl get pods -w` : la colonne RESTARTS augmente environ toutes les 30 secondes (3 échecs de suite, à 10 secondes d'intervalle).
- `kubectl describe pod <pod>` : l'événement `Liveness probe failed … 404` donne la cause : le chemin `/healthzz` n'existe pas.

Remettez `/healthz`, appliquez de nouveau et attendez la fin du rollout.

## À vous, sans pas-à-pas

Passez podinfo à 5 réplicas en modifiant `30-podinfo.yaml`, pas avec `kubectl scale`. Appliquez, vérifiez que le fichier et le cluster sont d'accord, puis revenez à 3 de la même façon.

Indice : `kubectl diff` ne doit plus rien afficher à la fin.

## Point de contrôle

- [ ] `curl http://k8s-w1:30080/version` renvoie 6.7.1.
- [ ] Les 3 pods podinfo sont `1/1 READY`, sans redémarrages qui augmentent.
- [ ] `kubectl rollout history deployment/podinfo` liste au moins 3 révisions.
- [ ] `kubectl diff -f 30-podinfo.yaml` ne renvoie rien.

## Pour comprendre

1. Pendant la mise à jour vers 6.99.99, pourquoi l'application répondait-elle toujours ?
2. Quelle différence de comportement entre une readiness et une liveness en échec ?

## Bonus

```bash
kubectl apply -f ~/tp/tp06/cronjob-ping.yaml
kubectl get cronjobs,jobs -w                     # un Job par minute ; Ctrl+C
kubectl logs job/<nom-d-un-job>                  # la version de podinfo
kubectl delete -f ~/tp/tp06/cronjob-ping.yaml
```

**Ligne par ligne.** Un CronJob crée un Job à heure fixe, ici chaque minute ; chaque Job lance un pod qui interroge podinfo puis s'arrête. `kubectl get cronjobs,jobs -w` montre les Jobs apparaître, `kubectl logs job/<nom>` affiche ce qu'a écrit le pod, et `kubectl delete -f` arrête le tout.


---

[← TP5](../tp05/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP7 →](../tp07-pannes/README.md)
