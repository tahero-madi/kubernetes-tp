# TP1 — Corrigé

Préparer les 3 nœuds, premiers conteneurs avec ctr. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pourquoi faut-il désactiver le swap et activer `ip_forward` ?**

Swap : par défaut, le kubelet refuse de démarrer avec du swap actif, car le swap fausse la mesure et la garantie de la mémoire des pods. ip_forward : le nœud doit router les paquets entre ses pods, les autres nœuds et l'extérieur.

**2. À l'étape 6, `cat /etc/os-release` et `uname -r` donnent-ils le système de l'image ou celui de la VM ? Qu'en concluez-vous ?**

`/etc/os-release` lu dans le conteneur affiche Debian (l'espace utilisateur vient de l'image) ; `uname -r` affiche le noyau Ubuntu de la VM : le noyau est partagé.

## Prédictions et « À vous »

**Prédiction (étape 6).** Pas de machine virtuelle : le conteneur est un processus ordinaire de la VM, visible avec `ps`,
isolé par des namespaces et limité par un cgroup.

**À vous.**
```bash
sudo ctr images pull mirror.gcr.io/library/busybox:1.36
sudo ctr run -d mirror.gcr.io/library/busybox:1.36 dodo sleep 600
sudo ctr tasks ls                     # PID de dodo
sudo kill -9 <PID>
sudo ctr tasks ls                     # dodo : STOPPED
sudo ctr tasks delete dodo && sudo ctr containers delete dodo
```
Le conteneur s'arrête avec son processus : il n'y a rien d'autre derrière.
