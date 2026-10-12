# TP9 — Helm, cert-manager, k9s

**Jour 3, 10:25 · 30 min, guidé par le formateur.** Objectif : reconnaître un opérateur, installer un logiciel avec Helm et voir un contrôleur réconcilier un objet que vous avez créé. Support : sections 13.1 à 13.5.

## Étape 1 — Vous utilisez déjà un opérateur

**Pourquoi.** Un opérateur est un programme qui tourne dans le cluster et pilote un logiciel à partir d'objets que vous déclarez. Vous en utilisez un depuis le TP2 : l'opérateur Tigera, qui gère Calico à partir de l'objet `Installation`.

```bash
kubectl get crd | grep -c tigera                 # les types ajoutés par l'opérateur de Calico
kubectl get installation default -o yaml | head -40
kubectl get tigerastatus
```

**Ligne par ligne.**

- `kubectl get crd | grep -c tigera` : `get crd` liste les types d'objets ajoutés à l'API ; `grep -c` compte ceux de Tigera.
- `kubectl get installation default -o yaml | head -40` : l'objet que vous avez créé au TP2, complété par l'opérateur ; `head -40` n'en affiche que le début.
- `kubectl get tigerastatus` : l'état de chaque composant de Calico, tel que l'opérateur le rapporte.

## Étape 2 — Installer Helm

**Pourquoi.** Helm est le gestionnaire de paquets de Kubernetes : un chart regroupe tous les manifestes d'un logiciel, avec des paramètres. On installe ici une version précise, pour que tous les postes soient identiques.

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash -s -- --version v3.22.0
helm version                                     # v3.22.0
```

**Ligne par ligne.** `curl -fsSL …/get-helm-3 | bash -s -- --version v3.22.0` télécharge le script officiel d'installation et l'exécute ; `-s --` permet de lui passer des arguments, ici la version. `helm version` contrôle le résultat.

## Étape 3 — Installer cert-manager avec Helm

**Pourquoi.** cert-manager est l'opérateur qui gère les certificats TLS dans un cluster : il les crée, les renouvelle avant expiration et les range dans des Secrets. On l'installe par Helm, en une commande.

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm install cert-manager jetstack/cert-manager --version v1.21.2 --namespace cert-manager --create-namespace --set crds.enabled=true --wait
# la commande rend la main quand cert-manager et son webhook sont prêts (1 à 2 min)
kubectl get pods -n cert-manager                 # 3 pods Running
kubectl api-resources --api-group=cert-manager.io
helm list -A
```

**Ligne par ligne.**

- `helm repo add jetstack https://charts.jetstack.io --force-update` : déclare le dépôt de charts de l'éditeur sous le nom `jetstack`.
- `helm install cert-manager jetstack/cert-manager` : installe le chart `cert-manager` du dépôt `jetstack` ; le premier `cert-manager` est le nom donné à cette installation, la release.
- `--version v1.21.2` : version figée. `--namespace cert-manager --create-namespace` : dans son propre namespace, créé au besoin. `--set crds.enabled=true` : installe aussi ses types d'objets. `--wait` : ne rend la main que lorsque tout est prêt.
- `kubectl api-resources --api-group=cert-manager.io` : les nouveaux types, dont Certificate et ClusterIssuer.
- `helm list -A` : les releases installées, dans tous les namespaces.

## Étape 4 — Un certificat géré par un contrôleur

**Pourquoi.** Vous déclarez ce que vous voulez, un certificat pour podinfo, et le contrôleur de cert-manager se charge de le produire puis de le maintenir : c'est la boucle de réconciliation de Kubernetes, appliquée à un logiciel tiers.

> **Prédiction.** À la fin de ce bloc, vous supprimez le Secret du certificat. Qui pourrait le recréer, et en combien de temps ?

```bash
cat ~/tp/tp09/60-certificat.yaml                 # une autorité auto-signée et un certificat
kubectl apply -f ~/tp/tp09/60-certificat.yaml
kubectl wait --for=condition=Ready certificate/podinfo-tls -n fil-rouge --timeout=60s
kubectl get certificate -n fil-rouge             # READY True
kubectl get secret podinfo-tls -n fil-rouge      # type kubernetes.io/tls
kubectl delete secret podinfo-tls -n fil-rouge
kubectl get secret podinfo-tls -n fil-rouge -w   # il réapparaît en quelques secondes ; Ctrl+C
```

**Ligne par ligne.**

- `cat ~/tp/tp09/60-certificat.yaml` : un `ClusterIssuer` auto-signé nommé `autosigne` (une autorité de test) et un `Certificate` qui lui demande un certificat pour podinfo, à ranger dans le Secret `podinfo-tls`.
- `kubectl wait --for=condition=Ready certificate/podinfo-tls … --timeout=60s` : attend que le certificat soit émis.
- `kubectl get certificate` et `kubectl get secret podinfo-tls` : le certificat est prêt ; le Secret, de type `kubernetes.io/tls`, contient la clé et le certificat.
- `kubectl delete secret podinfo-tls` puis `kubectl get secret podinfo-tls -w` : vous effacez le résultat ; le contrôleur constate l'écart avec ce que demande le Certificate et le recrée.

## Étape 5 — k9s, le tableau de bord dans le terminal

**Pourquoi.** La console web ne donne pas de navigateur vers les VM : votre interface d'administration sera k9s, qui s'affiche dans le terminal. Il montre en direct ce que vous obtenez avec kubectl et permet d'agir au clavier. Comme kubectl, il lit `~/.kube/config` et agit donc avec vos droits.

```bash
curl -fsSL https://github.com/derailed/k9s/releases/download/v0.51.0/k9s_Linux_amd64.tar.gz | tar xz -C /tmp k9s
sudo install /tmp/k9s /usr/local/bin/k9s
k9s version
k9s -n fil-rouge          # quitter : taper :q puis Entrée
```

**Ligne par ligne.**

- `curl … | tar xz -C /tmp k9s` : télécharge l'archive de k9s et n'en extrait que le programme, dans `/tmp`.
- `sudo install /tmp/k9s /usr/local/bin/k9s` : le copie dans un dossier où le shell cherche les commandes, avec les droits d'exécution.
- `k9s -n fil-rouge` : lance l'interface, ouverte sur le namespace `fil-rouge`.

| Touche | Action |
| --- | --- |
| `:pod`, `:deploy`, `:svc`, `:cert` puis Entrée | Changer de type d'objet |
| `0` | Tous les namespaces |
| `/` | Filtrer la liste |
| Entrée, Échap | Entrer dans un objet, revenir |
| `d`, `y`, `l` | describe, YAML, logs |
| `s` | Changer le nombre de réplicas (sur un Deployment) |
| Ctrl+D | Supprimer, avec confirmation |
| `?` | Aide |

À vous, dans k9s : affichez les logs d'un pod podinfo, retrouvez le Certificate `podinfo-tls`, passez le Deployment podinfo à 4 réplicas puis revenez à 3. Headlamp, l'interface web présentée en cours (section 3.6), s'installe elle aussi par Helm ; le formateur peut la montrer en démonstration.

## Point de contrôle

- [ ] cert-manager tourne et `helm list -A` l'affiche.
- [ ] Le Certificate `podinfo-tls` est `READY True`.
- [ ] Son Secret a réapparu après suppression.

## Pour comprendre

1. Qui a recréé le Secret `podinfo-tls`, et à partir de quoi ?
2. Quelle différence de fonctionnement entre une installation Helm et un opérateur ?


---

[← TP8](../tp08/README.md) · [Sommaire](../README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP10 →](../tp10/README.md)
