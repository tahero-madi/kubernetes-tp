# TP6 — Corrigé

Mettre à jour, revenir en arrière, sonder. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pendant la mise à jour vers 6.99.99, pourquoi l'application répondait-elle toujours ?**

Avec `maxUnavailable`, les anciens pods restent en place tant que les nouveaux ne sont pas prêts ; les nouveaux ne démarrent jamais (image introuvable), donc les anciens continuent de servir.

**2. Quelle différence de comportement entre une readiness et une liveness en échec ?**

Une readiness en échec retire le pod des Services sans le redémarrer ; une liveness en échec redémarre le conteneur.

## Prédictions et « À vous »

**Prédiction (étape 2).** Non. Avec 3 réplicas, la stratégie par défaut (25 %) donne `maxUnavailable` = 0 (arrondi
inférieur) et `maxSurge` = 1 : un seul nouveau pod est créé, il reste bloqué en `ImagePullBackOff`, et les 3 anciens
continuent de servir.

**Prédiction (étape 5).** Redémarrés : la liveness échoue, le kubelet tue le conteneur (`RESTARTS` augmente). Le pod
ne sort du Service que brièvement, le temps que le conteneur reparte.

**À vous.** `replicas: 5` dans `30-podinfo.yaml`, `kubectl apply -f 30-podinfo.yaml`, `kubectl diff -f 30-podinfo.yaml`
ne renvoie rien ; puis `replicas: 3` et de nouveau `apply`.

## Fichiers corrigés

| Fichier | Contenu |
| --- | --- |
| [`30-podinfo.yaml`](30-podinfo.yaml) | Fil rouge - podinfo après le TP6 : version 6.7.1, mise à jour sans perte de capacité, probes |
