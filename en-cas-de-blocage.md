# En cas de blocage

Commencez toujours par la méthode du module 10 : `kubectl get`, puis `kubectl describe` (section Events en bas), puis `kubectl logs --previous`, puis `kubectl events`. Les tableaux ci-dessous réunissent les causes les plus fréquentes dans ces TP.

## Installation du cluster (TP1 à TP3)

| Symptôme | Cause probable | Remède |
| --- | --- | --- |
| `kubeadm init` s'arrête sur `[ERROR Swap]` ou `ip_forward` | Une étape du TP1 a été sautée | Refaire les étapes 2 et 3 du TP1, puis relancer `kubeadm init` |
| `kubeadm init` attend puis échoue : `the kubelet is not healthy` | `SystemdCgroup = false` dans la configuration de containerd | `grep SystemdCgroup /etc/containerd/config.toml`, corriger, `sudo systemctl restart containerd`, `sudo kubeadm reset -f`, relancer `kubeadm init` |
| `kubeadm init` relancé : `port 6443 is in use` ou `already exists` | Restes d'une première tentative | `sudo kubeadm reset -f`, puis relancer |
| `kubectl` : `connection to the server localhost:8080 was refused` | Le fichier kubeconfig n'est pas en place, ou vous êtes sur un worker | Recopier `admin.conf` dans `~/.kube/config` (TP2) ; travailler sur k8s-cp |
| `crictl` : commande introuvable | Paquet `cri-tools` absent : kubeadm ne l'installe plus automatiquement | `sudo apt-get install -y cri-tools`, puis l'étape 5 du TP1 à partir de `crictl config` |
| `crictl` affiche des avertissements de connexion | crictl ne connaît pas le socket de containerd | `sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock` |
| Les nœuds restent `NotReady`, CoreDNS reste `Pending` | Calico n'est pas prêt | `kubectl get tigerastatus` ; `kubectl get pods -n calico-system` ; attendre ou appeler le formateur |
| `kubeadm join` : jeton invalide ou expiré | Le jeton vit 24 heures | Sur k8s-cp : `sudo kubeadm token create --print-join-command` |
| Un worker n'apparaît pas, ou sous le nom k8s-cp | Nom d'hôte non changé sur le worker | `hostnamectl` sur le worker, puis « Repartir de zéro sur un worker » ci-dessous |

## Pods et Services (TP3 à TP7)

| Symptôme | Cause probable | Remède |
| --- | --- | --- |
| `ErrImagePull`, `ImagePullBackOff` | Nom ou tag d'image faux, registre injoignable | `kubectl describe pod` : lire le message ; corriger l'image |
| `CrashLoopBackOff` | Le programme s'arrête dès son démarrage | `kubectl logs <pod> --previous` |
| `CreateContainerConfigError` | ConfigMap ou Secret référencé absent | `kubectl get configmap,secret` dans le bon namespace |
| `Pending` | Pas assez de CPU ou de mémoire, taint, PVC non lié | `kubectl describe pod` : le message `FailedScheduling` donne la raison |
| `Running` mais `0/1` dans READY | La readinessProbe échoue | `kubectl describe pod` : chemin et port de la probe |
| Le Service ne répond pas | Sélecteur du Service différent des labels des pods | `kubectl get endpointslices -l kubernetes.io/service-name=<service>` : aucune adresse = sélecteur faux |
| `kubectl apply` : `found character that cannot start any token` | Une tabulation dans le YAML | Remplacer les tabulations par des espaces (section 6.9) |
| `kubectl apply` : `unknown field` | Faute de frappe ou mauvais niveau d'indentation | `kubectl explain <type>.<champ>` |
| Les objets semblent avoir disparu | Vous regardez un autre namespace | Ajouter `-n fil-rouge`, ou `kubectl config set-context --current --namespace=fil-rouge` |

## Ressources, sécurité et outils (TP8 à TP12)

| Symptôme | Cause probable | Remède |
| --- | --- | --- |
| `exceeded quota` ou `must specify requests` | Quota du namespace atteint, ou requests absentes | `kubectl describe quota -n equipe-a` |
| `violates PodSecurity "restricted"` | Le pod ne déclare pas le securityContext exigé | Partir de `~/tp/tp11/80-pod-securise.yaml` |
| `kubectl top` : `Metrics API not available` | metrics-server pas encore prêt | `kubectl get pods -n kube-system` ; attendre une minute |
| HPA : `<unknown>` dans TARGETS | Pas de mesure encore, ou pas de `requests.cpu` | Attendre une minute ; vérifier les requests du Deployment |
| `helm install` : `cannot re-use a name that is still in use` | La release existe déjà | `helm list -A` ; `helm upgrade --install` |
| Certificate reste `READY False` | cert-manager démarre encore | `kubectl get pods -n cert-manager` ; `kubectl describe certificate -n fil-rouge` |
| Plus rien ne répond sur le port 30080 | NetworkPolicy de refus sans les autorisations | `kubectl get networkpolicy -n fil-rouge` ; appliquer `91-netpol-autorisations.yaml` |
| `spec.strategy.rollingUpdate: Forbidden` | Passage à la stratégie Recreate par un simple apply | Supprimer le Deployment, puis l'appliquer à nouveau (TP12) |
| Pod Redis `Pending` : `volume node affinity conflict` | k8s-w1 est vidé (drain) ou arrêté | `kubectl uncordon k8s-w1` |

## Repartir de zéro sur un worker

Si un worker est irrécupérable, retirez-le du cluster puis faites-le rejoindre (exemple avec k8s-w2).

```bash
# [cp]
kubectl drain k8s-w2 --ignore-daemonsets --delete-emptydir-data
kubectl delete node k8s-w2
sudo kubeadm token create --print-join-command   # copiez la commande affichée
```

```bash
# [w2]
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo <commande kubeadm join copiée>
```

## Remettre le fil rouge en place

Les fichiers de `~/tp/fil-rouge` contiennent toutes vos modifications : appliquez-les à nouveau.

```bash
kubectl create namespace fil-rouge                  # AlreadyExists : sans gravité
kubectl apply -f ~/tp/tp12/95-stockage.yaml          # seulement si le TP12 est commencé
kubectl apply -f ~/tp/fil-rouge/
kubectl apply -f ~/tp/tp11/90-netpol-refus.yaml -f ~/tp/tp11/91-netpol-autorisations.yaml   # seulement après le TP11
kubectl get pods -n fil-rouge
```

Si votre cluster ne peut pas être réparé à temps, le formateur vous donne accès à un cluster de secours pour continuer le TP en cours.


---

[Sommaire](README.md)
