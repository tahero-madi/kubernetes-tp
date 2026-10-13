# TP8 — Encadrer un namespace d'équipe, labels

**Jour 3, 09:25 · 45 min.** Objectif : donner un budget et des valeurs par défaut à un namespace, voir le quota bloquer et la mémoire tuer, puis manipuler labels et annotations. Support : sections 11.1 à 11.6 et 12.1 à 12.3.

## Étape 1 — Un namespace avec budget

**Pourquoi.** Quand plusieurs équipes partagent un cluster, on donne à chacune un namespace avec un budget (ResourceQuota) et des valeurs par défaut (LimitRange). Sans cela, une seule application mal réglée peut consommer tout le cluster.

```bash
kubectl create namespace equipe-a
cat ~/tp/tp08/40-quota.yaml                      # lisez les deux objets
kubectl apply -f ~/tp/tp08/40-quota.yaml
kubectl describe quota -n equipe-a
kubectl describe limitrange -n equipe-a
```

**Ligne par ligne.**

- `cat ~/tp/tp08/40-quota.yaml` : le ResourceQuota plafonne les totaux du namespace (CPU et mémoire réservés, limites, nombre de pods) ; la LimitRange fixe, pour chaque conteneur, des valeurs par défaut et des maximums.
- `kubectl describe quota -n equipe-a` : la colonne Used (consommé) face à la colonne Hard (plafond).
- `kubectl describe limitrange -n equipe-a` : les valeurs par défaut et les bornes.

## Étape 2 — Valeurs injectées par la LimitRange

**Pourquoi.** Vous allez créer des pods sans rien déclarer, et voir la LimitRange compléter leurs requests et leurs limits. Les requests sont ce que le scheduler réserve pour placer un pod ; les limits sont le plafond qu'il ne peut pas dépasser.

```bash
kubectl create deployment web -n equipe-a --image=ghcr.io/stefanprodan/podinfo:6.7.1 --replicas=2
kubectl get pods -n equipe-a -o yaml | grep -A6 resources:    # vous n'avez rien déclaré...
kubectl get pods -n equipe-a -o custom-columns=NOM:.metadata.name,QOS:.status.qosClass
kubectl describe quota -n equipe-a                            # colonne Used
```

**Ligne par ligne.**

- `kubectl create deployment web -n equipe-a … --replicas=2` : 2 pods podinfo, sans requests ni limits dans la commande.
- `kubectl get pods -n equipe-a -o yaml | grep -A6 resources:` : affiche les 6 lignes qui suivent chaque `resources:` ; les valeurs viennent de la LimitRange.
- `-o custom-columns=NOM:.metadata.name,QOS:.status.qosClass` : un tableau aux colonnes choisies ; la classe QoS fixe l'ordre dans lequel les pods sont expulsés quand un nœud manque de mémoire.
- `kubectl describe quota -n equipe-a` : la colonne Used a augmenté.

## Étape 3 — Le quota bloque

**Pourquoi.** Un quota ne joue pas seulement à la création : il bloque toute demande qui ferait dépasser le plafond, y compris un simple changement du nombre de réplicas. Le calcul porte sur les requests réservées, pas sur la consommation réelle.

Avant de lancer la commande, écrivez votre pronostic : à combien de pods le déploiement va-t-il s'arrêter ? ............

```bash
kubectl scale deployment web -n equipe-a --replicas=15
kubectl get deployment web -n equipe-a                        # READY x/15
kubectl get events -n equipe-a | grep -i quota                # exceeded quota
kubectl describe quota -n equipe-a
kubectl scale deployment web -n equipe-a --replicas=2
```

**Ligne par ligne.**

- `kubectl scale deployment web -n equipe-a --replicas=15` : demande 15 pods.
- `kubectl get deployment web -n equipe-a` : READY indique combien ont réellement pu être créés.
- `kubectl get events -n equipe-a | grep -i quota` : les refus `exceeded quota` du contrôleur.
- `kubectl describe quota -n equipe-a` : quelle ressource a atteint son plafond.
- `kubectl scale … --replicas=2` : revient à la situation de départ.

## Étape 4 — La mémoire tue

