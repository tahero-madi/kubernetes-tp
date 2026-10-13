# TP7 — Corrigé

Chasse aux pannes. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Les six pannes

Toutes les pannes partent du même Deployment podinfo, avec une seule modification.

| Panne | Symptôme (kubectl get pods) | Commande révélatrice | Cause | Correction |
| --- | --- | --- | --- | --- |
| 1 | `ErrImagePull` puis `ImagePullBackOff` | `kubectl describe pod` : `podinfo:6.99.99: not found` | Le tag d'image n'existe pas | Image `ghcr.io/stefanprodan/podinfo:6.7.0` |
| 2 | Pod `Running 1/1`, mais `wget http://panne-2:9898` échoue (connexion refusée) | `kubectl get endpointslices -l kubernetes.io/service-name=panne-2` : aucun endpoint | Le sélecteur du Service vise `app: panne2`, les pods portent `app: panne-2` | Sélecteur du Service : `app: panne-2` |
| 3 | `Pending` | `kubectl describe pod` : `FailedScheduling ... Insufficient cpu` | Le pod demande 8 CPU, aucun nœud n'en a autant | `requests.cpu: 100m` |
| 4 | `RunContainerError` puis `CrashLoopBackOff` | `kubectl describe pod` : `exec: "podinfoo": executable file not found in $PATH` | Faute de frappe dans la commande | Supprimer `command` ou écrire `./podinfo` |
| 5 | `CreateContainerConfigError` | `kubectl describe pod` : `configmap "config-absente" not found` | La ConfigMap référencée n'existe pas | Créer la ConfigMap ou retirer la référence |
| 6 | `Running` mais `0/1` READY | `kubectl describe pod` : `Readiness probe failed ... :9999 ... connection refused` | La probe interroge le port 9999 au lieu de 9898 | `port: 9898` dans la readinessProbe |

Correction rapide en séance : `kubectl edit deployment panne-N -n pannes`, ou corriger le fichier puis `kubectl apply -n pannes -f panne-N.yaml`.

## Prédictions et « À vous »

**À vous.** Libre. Pannes typiques : une image inexistante
(`kubectl set image deployment/podinfo podinfo=ghcr.io/stefanprodan/podinfo:9.9.9`, `ImagePullBackOff`), ou un mauvais
port de readiness posé avec `kubectl edit` (pods `0/1`). Réparation : `kubectl rollout undo deployment/podinfo`, puis `kubectl apply -f ~/tp/fil-rouge/30-podinfo.yaml`
pour revenir à l'état décrit.
