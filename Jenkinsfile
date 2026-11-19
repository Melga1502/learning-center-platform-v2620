pipeline {
  // "any": que Jenkins use cualquier ejecutor disponible (aquí, el propio Jenkins)
  agent any

  environment {
    // Aquí no hay bloque "tools": el JDK 26 y Maven ya vienen dentro de la imagen de Jenkins.
    // Se le indica a Maven qué Java usar apuntando JAVA_HOME al JDK 26.
    JAVA_HOME = "${env.JAVA_HOME_26}"
    PATH      = "${env.JAVA_HOME_26}/bin:${env.PATH}"

    // Nombre final de la imagen: usuario_dockerhub/retail-store-<codigo>:<tag>  (TODO EN MINÚSCULAS)
    REGISTRY_USER = 'melga135'                      // tu usuario de Docker Hub
    CODIGO        = 'practica'                      // en el examen: tu código de estudiante, en minúsculas
    IMAGE_NAME    = "retail-store-${CODIGO}"
    TAG           = "${env.BUILD_NUMBER}"           // el número de ejecución de Jenkins sirve de versión
  }

  stages {
    stage('Compile Project') {
      steps {
        sh 'mvn -B -ntp clean compile'
      }
    }

    // El pom.xml ya trae Checkstyle: si el código no cumple el estilo, el build falla aquí
    stage('Validate Checkstyle') {
      steps {
        sh 'mvn -B -ntp checkstyle:check'
      }
    }

    stage('Validate Unit Tests') {
      steps {
        sh 'mvn -B -ntp test'
      }
      post {
        always {
          // Muestra los resultados de las pruebas en Jenkins
          junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: true
        }
      }
    }

    // "verify" ejecuta las pruebas con JaCoCo y valida la cobertura mínima definida en el pom.xml
    stage('Validate Test Coverage') {
      steps {
        sh 'mvn -B -ntp verify'
      }
    }

    stage('SonarQube Analysis') {
      steps {
        // MiSonarServer es el nombre del servidor en Jenkins; inyecta la URL y el token de SonarQube
        withSonarQubeEnv('MiSonarServer') {
          sh "mvn -B -ntp sonar:sonar -Dsonar.projectKey=${IMAGE_NAME} -Dsonar.projectName=${IMAGE_NAME}"
        }
        // Espera el aviso (webhook) de SonarQube con el resultado del Quality Gate
        script {
          timeout(time: 10, unit: 'MINUTES') {
            def qg = waitForQualityGate()
            if (qg.status != 'OK') {
              error "No se superó el Quality Gate de SonarQube: ${qg.status}"
            }
          }
        }
      }
    }

    stage('Package Project') {
      steps {
        sh 'mvn -B -ntp package -DskipTests'
      }
    }

    stage('Build Docker Image') {
      steps {
        // Dos etiquetas: la versión (número de build) y "latest"
        sh "docker build -t ${REGISTRY_USER}/${IMAGE_NAME}:${TAG} -t ${REGISTRY_USER}/${IMAGE_NAME}:latest ."
        sh "docker images ${REGISTRY_USER}/${IMAGE_NAME}"
      }
    }

    stage('Push Docker Image') {
      steps {
        // La credencial vive en Jenkins; el pipeline nunca escribe la contraseña
        withCredentials([usernamePassword(credentialsId: 'DOCKER_HUB_CREDENTIALS',
                                          usernameVariable: 'DOCKER_USER',
                                          passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push "$REGISTRY_USER/$IMAGE_NAME:$TAG"
            docker push "$REGISTRY_USER/$IMAGE_NAME:latest"
          '''
        }
      }
      post {
        always {
          sh 'docker logout || true'
        }
      }
    }
  }
}