**Pourquoi.** La limite mémoire est un plafond strict : un conteneur qui la dépasse est tué par le noyau. Pour le CPU, c'est différent : au-delà de sa limite, un conteneur est seulement ralenti.

Ce pod tente d'allouer 300 Mo alors que la LimitRange lui impose une limite de 128 Mi :

> **Prédiction.** Ce pod sera-t-il refusé à la création, ralenti, ou tué en cours de route ?

```bash
kubectl run gourmand -n equipe-a --image=mirror.gcr.io/library/python:3.12-alpine --restart=Never --command -- python -c "x = ' ' * 300_000_000; import time; time.sleep(600)"
kubectl get pod gourmand -n equipe-a -w                       # OOMKilled ; Ctrl+C
kubectl describe pod gourmand -n equipe-a | grep -A4 State    # Reason: OOMKilled, Exit Code: 137
kubectl delete pod gourmand -n equipe-a
```

**Ligne par ligne.**

- `kubectl run gourmand … --command -- python -c "x = ' ' * 300_000_000; …"` : un programme Python qui réserve 300 Mo de mémoire puis attend ; `--command` indique que ce qui suit `--` remplace la commande de l'image.
- `kubectl get pod gourmand -n equipe-a -w` : le statut passe à `OOMKilled` (Out Of Memory, tué pour manque de mémoire).
- `kubectl describe pod gourmand … | grep -A4 State` : `Reason: OOMKilled` et le code de sortie 137, soit 128 + 9, le numéro du signal SIGKILL envoyé par le noyau.
- `kubectl delete pod gourmand -n equipe-a` : nettoyage.

## Étape 5 — Labels et annotations sur le fil rouge

**Pourquoi.** Les labels servent à sélectionner : un Service choisit ses pods par label, kubectl filtre par label. Les annotations servent à documenter (auteur, description, lien vers un ticket) et ne sélectionnent rien.

```bash
kubectl get pods -n fil-rouge --show-labels
kubectl get pods -n fil-rouge -l 'app in (podinfo,redis)' -L app
kubectl label pods -n fil-rouge -l app=redis tier=donnees
kubectl get pods -n fil-rouge -l tier=donnees
kubectl annotate deployment podinfo -n fil-rouge description="Démonstrateur formation INSEE"
kubectl describe deployment podinfo -n fil-rouge | grep -A3 Annotations
```

**Ligne par ligne.**

- `kubectl get pods -n fil-rouge --show-labels` : tous les labels de chaque pod.
- `-l 'app in (podinfo,redis)' -L app` : sélection par ensemble de valeurs ; `-L app` ajoute la colonne du label.
- `kubectl label pods -n fil-rouge -l app=redis tier=donnees` : ajoute un label à tous les pods sélectionnés.
- `kubectl annotate deployment podinfo … description="…"` : ajoute une annotation, visible ensuite dans `describe`.

## À vous, sans pas-à-pas

Dans `equipe-a`, créez un Deployment `mini` de 3 pods podinfo dont chaque conteneur demande 50m de CPU et 64Mi de mémoire, sans déclarer de limite. Avant de vérifier, prédisez la classe QoS de ces pods et ce qu'ils ajoutent à la colonne Used du quota. Contrôlez, puis supprimez `mini`.

Indice : `kubectl set resources deployment mini --requests=...` ; la LimitRange complète ce que vous ne déclarez pas.

## Point de contrôle

- [ ] Vous savez expliquer, chiffres à l'appui, pourquoi le déploiement s'est arrêté à ce nombre de pods.
- [ ] Vous avez vu un conteneur `OOMKilled`, code de sortie 137.
- [ ] Le pod redis porte le label `tier=donnees`.

## Pour comprendre

1. Pourquoi le déploiement plafonne-t-il à 8 pods, alors que le quota en autorise 10 ?
2. Quelle est la classe QoS des pods `web`, et pourquoi ?

## Bonus

Écrivez un pod dans `equipe-a` dont les requests sont égales aux limits, pour le CPU et la mémoire, et vérifiez qu'il obtient la classe `Guaranteed`.


---

[← TP7](../tp07-pannes/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP9 →](../tp09/README.md)
