# DATASCIENTEST JENKINS EXAM
# python-microservice-fastapi
Learn to build your own microservice using Python and FastAPI

## How to run??
 - Make sure you have installed `docker` and `docker-compose`
 - Run `docker-compose up -d`
 - Head over to http://localhost:8080/api/v1/movies/docs for movie service docs 
   and http://localhost:8080/api/v1/casts/docs for cast service docs

## Kubernetes — environnements (namespaces)

Quatre environnements sont modélisés par des **Namespaces** : `dev`, `qa`, `staging`, `prod` (voir `kubernetes/namespaces.yaml`).

### Installer / accéder au cluster

- **k3s** (Linux) : `curl -sfL https://get.k3s.io | sh -` puis, pour utiliser `kubectl` en utilisateur non root, copier le kubeconfig : `sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && sudo chown "$USER:$USER" ~/.kube/config` (ou ajouter l’utilisateur au groupe configuré par k3s).
- **Minikube** : `minikube start`
- **kind** : `kind create cluster`

### Créer les namespaces

```bash
./scripts/apply-namespaces.sh
# ou : kubectl apply -f kubernetes/namespaces.yaml
```

Vérification : `kubectl get ns -l app.kubernetes.io/part-of=movie-microservices`

### Déployer le chart Helm par environnement

Les fichiers `charts/values-<env>.yaml` fixent des **NodePorts distincts** (obligatoire : un NodePort est unique sur tout le cluster).

```bash
helm install fastapi-dev ./charts -n dev -f charts/values-dev.yaml
helm install fastapi-qa ./charts -n qa -f charts/values-qa.yaml
helm install fastapi-staging ./charts -n staging -f charts/values-staging.yaml
helm install fastapi-prod ./charts -n prod -f charts/values-prod.yaml
```

Prérequis image : adapter `values.yaml` / secrets (`regcred`) selon votre registry.

## Jenkins (`Jenkinsfile`)

Pipeline déclarative sur le modèle *datascientest-jenkins* : build des images `movie-service` et `cast-service`, tests via Docker Compose (`docker-compose.jenkins.yml`), push Docker Hub, application des namespaces, déploiements Helm vers **dev → qa → staging → prod**. Le déploiement **prod** est **manuel** (`input`) et **n’est proposé que sur la branche `master`** (les autres branches sautent ce stage).

### Mettre en œuvre l’automatisation complète avec Jenkins

1. **Installer Jenkins** sur une machine Linux (paquets officiels ou image Docker « jenkins/jenkins »). Plugins utiles : **Pipeline**, **Git**, **Credentials Binding**, **Email Extension** (si vous utilisez le mail d’échec dans le `Jenkinsfile`).

2. **Sur l’agent qui exécute le pipeline** (`agent any`) : **Docker** + `docker compose`, **kubectl**, **Helm**, **curl**. L’utilisateur qui lance les builds doit pouvoir parler au démon Docker (groupe `docker` ou socket monté si Jenkins est en conteneur).

3. **Credentials Jenkins** (*Manage Jenkins → Credentials*) — les **IDs sont imposés par le `Jenkinsfile`** :
   - **`DOCKER_HUB_PASS`** (*Secret text*) : token ou mot de passe Docker Hub.
   - **`config`** (*Secret file*) : fichier **kubeconfig** du cluster cible.

4. **Créer le job** : *New Item* → **Pipeline** → *Pipeline script from SCM* → Git : URL du dépôt, branche (ex. `*/master`), **Script Path** : `Jenkinsfile` → sauver → **Build Now**.

5. **Adapter le `Jenkinsfile`** : **`DOCKER_ID`** = votre utilisateur Docker Hub ; **`post { failure { mail ... } }`** : email et SMTP Jenkins si besoin.

6. **Kubernetes** : si les pulls d’images sont privés, créer **`regcred`** dans chaque namespace (`kubectl create secret docker-registry regcred ...`), comme attendu par `charts/values.yaml`.

7. **Webhook (optionnel)** : GitHub/GitLab → webhook vers Jenkins pour lancer un build à chaque push.

8. **Port 8080** : les tests utilisent `localhost:8080` (nginx Compose). Si Jenkins utilise aussi le port **8080** sur la même machine, changez le port de Jenkins ou celui de nginx dans Compose pour éviter le conflit.

Configurer les identifiants **`DOCKER_HUB_PASS`** et **`config`**, puis vérifier **`DOCKER_ID`** dans le `Jenkinsfile`.
