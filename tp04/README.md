# TP4 — Premiers manifestes et YAML cassés

**Jour 2, 09:30 · 35 min.** Objectif : écrire un manifeste à la main, l'appliquer, le lire, et apprendre à lire les messages d'erreur YAML. Support : sections 6.2 à 6.5 et 6.9.

## Étape 1 — Préparer l'éditeur et le namespace du fil rouge

**Pourquoi.** Dans un fichier YAML, l'indentation porte le sens et les tabulations sont interdites : on règle l'éditeur pour qu'il n'insère que des espaces. On crée ensuite le namespace `fil-rouge`, un espace de noms qui regroupera l'application des TP suivants, et on en fait le namespace par défaut de kubectl.

```bash
echo "set expandtab tabstop=2 shiftwidth=2 autoindent" >> ~/.vimrc   # indentation en espaces dans vim
cd ~/tp/tp04
kubectl create namespace fil-rouge --dry-run=client -o yaml > 00-namespace.yaml
cat 00-namespace.yaml
kubectl apply -f 00-namespace.yaml
kubectl config set-context --current --namespace=fil-rouge
kubectl config get-contexts                 # colonne NAMESPACE : fil-rouge
```

**Ligne par ligne.**

- `echo "set expandtab tabstop=2 shiftwidth=2 autoindent" >> ~/.vimrc` : vim remplace la touche Tab par 2 espaces et reprend l'indentation de la ligne précédente.
- `cd ~/tp/tp04` : vous travaillez dans le dossier du TP.
- `kubectl create namespace fil-rouge --dry-run=client -o yaml > 00-namespace.yaml` : `--dry-run=client` n'envoie rien au cluster, `-o yaml` affiche l'objet qui aurait été créé, `>` l'enregistre dans un fichier. C'est la façon la plus sûre d'obtenir un modèle de manifeste.
- `kubectl apply -f 00-namespace.yaml` : crée l'objet décrit par le fichier.
- `kubectl config set-context --current --namespace=fil-rouge` : vos commandes viseront désormais `fil-rouge` sans qu'il faille ajouter `-n`.
- `kubectl config get-contexts` : vérifie le namespace du contexte courant, marqué d'une étoile.

Vous préférez nano ? Il convient aussi ; vérifiez simplement qu'il n'insère pas de tabulations.

## Étape 2 — Écrire un Pod à la main

**Pourquoi.** Tout objet Kubernetes s'écrit avec quatre blocs : `apiVersion` (la version de l'API qui le définit), `kind` (son type), `metadata` (son nom, ses labels) et `spec` (l'état voulu). Le taper une fois à la main ancre cette structure mieux que dix copier-coller.

Créez le fichier `01-pod.yaml` en le **tapant** (pas de copier-coller) :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: podinfo
  labels:
    app: podinfo
    version: "6.7.0"
spec:
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:6.7.0
      ports:
        - containerPort: 9898
```

**Champ par champ.**

- `apiVersion: v1` et `kind: Pod` : un Pod, défini dans le groupe de base de l'API.
- `metadata.name` : le nom, unique dans le namespace. `labels` : les étiquettes qui permettront de le sélectionner ; les guillemets autour de `"6.7.0"` en font une chaîne de caractères, sinon YAML lirait un nombre.
- `spec.containers` : une liste (chaque tiret ouvre un élément) de conteneurs, chacun avec un nom, une image et les ports qu'il expose.

> **Prédiction.** Votre fichier fait 13 lignes. Quels champs, absents de votre fichier, Kubernetes aura-t-il ajoutés quand vous afficherez le pod avec `-o yaml` ?

```bash
kubectl apply -f 01-pod.yaml
kubectl get pod podinfo -o wide            # notez l'IP du pod
kubectl describe pod podinfo               # lisez la section Events
kubectl logs podinfo
curl http://<IP-du-pod>:9898               # le nœud joint le pod directement
kubectl get pod podinfo -o yaml            # comparez spec et status
kubectl explain pod.spec.containers.ports
kubectl delete -f 01-pod.yaml
```

**Ligne par ligne.**

- `kubectl apply -f 01-pod.yaml` : envoie le manifeste à l'API server.
- `kubectl get pod podinfo -o wide` : son état, son IP et son nœud.
- `kubectl describe pod podinfo` : le détail, et surtout la section Events en bas : placement sur un nœud, téléchargement de l'image, démarrage.
- `kubectl logs podinfo` : ce que le programme écrit sur sa sortie standard.
- `curl http://<IP-du-pod>:9898` : depuis un nœud, on joint directement l'IP d'un pod ; c'est le réseau Calico qui achemine le paquet.
- `kubectl get pod podinfo -o yaml` : l'objet complet tel que le cluster le conserve ; comparez avec votre fichier.
- `kubectl explain pod.spec.containers.ports` : la documentation d'un champ, sans quitter le terminal.
- `kubectl delete -f 01-pod.yaml` : supprime l'objet décrit par le fichier.

## Étape 3 — Réparer des fichiers cassés

**Pourquoi.** Une grande part des incidents vient de fichiers YAML mal écrits. Savoir lire le message d'erreur et retrouver la ligne en cause fait gagner un temps considérable. `--dry-run=server` fait vérifier le fichier par l'API server, comme pour une vraie création, mais sans rien enregistrer.

Le dossier `~/tp/tp04` contient 4 fichiers, chacun avec **une seule** erreur. Pour chacun : testez, lisez le message, corrigez, retestez jusqu'à obtenir « created (server dry run) ». Les fichiers 1 et 2 sont pour tous, 3 et 4 pour les plus rapides.

```bash
kubectl apply --dry-run=server -f casse-1.yaml
vim casse-1.yaml                           # corrigez, puis relancez la commande précédente
```

**Ligne par ligne.**

- `kubectl apply --dry-run=server -f casse-1.yaml` : validation complète, sans effet. Le message indique souvent la ligne fautive (`line 11`) ou le champ inconnu.
- `vim casse-1.yaml` : corrigez, enregistrez et quittez (`:wq`), puis relancez la validation.

Notez vos trouvailles :

| Fichier | Message d'erreur (extrait) | Erreur trouvée |
| --- | --- | --- |
| `casse-1.yaml` |  |  |
| `casse-2.yaml` |  |  |
| `casse-3.yaml` |  |  |
| `casse-4.yaml` |  |  |

Astuce : `cat -A casse-1.yaml` affiche les tabulations sous la forme `^I`.

## À vous, sans pas-à-pas

Écrivez à la main `02-cache.yaml` : un Pod `cache` avec l'image `mirror.gcr.io/library/redis:7-alpine`, le label `app: cache` et le port 6379. Validez-le avec `--dry-run=server`, appliquez-le, vérifiez qu'il tourne, puis supprimez-le.

Indice : partez de la structure de `01-pod.yaml`.

## Point de contrôle

- [ ] Le contexte courant pointe sur le namespace `fil-rouge`.
- [ ] Votre Pod tapé à la main a démarré et répondu sur le port 9898.
- [ ] Les fichiers `casse-1.yaml` et `casse-2.yaml` corrigés passent `kubectl apply --dry-run=server`.

## Pour comprendre

1. Quelle différence entre `--dry-run=client` et `--dry-run=server` ?
2. Que contient la section `status` d'un objet, et qui l'écrit ?


---

[← TP3](../tp03/README.md) · [Sommaire](../README.md) · [Corrigé](corrige/README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP5 →](../tp05/README.md)
