pipeline {
  environment {
    DOCKER_ID = "edouardaugustinribes"
    DOCKER_REPOSITORY = "examdevopsjenkins"
    DOCKER_TAG = "v.${BUILD_ID}.0"
  }
  agent any
  stages {
    stage('Docker Build') {
      steps {
        script {
          sh '''
            docker compose -f docker-compose.yml down --remove-orphans 2>/dev/null || true
            docker build -t ${DOCKER_ID}/${DOCKER_REPOSITORY}:movie-${DOCKER_TAG} ./movie-service
            docker build -t ${DOCKER_ID}/${DOCKER_REPOSITORY}:cast-${DOCKER_TAG} ./cast-service
            sleep 2
          '''
        }
      }
    }
    stage('Docker run') {
      steps {
        script {
          sh '''
            export DOCKER_ID="${DOCKER_ID}"
            export DOCKER_TAG="${DOCKER_TAG}"
            export DOCKER_REPOSITORY="${DOCKER_REPOSITORY}"
            export CI_MOVIE_IMAGE="${DOCKER_ID}/${DOCKER_REPOSITORY}:movie-${DOCKER_TAG}"
            export CI_CAST_IMAGE="${DOCKER_ID}/${DOCKER_REPOSITORY}:cast-${DOCKER_TAG}"
            docker compose -f docker-compose.yml -f docker-compose.jenkins.yml down --remove-orphans -v 2>/dev/null || true
            docker compose -f docker-compose.yml -f docker-compose.jenkins.yml up -d --no-build
            sleep 20
          '''
        }
      }
    }
    stage('Test Acceptance') {
      steps {
        script {
          sh '''
            curl -fsS http://localhost:8080/api/v1/movies/ >/dev/null
            curl -fsS http://localhost:8080/api/v1/casts/docs >/dev/null
          '''
        }
      }
    }
    stage('Docker Push') {
      environment {
        DOCKER_PASS = credentials('DOCKER_HUB_PASS')
      }
      steps {
        script {
          sh '''
            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_ID}" --password-stdin
            docker push ${DOCKER_ID}/${DOCKER_REPOSITORY}:movie-${DOCKER_TAG}
            docker push ${DOCKER_ID}/${DOCKER_REPOSITORY}:cast-${DOCKER_TAG}
          '''
        }
      }
    }
    stage('Kubernetes namespaces') {
      environment {
        KUBECONFIG = credentials('config')
      }
      steps {
        script {
          sh '''
            rm -Rf .kube
            mkdir -p .kube
            cat "${KUBECONFIG}" > .kube/config
            export KUBECONFIG="$(pwd)/.kube/config"
            kubectl apply -f kubernetes/namespaces.yaml
          '''
        }
      }
    }
    stage('Deploiement en dev') {
      environment {
        KUBECONFIG = credentials('config')
      }
      steps {
        script {
          sh '''
            rm -Rf .kube
            mkdir -p .kube
            cat "${KUBECONFIG}" > .kube/config
            export KUBECONFIG="$(pwd)/.kube/config"
            helm upgrade --install fastapi-dev charts \
              -f charts/values.yaml \
              -f charts/values-dev.yaml \
              --set image.repository="${DOCKER_ID}/${DOCKER_REPOSITORY}" \
              --set image.tag="movie-${DOCKER_TAG}" \
              --namespace dev
          '''
        }
      }
    }
    stage('Deploiement en qa') {
      environment {
        KUBECONFIG = credentials('config')
      }
      steps {
        script {
          sh '''
            rm -Rf .kube
            mkdir -p .kube
            cat "${KUBECONFIG}" > .kube/config
            export KUBECONFIG="$(pwd)/.kube/config"
            helm upgrade --install fastapi-qa charts \
              -f charts/values.yaml \
              -f charts/values-qa.yaml \
              --set image.repository="${DOCKER_ID}/${DOCKER_REPOSITORY}" \
              --set image.tag="movie-${DOCKER_TAG}" \
              --namespace qa
          '''
        }
      }
    }
    stage('Deploiement en staging') {
      environment {
        KUBECONFIG = credentials('config')
      }
      steps {
        script {
          sh '''
            rm -Rf .kube
            mkdir -p .kube
            cat "${KUBECONFIG}" > .kube/config
            export KUBECONFIG="$(pwd)/.kube/config"
            helm upgrade --install fastapi-staging charts \
              -f charts/values.yaml \
              -f charts/values-staging.yaml \
              --set image.repository="${DOCKER_ID}/${DOCKER_REPOSITORY}" \
              --set image.tag="movie-${DOCKER_TAG}" \
              --namespace staging
          '''
        }
      }
    }
    stage('Deploiement en prod') {
      when {
        beforeAgent true
        expression {
          def raw = (env.BRANCH_NAME ?: env.GIT_BRANCH ?: '').trim()
          if (raw.startsWith('origin/')) raw = raw.substring('origin/'.length())
          if (raw.startsWith('refs/heads/')) raw = raw.substring('refs/heads/'.length())
          return raw == 'master'
        }
      }
      environment {
        KUBECONFIG = credentials('config')
      }
      steps {
        timeout(time: 15, unit: 'MINUTES') {
          input message: 'Deploy to production?', ok: 'Yes'
        }
        script {
          sh '''
            rm -Rf .kube
            mkdir -p .kube
            cat "${KUBECONFIG}" > .kube/config
            export KUBECONFIG="$(pwd)/.kube/config"
            helm upgrade --install fastapi-prod charts \
              -f charts/values.yaml \
              -f charts/values-prod.yaml \
              --set image.repository="${DOCKER_ID}/${DOCKER_REPOSITORY}" \
              --set image.tag="movie-${DOCKER_TAG}" \
              --namespace prod
          '''
        }
      }
    }
  }
  post {
    failure {
      echo 'Pipeline failure — check console output.'
      mail to: 'edouardribes82@gmail.com',
        subject: "${env.JOB_NAME} - Build # ${env.BUILD_ID} failed",
        body: "Console: ${env.BUILD_URL}"
    }
  }
}
