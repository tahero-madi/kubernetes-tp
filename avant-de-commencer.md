# Avant de commencer

## Vos nœuds

Notez ici les adresses IP privées fournies par le formateur. Dans tout le cahier, les exemples utilisent 10.10.0.10, 10.10.0.20 et 10.10.0.30 : **remplacez-les par les vôtres**.

| Nœud | Rôle | Votre IP privée | Exemple du cahier |
| --- | --- | --- | --- |
| `k8s-cp` | Control plane, poste d'administration (`kubectl`) |  | 10.10.0.10 |
| `k8s-w1` | Worker |  | 10.10.0.20 |
| `k8s-w2` | Worker |  | 10.10.0.30 |

## L'archive des TP

Tous les fichiers des TP sont dans une archive que le formateur met à votre disposition. Récupérez-la sur `k8s-cp` au début du TP1, dans le dossier `~/tp` :

```bash
# [cp] avec l'adresse donnée par le formateur
sudo apt-get update -q && sudo apt-get install -y git unzip tmux   # outils de la formation, souvent déjà présents
git clone https://github.com/VOTRE-COMPTE/kubernetes-tp.git ~/tp
# ou, si l'archive vous est remise en fichier zip :
unzip kubernetes-tp.zip && mv kubernetes-tp ~/tp
ls ~/tp                     # un dossier par TP, plus fil-rouge/
```

**Ligne par ligne.**

- `sudo apt-get update -q && sudo apt-get install -y git unzip tmux` : met à jour la liste des paquets, puis installe les trois outils de la formation s'ils manquent.
- `git clone https://github.com/VOTRE-COMPTE/kubernetes-tp.git ~/tp` : copie le dépôt des TP dans le dossier `tp` de votre répertoire personnel (`~`).
- `unzip kubernetes-tp.zip && mv kubernetes-tp ~/tp` : la variante si l'archive vous est remise en fichier zip.
- `ls ~/tp` : vérifie le contenu.

| Dossier | Utilisé au |
| --- | --- |
| `tp01/` | TP1 : script de préparation des workers |
| `tp02/` | TP2 : configuration de Calico |
| `tp04/` | TP4 : quatre fichiers YAML cassés |
| `fil-rouge/` | TP5, puis TP6 et TP12 : l'application podinfo + Redis |
| `tp06/` à `tp13/` | TP du même numéro |

## Conventions

- Un bloc de commandes commence par le nœud où l'exécuter : `[cp]` pour `k8s-cp`, `[w1]` et `[w2]` pour les workers. Sans indication, c'est `k8s-cp`, où `kubectl` est configuré.
- Ce qui suit `#` en fin de ligne est un commentaire : il décrit le résultat attendu. Ne le tapez pas.
- `<PID>`, `<pod>` ou `<IP-worker>` sont à remplacer par une valeur que vous lisez dans la sortie de la commande précédente.
- Les étapes **Bonus** sont pour celles et ceux qui ont terminé en avance.

Chaque étape suit le même déroulé. Le paragraphe **Pourquoi** dit ce que l'on cherche à obtenir et la notion en jeu : lisez-le avant de taper. Les encadrés **Prédiction** vous demandent d'écrire ce que vous attendez avant de lancer la commande : c'est l'écart entre votre prédiction et le résultat qui fait apprendre. Après chaque bloc, **Ligne par ligne** explique chaque commande, ses options et ce qu'il faut regarder dans la sortie : ne passez pas à la suite sans savoir ce que vient de faire la commande. Enfin, les sections **À vous** se font sans pas-à-pas, avec un indice : elles montrent que vous savez refaire seul.

## Accès par la console web

Vous travaillez dans une console web qui ouvre une session SSH vers vos VM. Trois conséquences :

- Pas de navigateur vers les VM : tous les tests HTTP se font avec `curl` depuis `k8s-cp`, et l'outil d'administration du TP9 est k9s, qui s'affiche dans le terminal.
- Le copier-coller passe par le presse-papiers de la console : le formateur vous montre la manipulation au début du TP1.
- Quand un TP demande un **second terminal**, ouvrez une deuxième connexion vers `k8s-cp`, ou utilisez `tmux`. Si la console se déconnecte, `tmux attach` retrouve vos panneaux.

| Action | tmux |
| --- | --- |
| Démarrer | `tmux` |
| Couper l'écran côte à côte | Ctrl+B puis `%` |
| Couper l'écran en haut et en bas | Ctrl+B puis `"` |
| Passer d'un panneau à l'autre | Ctrl+B puis une flèche |
| Fermer un panneau | `exit` |

## Si vous êtes bloqué

1. Relisez la sortie de la dernière commande : l'erreur y est souvent écrite.
2. Appliquez la méthode du module 10 : `kubectl get`, puis `kubectl describe` (section Events en bas), puis `kubectl logs --previous`, puis `kubectl events`.
3. Consultez [En cas de blocage](en-cas-de-blocage.md).
4. Demandez à votre binôme, puis au formateur.

Chaque TP se termine par un **point de contrôle** : cochez les cases au fur et à mesure. Le TP suivant repose sur ce qu'il vérifie.


---

[Sommaire](README.md) · [TP1 →](tp01/README.md)
