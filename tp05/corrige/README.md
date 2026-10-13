# TP5 — Corrigé

Application fil rouge podinfo + Redis. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Comment podinfo trouve-t-il Redis, alors que l'adresse IP du pod Redis change à chaque redémarrage ?**

Par le nom DNS du Service `redis` (`redis.fil-rouge.svc.cluster.local`, raccourci en `redis` dans le même namespace) ; CoreDNS le traduit en ClusterIP, et kube-proxy renvoie le trafic vers le pod Redis.

**2. À l'étape Bonus, pourquoi la modification de la ConfigMap reste-t-elle invisible jusqu'au redémarrage ?**

Les variables d'environnement ne sont lues qu'au démarrage du conteneur ; il faut redémarrer les pods (`kubectl rollout restart deployment podinfo`).

## Prédictions et « À vous »

**Prédiction (étape 1).** Par le Service `redis` : un nom DNS stable, une ClusterIP stable, et une EndpointSlice que
Kubernetes tient à jour quand le pod change.

**Prédiction (sélecteur `app: redis2`).** L'EndpointSlice se vide : le Service ne mène plus nulle part et podinfo
perd son cache, alors que le pod Redis tourne toujours.

**Prédiction (étape 3).** Par tous les nœuds, `k8s-cp` compris : kube-proxy ouvre le NodePort sur chaque nœud.

**À vous.**
```bash
kubectl expose deployment podinfo --name=podinfo-interne --port=80 --target-port=9898
kubectl run t --image=mirror.gcr.io/library/busybox:1.36 --rm -it --restart=Never -- wget -qO- http://podinfo-interne
kubectl delete service podinfo-interne
```

## Fichiers corrigés

| Fichier | Contenu |
| --- | --- |
| [`21-secret.yaml`](21-secret.yaml) | Le Secret attendu ; la commande qui le génère est en tête du fichier |
