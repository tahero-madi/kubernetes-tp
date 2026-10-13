# TP9 — Corrigé

Helm, cert-manager, k9s. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Qui a recréé le Secret `podinfo-tls`, et à partir de quoi ?**

Le contrôleur de cert-manager : il constate que le Certificate `podinfo-tls` n'a plus de Secret et le recrée (réconciliation).

**2. Quelle différence de fonctionnement entre une installation Helm et un opérateur ?**

Helm installe une fois puis s'arrête ; un opérateur tourne en permanence et ramène sans cesse l'état réel vers l'état décrit.

## Prédictions et « À vous »

**Prédiction.** Le contrôleur de cert-manager, en quelques secondes : il constate que le Certificate n'a plus son Secret.

**À vous (k9s).** `:pod` puis Entrée, sélectionner un pod podinfo, `l` ; `:cert` ; `:deploy`, sélectionner podinfo,
`s`, saisir 4, puis recommencer avec 3.
