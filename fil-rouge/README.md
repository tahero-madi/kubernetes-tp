# Application fil rouge

Les manifestes de l'application podinfo + Redis, construite au [TP5](../tp05/README.md),
mise à jour au [TP6](../tp06/README.md) et rendue persistante au [TP12](../tp12/README.md).

| Fichier | Contenu |
| --- | --- |
| `10-redis.yaml` | Redis, le cache, et son Service |
| `20-config.yaml` | La ConfigMap de podinfo : message et couleur |
| `30-podinfo.yaml` | podinfo en 3 réplicas et son Service NodePort 30080 |

Le fichier `21-secret.yaml` n'est pas fourni : vous le générez au TP5 (version attendue : [`tp05/corrige/21-secret.yaml`](../tp05/corrige/21-secret.yaml)).
États attendus après chaque TP : [`tp06/corrige/30-podinfo.yaml`](../tp06/corrige/30-podinfo.yaml) et [`tp12/corrige/10-redis.yaml`](../tp12/corrige/10-redis.yaml).
