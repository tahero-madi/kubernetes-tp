# TP4 — Corrigé

Premiers manifestes et YAML cassés. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Quelle différence entre `--dry-run=client` et `--dry-run=server` ?**

`--dry-run=client` ne fait que construire l'objet localement, sans le soumettre à l'API ; `--dry-run=server` le soumet à toute la chaîne de l'API server (validation, admission, droits) sans l'enregistrer.

**2. Que contient la section `status` d'un objet, et qui l'écrit ?**

L'état observé : phase, conditions, IP du pod et du nœud, état des conteneurs. Il est écrit par Kubernetes (le kubelet, les contrôleurs), jamais par vous.

## Prédictions et « À vous »

**Prédiction.** Kubernetes a ajouté la section `status` (phase, IP du pod et du nœud, conditions, état des conteneurs),
`metadata.uid`, `creationTimestamp`, `resourceVersion`, et des valeurs par défaut dans `spec` : `nodeName`,
`restartPolicy: Always`, `imagePullPolicy: IfNotPresent`, `dnsPolicy`, `serviceAccountName: default`,
`terminationGracePeriodSeconds: 30`, les tolérances `not-ready` et `unreachable` de 300 s et le volume du jeton
de ServiceAccount.

**À vous.**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cache
  labels:
    app: cache
spec:
  containers:
    - name: redis
      image: mirror.gcr.io/library/redis:7-alpine
      ports:
        - containerPort: 6379
```
`kubectl apply --dry-run=server -f 02-cache.yaml`, puis `kubectl apply -f 02-cache.yaml`, `kubectl get pod cache`,
`kubectl delete -f 02-cache.yaml`.

## Fichiers corrigés

| Fichier | Contenu |
| --- | --- |
| [`00-namespace.yaml`](00-namespace.yaml) | Version attendue |
| [`01-pod.yaml`](01-pod.yaml) | Version attendue |
| [`casse-1-corrige.yaml`](casse-1-corrige.yaml) | Erreur : une tabulation dans l'indentation de la ligne image (YAML n'accepte que des espaces) |
| [`casse-2-corrige.yaml`](casse-2-corrige.yaml) | Erreur : version: 6.7 est lu comme un nombre ; une valeur de label doit être une chaîne |
| [`casse-3-corrige.yaml`](casse-3-corrige.yaml) | Erreur : faute de frappe contianers -> containers |
| [`casse-4-corrige.yaml`](casse-4-corrige.yaml) | Erreur : ports attend une liste d'objets containerPort, pas un nombre |

À vous (`02-cache.yaml`) : voir la section précédente.
