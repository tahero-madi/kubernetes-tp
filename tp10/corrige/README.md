# TP10 — Corrigé

HPA sous charge. [Retour à l'énoncé](../README.md)

> Cherchez d'abord par vous-même : ce corrigé sert à vous débloquer, ou à vérifier votre travail à la fin du TP.

## Pour comprendre

**1. Pourquoi l'HPA affiche-t-il `<unknown>` au début ?**

metrics-server n'a pas encore collecté de mesures pour les nouveaux pods (environ une minute) ; sans request CPU, l'affichage resterait `<unknown>`.

**2. Pourquoi la redescente est-elle plus lente que la montée ?**

Par défaut, l'HPA attend 5 minutes de stabilisation avant de retirer des pods, pour ne pas réagir à une accalmie passagère ; la montée, elle, est immédiate.

## Prédictions et « À vous »

**Prédiction.** Plusieurs réplicas, souvent 4 à 7, jamais plus de 8 : l'HPA calcule
réplicas = arrondi supérieur (réplicas actuels × utilisation mesurée / 50 %) et se stabilise quand l'utilisation
moyenne revient près de 50 %.

**À vous.**
```bash
kubectl get hpa php-apache -n charge -o yaml | grep -E 'averageUtilization|minReplicas|maxReplicas'
kubectl get deployment php-apache -n charge -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}'   # 200m
```
