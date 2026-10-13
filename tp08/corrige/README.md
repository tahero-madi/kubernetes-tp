# TP8 — Corrigé

Encadrer un namespace d'équipe, labels. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pourquoi le déploiement plafonne-t-il à 8 pods, alors que le quota en autorise 10 ?**

Chaque pod reçoit de la LimitRange une request mémoire de 128Mi ; le quota autorise 1Gi de requests mémoire, soit 8 pods (8 x 128Mi = 1Gi). Le 9e dépasserait le quota.

**2. Quelle est la classe QoS des pods `web`, et pourquoi ?**

Burstable : les requests et les limits sont déclarées mais différentes pour le CPU (100m contre 200m).

## Prédictions et « À vous »

**Prédiction (étape 4).** Créé, puis tué (`OOMKilled`, code 137) : la limite mémoire n'est pas contrôlée à la création,
c'est le noyau qui tue le processus quand il la dépasse.

**À vous.**
```bash
kubectl create deployment mini -n equipe-a --image=ghcr.io/stefanprodan/podinfo:6.7.1 --replicas=3
kubectl set resources deployment mini -n equipe-a --requests=cpu=50m,memory=64Mi
kubectl get pods -n equipe-a -l app=mini -o custom-columns=NOM:.metadata.name,QOS:.status.qosClass   # Burstable
kubectl describe quota -n equipe-a
kubectl delete deployment mini -n equipe-a
```
Burstable : les requests (50m, 64Mi) diffèrent des limites posées par la LimitRange (200m, 128Mi). Le quota augmente
de 150m et 192Mi en requests, de 600m et 384Mi en limits, et de 3 pods.
