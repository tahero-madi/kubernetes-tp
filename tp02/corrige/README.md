# TP2 — Corrigé

Initialiser le cluster, installer Calico, joindre les workers. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pourquoi les nœuds restent-ils `NotReady` tant que Calico n'est pas installé ?**

Aucun plugin réseau (CNI) n'est installé : le kubelet déclare le nœud NotReady tant que le réseau des pods n'existe pas.

**2. Où se trouvent les définitions de l'API server, d'etcd et du scheduler, et qui les lance ?**

Dans `/etc/kubernetes/manifests/` sur k8s-cp ; c'est le kubelet qui les lance, sous forme de pods statiques.

## Prédictions et « À vous »

**Prédiction (étape 4).** `NotReady` pendant quelques dizaines de secondes, le temps que le DaemonSet `calico-node`
démarre sur le nouveau nœud, puis `Ready`.

**À vous.** `kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide` : deux pods, avec des IP en 10.244.x.y.
Ils sont souvent sur `k8s-cp` : CoreDNS tolère la taint du control plane et a démarré quand ce nœud était seul.
