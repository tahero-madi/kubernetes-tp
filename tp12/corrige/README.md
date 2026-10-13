# TP12 — Corrigé

Rendre Redis persistant. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pourquoi le PVC est-il resté `Pending` jusqu'au redéploiement de Redis ?**

La StorageClass est en `WaitForFirstConsumer` : le PVC n'est lié qu'au moment où un pod l'utilise, pour choisir un volume accessible depuis le nœud du pod.

**2. Pourquoi passer le Deployment Redis en stratégie `Recreate` ?**

Deux instances Redis ne doivent jamais écrire en même temps dans les mêmes fichiers ; `Recreate` arrête l'ancien pod avant de démarrer le nouveau.

## Prédictions et « À vous »

**Prédiction (étape 6).** Oui : Redis rejoue son journal depuis `/data`, monté depuis `/mnt/data/redis` sur `k8s-w1`.

**À vous.**
```bash
curl -X POST -d 'deux' http://k8s-w1:30080/cache/cle2
kubectl delete deployment redis -n fil-rouge
kubectl get pvc -n fil-rouge                  # redis-data reste Bound : le PVC vit indépendamment du Deployment
kubectl apply -f ~/tp/fil-rouge/10-redis.yaml
kubectl rollout status deployment redis -n fil-rouge
curl http://k8s-w1:30080/cache/cle2           # deux
```
Si l'on supprimait le PVC : le PV passerait `Released` (politique `Retain`), les fichiers resteraient dans
`/mnt/data/redis`, mais un nouveau PVC ne s'y lierait pas sans nettoyage manuel du PV. Avec la politique `Delete`
et un provisionneur, les données seraient effacées.

## Fichiers corrigés

| Fichier | Contenu |
| --- | --- |
| [`10-redis.yaml`](10-redis.yaml) | Fil rouge - Redis après le TP12 : données persistantes sur le PVC redis-data |
