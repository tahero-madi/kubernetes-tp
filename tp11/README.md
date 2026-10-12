# TP11 — Sécuriser le fil rouge

**Jour 3, 13:20 · 50 min.** Objectif : limiter qui peut faire quoi (RBAC), ce que les pods ont le droit de faire (Pod Security) et qui parle à qui (NetworkPolicies), puis créer un utilisateur humain. Support : sections 15.2 à 15.7.

## Étape 1 — RBAC : un compte en lecture seule

**Pourquoi.** RBAC (contrôle d'accès par rôles) répond à la question « qui peut faire quoi ». Un Role liste des actions permises sur des types d'objets dans un namespace ; un RoleBinding attribue ce rôle à une identité. Tout ce qui n'est pas permis est refusé. Ici, l'identité est un ServiceAccount, le compte d'un programme.

```bash
kubectl create serviceaccount lecteur -n fil-rouge
kubectl create role lecture -n fil-rouge --verb=get,list,watch --resource=pods,services,deployments
kubectl create rolebinding lecteur-lecture -n fil-rouge --role=lecture --serviceaccount=fil-rouge:lecteur
kubectl auth can-i list pods -n fil-rouge --as=system:serviceaccount:fil-rouge:lecteur      # yes
kubectl auth can-i delete pods -n fil-rouge --as=system:serviceaccount:fil-rouge:lecteur    # no
kubectl auth can-i get secrets -n fil-rouge --as=system:serviceaccount:fil-rouge:lecteur    # no
```

**Ligne par ligne.**

- `kubectl create serviceaccount lecteur -n fil-rouge` : crée l'identité.
- `kubectl create role lecture --verb=get,list,watch --resource=pods,services,deployments` : un rôle en lecture seule (lire un objet, lister, suivre les changements) sur trois types d'objets.
- `kubectl create rolebinding lecteur-lecture --role=lecture --serviceaccount=fil-rouge:lecteur` : lie le rôle au compte, désigné sous la forme `namespace:nom`.
- `kubectl auth can-i … --as=system:serviceaccount:fil-rouge:lecteur` : demande à l'API server si cette identité a le droit ; `--as` emprunte l'identité pour le test, sans avoir besoin de son jeton.

## Étape 2 — Pod Security : le niveau restricted

**Pourquoi.** Pod Security limite ce qu'un pod a le droit de faire sur le nœud : tourner en root, devenir privilégié, monter des dossiers de la machine. Le niveau `restricted` impose les bonnes pratiques ; on l'active par un simple label sur le namespace.

```bash
kubectl label namespace equipe-a pod-security.kubernetes.io/enforce=restricted
kubectl run test-root -n equipe-a --image=mirror.gcr.io/library/nginx:1.27   # refusé : lisez la liste des violations
cat ~/tp/tp11/80-pod-securise.yaml                                          # ce qui le rend conforme
kubectl apply -f ~/tp/tp11/80-pod-securise.yaml
kubectl get pod podinfo-securise -n equipe-a                                # Running
```

**Ligne par ligne.**

- `kubectl label namespace equipe-a pod-security.kubernetes.io/enforce=restricted` : refuse désormais tout pod non conforme dans ce namespace.
- `kubectl run test-root … nginx:1.27` : l'image nginx s'exécute en root : la création est refusée, et le message liste chaque règle violée.
- `cat ~/tp/tp11/80-pod-securise.yaml` : `runAsNonRoot` et `runAsUser: 10001` (pas de root), `seccompProfile: RuntimeDefault` (appels système filtrés), `allowPrivilegeEscalation: false` et `capabilities.drop: ["ALL"]` (aucun privilège supplémentaire).
- `kubectl apply` puis `kubectl get pod podinfo-securise -n equipe-a` : ce pod-là est accepté et tourne.

## Étape 3 — NetworkPolicies : isoler Redis

**Pourquoi.** Par défaut, tout pod peut joindre tout autre pod du cluster. Une NetworkPolicy sélectionne des pods et liste le trafic qu'ils acceptent ; dès qu'un pod est sélectionné par une policy, tout le reste lui est refusé. La méthode sûre consiste à tout fermer, puis à rouvrir seulement les flux nécessaires.

D'abord, constatez que n'importe quel pod joint Redis :

```bash
kubectl run intrus -n fil-rouge --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- sh -c 'echo PING | nc -w 3 redis 6379 && echo OUVERT || echo BLOQUÉ'
# +PONG puis OUVERT
```

**Ligne par ligne.** Le pod `intrus` tente une connexion à Redis avec `nc` ; `&&` affiche OUVERT si elle réussit, `||` affiche BLOQUÉ sinon.

Puis fermez tout le trafic entrant du namespace :

> **Prédiction.** Avec cette seule policy, un pod client joindra-t-il encore podinfo ? Et podinfo pourra-t-il encore joindre Redis ?

```bash
kubectl apply -f ~/tp/tp11/90-netpol-refus.yaml
kubectl run client -n fil-rouge --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- wget -qO- -T 3 http://podinfo:9898
# wget: download timed out : plus aucun pod ne joint podinfo
# on teste depuis un pod : un pod ne peut pas bloquer le trafic de son propre nœud, et le NodePort passe par un nœud
```

**Ligne par ligne.** Dans `90-netpol-refus.yaml`, `podSelector: {}` sélectionne tous les pods du namespace et `policyTypes: [Ingress]` sans aucune règle n'autorise rien en entrée. Le pod `client` ne joint plus podinfo : `wget` abandonne au bout de 3 secondes (`-T 3`).

Rouvrez seulement les flux nécessaires, puis refaites les deux tests :

```bash
cat ~/tp/tp11/91-netpol-autorisations.yaml
kubectl apply -f ~/tp/tp11/91-netpol-autorisations.yaml
kubectl run client -n fil-rouge --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- wget -qO- -T 3 http://podinfo:9898   # podinfo répond de nouveau
curl http://k8s-w1:30080/cache/test              # podinfo répond et lit Redis
kubectl run intrus -n fil-rouge --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- sh -c 'echo PING | nc -w 3 redis 6379 && echo OUVERT || echo BLOQUÉ'
# BLOQUÉ : seul podinfo joint Redis
```

**Ligne par ligne.**

- `cat ~/tp/tp11/91-netpol-autorisations.yaml` : deux policies : tout le monde peut joindre les pods `app: podinfo` sur le port 9898 ; seuls les pods `app: podinfo` peuvent joindre les pods `app: redis` sur le port 6379.
- les tests suivants : podinfo répond de nouveau, par un pod comme par le NodePort, et lit Redis ; l'intrus, qui ne porte pas le label `app: podinfo`, reste bloqué.

## Étape 4 — Un utilisateur humain authentifié par certificat

**Pourquoi.** Kubernetes ne gère pas de comptes d'utilisateurs : alice existe parce qu'un certificat signé par l'autorité du cluster porte son nom. Vous allez fabriquer cette identité, puis lui donner des droits, en distinguant les deux étapes : l'authentification (qui êtes-vous ?) et l'autorisation (que pouvez-vous faire ?). Étape prioritaire pour l'équipe Secrets, bonus pour les autres.

```bash
openssl genrsa -out alice.key 2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice/O=equipe-diffusion"
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: alice
spec:
  request: $(base64 -w0 < alice.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["client auth"]
EOF
kubectl certificate approve alice
kubectl get csr alice -o jsonpath='{.status.certificate}' | base64 -d > alice.crt
kubectl config set-cluster formation --server=https://10.10.0.10:6443 --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true --kubeconfig=alice.kubeconfig
kubectl config set-credentials alice --client-certificate=alice.crt --client-key=alice.key --embed-certs=true --kubeconfig=alice.kubeconfig
kubectl config set-context alice --cluster=formation --user=alice --namespace=fil-rouge --kubeconfig=alice.kubeconfig
kubectl config use-context alice --kubeconfig=alice.kubeconfig
kubectl --kubeconfig=alice.kubeconfig get pods            # Forbidden : authentifiée, mais aucun droit
kubectl create rolebinding equipe-diffusion-view -n fil-rouge --clusterrole=view --group=equipe-diffusion
kubectl --kubeconfig=alice.kubeconfig get pods            # autorisé
kubectl --kubeconfig=alice.kubeconfig get secrets         # Forbidden : le rôle view exclut les Secrets
kubectl --kubeconfig=alice.kubeconfig delete pod --all    # Forbidden
```

**Ligne par ligne.**

- `openssl genrsa -out alice.key 2048` : crée la clé privée d'alice, qui ne doit jamais quitter son poste.
- `openssl req -new … -subj "/CN=alice/O=equipe-diffusion"` : prépare une demande de certificat ; pour Kubernetes, CN devient le nom d'utilisateur et O son groupe.
- l'objet `CertificateSigningRequest` : soumet cette demande au cluster, encodée en base64. `signerName: kubernetes.io/kube-apiserver-client` demande un certificat client pour l'API server ; `expirationSeconds: 86400` le limite à 24 heures.
- `kubectl certificate approve alice` : l'administrateur approuve, le cluster signe.
- `kubectl get csr alice -o jsonpath='{.status.certificate}' | base64 -d > alice.crt` : récupère le certificat signé et le décode.
- les trois `kubectl config set-…` puis `use-context` : construisent un kubeconfig dédié à alice : le cluster (adresse et autorité), l'utilisateur (certificat et clé) et le contexte qui les associe.
- premier `get pods` : `Forbidden`. alice est authentifiée (on sait qui elle est) mais n'a encore aucune autorisation.
- `kubectl create rolebinding equipe-diffusion-view --clusterrole=view --group=equipe-diffusion` : donne le rôle prédéfini `view` au groupe d'alice ; tout futur membre du groupe en héritera.
- derniers tests : lecture permise ; Secrets et suppression refusés.

## À vous, sans pas-à-pas

Autorisez le compte `lecteur` à lire aussi les ConfigMaps du namespace, mais toujours pas les Secrets. Prouvez-le avec `kubectl auth can-i`.

Indice : c'est le Role `lecture` qu'il faut modifier, pas le RoleBinding.

## Point de contrôle

- [ ] Le compte `lecteur` lit les pods mais ne peut ni supprimer ni lire les Secrets.
- [ ] `podinfo-securise` tourne dans `equipe-a` ; le pod nginx standard y est refusé.
- [ ] L'application répond sur le port 30080, mais un pod intrus ne joint plus Redis.

## Pour comprendre

1. Pourquoi `lecteur` ne peut-il pas lire les Secrets, alors qu'aucune règle ne l'interdit ?
2. Après la seule policy `refus-par-defaut`, pourquoi le pod `client` ne joignait-il plus podinfo ? Et pourquoi tester depuis un pod plutôt que par le NodePort ?

## Bonus avec le formateur

Chiffrer les Secrets dans etcd (section 8.4 du support) : une manipulation du manifeste de l'API server, à faire accompagné.


---

[← TP10](../tp10/README.md) · [Sommaire](../README.md) · [En cas de blocage](../en-cas-de-blocage.md) · [TP12 →](../tp12/README.md)
