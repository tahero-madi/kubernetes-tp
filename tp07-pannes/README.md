# TP7 — Chasse aux pannes

**Jour 2, 14:30 · 60 min, seul ou en binôme, selon la consigne du formateur.** Objectif : diagnostiquer six pannes courantes avec la méthode `get` → `describe` → `logs` → `events`, comme en production. Support : sections 10.1 à 10.7 ; le tableau 10.9 et le corrigé du TP donnent les réponses : ne les lisez qu'après la chasse.

## Étape 1 — Installer metrics-server

**Pourquoi.** metrics-server collecte la consommation CPU et mémoire des nœuds et des pods. Il est indispensable à `kubectl top` aujourd'hui et à l'autoscaling du jour 3. L'option `--kubelet-insecure-tls` est nécessaire car kubeadm signe lui-même les certificats des kubelets, auxquels metrics-server refuserait sinon de faire confiance.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml
kubectl -n kube-system patch deployment metrics-server --type=json -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deployment metrics-server
kubectl top nodes                        # après environ une minute
kubectl top pods -A --sort-by=memory
```

**Ligne par ligne.**

- `kubectl apply -f …/components.yaml` : installe metrics-server, qui interroge régulièrement chaque kubelet sur la consommation CPU et mémoire.
- `kubectl -n kube-system patch deployment metrics-server --type=json -p='[…]'` : ajoute l'argument `--kubelet-insecure-tls` aux arguments du conteneur. Un patch JSON vise un emplacement précis : `/spec/template/spec/containers/0/args/-`, où `0` est le premier conteneur et `-` la fin de la liste.
- `kubectl -n kube-system rollout status deployment metrics-server` : attend son redémarrage.
- `kubectl top nodes` et `kubectl top pods -A --sort-by=memory` : la consommation réelle, triée par mémoire.

## Étape 2 — Déployer les pannes

**Pourquoi.** Six Deployments, chacun avec une seule erreur, dans un namespace à part pour ne pas toucher au fil rouge.

```bash
kubectl create namespace pannes
kubectl apply -n pannes -f ~/tp/tp07-pannes/
kubectl get pods -n pannes
```

**Ligne par ligne.** `kubectl apply -n pannes -f ~/tp/tp07-pannes/` applique tous les fichiers du dossier (`-f` accepte un dossier) dans le namespace `pannes` ; `kubectl get pods -n pannes` donne le premier coup d'œil, avant toute analyse.

Règle du jeu : ne lisez pas les fichiers `panne-N.yaml` avant d'avoir trouvé. Diagnostiquez depuis le cluster, comme si quelqu'un d'autre avait déployé.

## Étape 3 — Diagnostiquer

**Pourquoi.** Face à une panne, on va toujours du général au particulier : l'état du pod, puis son histoire (les événements), puis ce que dit le programme (les logs). Cette méthode trouve la cause sans deviner, et c'est elle que vous appliquerez en production.

Pour chaque panne, dans l'ordre :

```bash
kubectl get pods -n pannes                         # état, READY, RESTARTS
kubectl describe pod -n pannes <pod>               # section Events, en bas
kubectl logs -n pannes <pod> --previous            # si le conteneur a déjà redémarré
kubectl events -n pannes --types=Warning
```

**Ligne par ligne.**

- `kubectl get pods` : les colonnes STATUS (état), READY (conteneurs prêts sur total) et RESTARTS orientent le diagnostic.
- `kubectl describe pod <pod>` : la section Events raconte la vie du pod : placement, téléchargement de l'image, démarrage, probes.
- `kubectl logs <pod> --previous` : les messages du conteneur précédent, celui qui s'est arrêté ; sans `--previous`, vous verriez celui qui redémarre.
- `kubectl events --types=Warning` : seulement les événements anormaux du namespace.

La panne 2 ne se voit pas dans l'état du pod : testez son Service.

```bash
kubectl run test -n pannes --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- wget -qO- -T 3 http://panne-2:9898
kubectl get endpointslices -n pannes
kubectl get pods -n pannes --show-labels
```

**Ligne par ligne.**

- `kubectl run test … -- wget -qO- -T 3 http://panne-2:9898` : joint le Service par son nom ; `-T 3` abandonne après 3 secondes.
- `kubectl get endpointslices -n pannes` : un Service sans adresse ne mène à aucun pod.
- `kubectl get pods -n pannes --show-labels` : comparez les labels des pods au sélecteur du Service (`kubectl describe svc panne-2`).

Les pannes 1 à 4 sont pour tous, les pannes 5 et 6 pour les plus rapides. Remplissez :

| Panne | Symptôme | Commande révélatrice | Cause | Correction |
| --- | --- | --- | --- | --- |
| 1 |  |  |  |  |
| 2 |  |  |  |  |
| 3 |  |  |  |  |
| 4 |  |  |  |  |
| 5 |  |  |  |  |
| 6 |  |  |  |  |

## Étape 4 — Réparer

**Pourquoi.** Diagnostiquer ne suffit pas : on corrige, puis on vérifie que la correction a l'effet attendu. Corrigez chaque panne directement dans le cluster, puis vérifiez que le pod passe `1/1 Running` :

```bash
kubectl edit deployment panne-1 -n pannes        # ou kubectl edit service panne-2 -n pannes
kubectl get pods -n pannes -w
```

**Ligne par ligne.** `kubectl edit deployment panne-1 -n pannes` ouvre l'objet du cluster dans l'éditeur ; à l'enregistrement, la modification s'applique aussitôt et les pods sont recréés. `kubectl get pods -n pannes -w` montre le résultat en direct.

Correction collective de 15 minutes en fin de TP.

## À vous, sans pas-à-pas

Échangez les claviers avec votre voisin : chacun casse quelque chose dans le Deployment `podinfo` de l'autre avec une seule commande (`kubectl set image` ou `kubectl set env`, par exemple), sans la montrer. Diagnostiquez avec la méthode, réparez, puis remettez le fichier en accord avec `kubectl apply -f ~/tp/fil-rouge/30-podinfo.yaml`.

Indice : `kubectl rollout history` et `kubectl diff -f` montrent ce qui a changé.

## Point de contrôle

- [ ] `kubectl top nodes` répond.
- [ ] Les pannes 1 à 4 sont identifiées et corrigées.
- [ ] Pour chaque panne, vous savez quelle commande a révélé la cause.

## Fin du jour 2

À 15:30, rattrapage : terminez les points de contrôle en retard ou faites les bonus. À 15:45, quiz. Puis nettoyez :

```bash
kubectl delete namespace pannes
```

Supprimer le namespace `pannes` supprime en une fois tous les objets qu'il contient.

Laissez le namespace `fil-rouge` en place : il sert tout le jour 3.


---

[← TP6](../tp06/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP8 →](../tp08/README.md)
