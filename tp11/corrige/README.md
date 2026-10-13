# TP11 — Corrigé

Sécuriser le fil rouge. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pourquoi `lecteur` ne peut-il pas lire les Secrets, alors qu'aucune règle ne l'interdit ?**

Le Role `lecture` n'accorde des droits que sur les pods, services et deployments ; RBAC refuse tout ce qui n'est pas explicitement permis, donc les Secrets.

**2. Après la seule policy `refus-par-defaut`, pourquoi le pod `client` ne joignait-il plus podinfo ? Et pourquoi tester depuis un pod plutôt que par le NodePort ?**

La policy `refus-par-defaut` sélectionne tous les pods du namespace en entrée sans rien autoriser : le trafic venant des autres pods est bloqué. On teste depuis un pod parce qu'une NetworkPolicy ne bloque jamais le trafic venant du nœud où tourne le pod ; or le NodePort fait entrer le trafic par un nœud, souvent avec l'adresse de ce nœud (SNAT). Le résultat varierait selon le pod choisi (documentation Kubernetes, « What you can't do with network policies »).

## Prédictions et « À vous »

**Prédiction.** Non dans les deux cas : `refus-par-defaut` bloque toute entrée vers tous les pods du namespace, Redis
compris. Le cache de podinfo ne fonctionne plus jusqu'aux autorisations du fichier 91.

**À vous.**
```bash
kubectl create role lecture -n fil-rouge --verb=get,list,watch --resource=pods,services,deployments,configmaps --dry-run=client -o yaml | kubectl apply -f -
kubectl auth can-i get configmaps -n fil-rouge --as=system:serviceaccount:fil-rouge:lecteur   # yes
kubectl auth can-i get secrets -n fil-rouge --as=system:serviceaccount:fil-rouge:lecteur      # no
```
