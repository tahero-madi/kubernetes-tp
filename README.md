# Kubernetes – Mise en œuvre · Travaux pratiques

Formation INSEE, du 14 au 16 octobre 2026. Treize travaux pratiques sur votre propre cluster de 3 nœuds,
que vous construisez au jour 1 et exploitez jusqu'au jour 3.

## Comment travailler

- **Lisez l'énoncé ici**, sur GitHub, dans le navigateur de votre poste. Chaque bloc de commandes a un bouton
  de copie en haut à droite.
- **Tapez ou collez les commandes dans la console web**, connectée à vos VM.
- Commencez par [Avant de commencer](avant-de-commencer.md) : vos adresses IP, les conventions du cahier et
  l'usage de la console.

## Récupérer les fichiers sur k8s-cp

Au début du TP1, sur `k8s-cp` :

```bash
sudo apt-get update -q && sudo apt-get install -y git unzip tmux
git clone https://github.com/tahero-madi/kubernetes-tp.git ~/tp
ls ~/tp
```

Si le formateur modifie un fichier pendant la formation, `cd ~/tp && git pull` récupère la nouvelle version.

## Corrigés

Le corrigé de chaque TP est publié **à la fin de ce TP**, dans un dossier `corrige/` du TP : `tp05/corrige/`
pour le TP5, par exemple. Il contient les réponses aux questions « Pour comprendre », les résultats attendus
des prédictions, la solution du « À vous » et, selon le TP, les fichiers YAML attendus.

Pour le lire, ouvrez le dossier du TP ici sur GitHub. Pour l'avoir aussi sur `k8s-cp` :

```bash
cd ~/tp && git pull
ls ~/tp/tp05/corrige/
```

`git pull` ajoute les nouveaux dossiers `corrige/` sans toucher aux fichiers que vous avez modifiés.
Cherchez d'abord par vous-même : le corrigé sert à vérifier, ou à rattraper un retard.

## Programme des TP

| Quand | TP | Durée |
| --- | --- | --- |
| Jour 1, 10:50 | [TP1 — Préparer les 3 nœuds, premiers conteneurs avec ctr](tp01/README.md) | 70 min |
| Jour 1, 13:15 | [TP2 — Initialiser le cluster, installer Calico, joindre les workers](tp02/README.md) | 75 min |
| Jour 1, 14:35 | [TP3 — Gérer les nœuds, premier déploiement](tp03/README.md) | 60 min |
| Jour 2, 09:30 | [TP4 — Premiers manifestes et YAML cassés](tp04/README.md) | 35 min |
| Jour 2, 10:30 | [TP5 — Application fil rouge podinfo + Redis](tp05/README.md) | 70 min |
| Jour 2, 13:00 | [TP6 — Mettre à jour, revenir en arrière, sonder](tp06/README.md) | 70 min |
| Jour 2, 14:30 | [TP7 — Chasse aux pannes](tp07-pannes/README.md) | 60 min |
| Jour 3, 09:25 | [TP8 — Encadrer un namespace d'équipe, labels](tp08/README.md) | 45 min |
| Jour 3, 10:25 | [TP9 — Helm, cert-manager, k9s](tp09/README.md) | 30 min |
| Jour 3, 11:15 | [TP10 — HPA sous charge](tp10/README.md) | 30 min |
| Jour 3, 13:20 | [TP11 — Sécuriser le fil rouge](tp11/README.md) | 50 min |
| Jour 3, 14:15 | [TP12 — Rendre Redis persistant](tp12/README.md) | 45 min |
| Jour 3, 15:00 | [TP13 — Atelier : migrer une application de VM vers Kubernetes](tp13/README.md) | 30 min |

En cas de problème : [En cas de blocage](en-cas-de-blocage.md).

## Contenu du dépôt

| Dossier | Contenu |
| --- | --- |
| `tp01/` à `tp13/` | L'énoncé du TP (`README.md`) et ses fichiers |
| `tp01/prep-node.sh` | Le script qui prépare les workers au TP1 |
| `tp02/calico-installation.yaml` | Le réseau des pods de Calico |
| `tp04/casse-*.yaml` | Quatre fichiers YAML à réparer |
| `fil-rouge/` | L'application podinfo + Redis, utilisée du TP5 au TP12 |
| `tp07-pannes/` | L'énoncé du TP7 et les six pannes (ne lisez pas les fichiers `panne-N.yaml` avant d'avoir trouvé) |
| `tpXX/corrige/` | Le corrigé du TP, publié à la fin du TP |
