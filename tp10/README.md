# TP10 — HPA sous charge

**Jour 3, 11:15 · 30 min.** Objectif : voir Kubernetes ajouter puis retirer des réplicas en fonction de la charge CPU. Prérequis : metrics-server du TP7 (`kubectl top nodes` doit répondre). Support : section 14.2.

## Étape 1 — Déployer l'application et son autoscaler

**Pourquoi.** Un HorizontalPodAutoscaler (HPA) ajuste le nombre de réplicas d'un Deployment selon une mesure, ici l'utilisation du CPU. Il raisonne en pourcentage des requests : sans request CPU, pas d'autoscaling. Il s'appuie sur metrics-server, installé au TP7.

```bash
kubectl create namespace charge
cat ~/tp/tp10/70-hpa.yaml                        # repérez requests.cpu et averageUtilization
kubectl apply -n charge -f ~/tp/tp10/70-hpa.yaml
kubectl get hpa -n charge -w                     # attendre cpu: 0%/50% au lieu de <unknown> ; Ctrl+C
```

**Ligne par ligne.**

- `kubectl create namespace charge` : un namespace jetable pour l'exercice.
- `cat ~/tp/tp10/70-hpa.yaml` : un Deployment `php-apache` (request de 200m de CPU, soit un cinquième de cœur), son Service, et l'HPA : entre 1 et 8 réplicas, cible 50 %.
- `kubectl apply -n charge -f …` : crée les trois objets.
- `kubectl get hpa -n charge -w` : la colonne TARGETS affiche l'utilisation mesurée face à la cible ; `<unknown>` tant que metrics-server n'a pas encore de mesure.

## Étape 2 — Générer de la charge

**Pourquoi.** Pour voir l'HPA réagir, il faut de la charge : un petit pod va appeler l'application en continu, pendant que vous observez dans l'autre terminal.

> **Prédiction.** L'HPA vise 50 % des requests CPU, avec 8 réplicas au maximum. Sous charge continue, jusqu'où pensez-vous qu'il montera ?

Dans un **second terminal** :

```bash
kubectl run charge -n charge --image=mirror.gcr.io/library/busybox:1.36 --restart=Never -it --rm -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

**Ligne par ligne.** Ce pod appelle le Service `php-apache` en boucle, cent fois par seconde (`while sleep 0.01`) ; `wget -q -O-` lit la page sans l'enregistrer. Chaque appel fait calculer le serveur, et le CPU monte.

Dans le premier terminal, observez pendant 2 à 3 minutes :

```bash
kubectl get hpa -n charge -w                     # la colonne REPLICAS monte
kubectl top pods -n charge                       # dans un 3e terminal si vous le souhaitez
```

**Ligne par ligne.** Suivez TARGETS et REPLICAS dans `kubectl get hpa -w` ; `kubectl top pods -n charge` montre la consommation réelle de chaque pod.

## Étape 3 — Arrêter la charge

**Pourquoi.** L'HPA ajoute des pods vite, mais en retire prudemment : il attend que la charge soit retombée durablement, pour ne pas supprimer des pods juste avant un nouveau pic.

Tapez Ctrl+C dans le second terminal, puis observez la redescente : elle ne commence qu'après environ 5 minutes.

```bash
kubectl describe hpa php-apache -n charge        # section Events : les décisions de l'HPA
```

**Ligne par ligne.** `kubectl describe hpa php-apache -n charge` liste dans Events chaque décision de l'HPA, avec sa raison, par exemple `New size: 4; reason: cpu resource utilization (percentage of request) above target`.

## À vous, sans pas-à-pas

Pendant la redescente, retrouvez avec kubectl seul, sans ouvrir le fichier : la cible de l'HPA, ses minimum et maximum, et la request CPU des pods qu'il pilote.

Indice : `kubectl get hpa -o yaml` pour l'HPA, `kubectl get deployment -o jsonpath=...` pour les requests.

## Point de contrôle

- [ ] L'HPA a dépassé 3 réplicas sous charge.
- [ ] Vous avez lu dans `describe hpa` la raison de chaque changement.

## Pour comprendre

1. Pourquoi l'HPA affiche-t-il `<unknown>` au début ?
2. Pourquoi la redescente est-elle plus lente que la montée ?

## Bonus

Ajoutez sous `spec` de l'HPA ce réglage, appliquez, relancez la charge et comparez la redescente :

```yaml
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
```

`stabilizationWindowSeconds: 60` : l'HPA attend 60 secondes de calme, au lieu de 300 par défaut, avant de retirer des pods. Plus court, il réagit plus vite mais risque de retirer des pods juste avant un nouveau pic.

## Fin du TP

```bash
kubectl delete namespace charge
```

Supprimer un namespace supprime tout ce qu'il contient : Deployments, pods, Services et HPA.


---

[← TP9](../tp09/README.md) · [Sommaire](../README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP11 →](../tp11/README.md)
