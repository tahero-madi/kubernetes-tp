# TP13 — Atelier : migrer une application de VM vers Kubernetes

**Jour 3, 15:00 · 30 min.** Objectif : appliquer la démarche des trois jours à une application réelle de votre service, et repartir avec une première liste d'objets Kubernetes. Rien à taper, tout à décider. Support : « Atelier de synthèse ».

## Déroulé

| Horaire | Activité |
| --- | --- |
| 15:00–15:05 | Consignes, groupes, choix de l'application |
| 15:05–15:20 | Remplir la grille en groupe |
| 15:20–15:30 | Restitution : 3 minutes par groupe |

## Les groupes

Le formateur forme trois groupes selon vos services. Chaque groupe traite une application qu'il connaît et qu'il pourrait réellement migrer.

| Groupe | Application traitée |
| --- | --- |
| Observabilité | Le cluster Elastic |
| Secrets et habilitations | Un service de votre périmètre |
| Applications | Une application de votre service |

## La grille

La grille est dans l'archive ; remplissez-la dans le fichier ou recopiez-la sur papier.

```bash
cat ~/tp/tp13/grille-migration.md
```

Pour chaque question, notez d'abord ce que l'on constate aujourd'hui sur la VM, puis la réponse Kubernetes. La dernière colonne indique où chercher dans le support.

| # | Question | Où chercher |
| --- | --- | --- |
| 1 | L'application garde-t-elle un état local ? | Module 16 (volumes, StatefulSet) |
| 2 | Où vont ses données, en quelle quantité ? | Sections 16.3 et 16.4 |
| 3 | Comment est-elle configurée ? | Module 8 (ConfigMaps) |
| 4 | Quels secrets utilise-t-elle ? | Sections 8.3, 8.4 et 15.4 |
| 5 | Comment sait-on qu'elle fonctionne ? | Section 9.3 (probes) |
| 6 | De quelles ressources a-t-elle besoin ? | Module 11 |
| 7 | Qui l'appelle, qui appelle-t-elle ? | Sections 7.5 à 7.7 et 15.7 |
| 8 | Comment survit-elle à une panne, comment passe-t-elle à l'échelle ? | Section 7.3 et module 14 |
| 9 | Comment l'observe-t-on ? | Module 10 |
| 10 | Quels droits lui faut-il sur la machine ? | Sections 15.5 et 15.6 |
| 11 | Comment est-elle livrée ? | Section 1.7 et module 13 (Helm) |

## Consignes

- Chaque réponse désigne un objet Kubernetes précis (Deployment, PersistentVolumeClaim, Secret, NetworkPolicy…), pas une intention.
- Ce que vous ne savez pas, notez-le « à vérifier » : c'est une question à poser dans votre service.
- Désignez un rapporteur dès le début.

## Restitution (3 minutes par groupe)

1. Les objets Kubernetes retenus.
2. Le point le plus délicat de la migration.
3. La première action à mener après la formation.

## Point de contrôle

- [ ] Les 11 lignes de la grille sont remplies ou marquées « à vérifier ».
- [ ] Chaque réponse cite au moins un objet Kubernetes.
- [ ] Le groupe a présenté sa restitution.

## Pour comprendre

1. Quel objet Kubernetes a été le plus difficile à choisir pour votre application, et pourquoi ?

## Et ensuite

À 15:30 : QCM final (20 questions, 15 minutes), bilan et évaluation de la formation. Gardez la grille remplie : c'est le point de départ de votre projet.


---

[← TP12](../tp12/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md)
