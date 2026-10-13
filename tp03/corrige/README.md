# TP3 — Corrigé

Gérer les nœuds, premier déploiement. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pourquoi aucun pod `hello` ne tourne-t-il sur `k8s-cp` ?**

Le control plane porte la taint `node-role.kubernetes.io/control-plane:NoSchedule` ; les pods hello ne la tolèrent pas.

**2. Que devient un pod supprimé à la main, et quel composant en décide ?**

Il est recréé aussitôt, avec un autre nom : le ReplicaSet constate qu'il manque un pod par rapport à l'état désiré et en crée un nouveau.

## Prédictions et « À vous »

**Prédiction (étape 4).** Toujours 4 : le ReplicaSet recrée aussitôt un pod, sous un autre nom.

**Prédiction (étape 6).** Les nouveaux pods vont sur `k8s-w1`. Ceux déjà sur `k8s-w2` restent : `NoSchedule`
n'expulse pas, `NoExecute` le ferait.

**À vous.**
```bash
kubectl scale deployment hello --replicas=0
kubectl get endpointslices -l kubernetes.io/service-name=hello   # plus aucune adresse
curl http://k8s-w1:<NodePort>         # Connection refused : kube-proxy rejette, le Service n'a plus de pod
kubectl scale deployment hello --replicas=4
```
