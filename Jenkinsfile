pipeline {
    agent any

    environment {
        // --- Update these for your environment ---
        NEXUS_HOST          = '192.168.0.125'
        NEXUS_PORT          = '8003'                    // Host port -> Nexus Docker connector (container 8082)
        NEXUS_UI_PORT       = '8002'                    // Nexus web UI (container 8081)
        NEXUS_DOCKER_REPO   = 'docker-hosted'
        SONAR_HOST          = 'http://192.168.0.125:8032'  // Host port -> SonarQube (container 9000)
        SONAR_PROJECT_KEY   = 'cis-deployment'
        SONAR_PROJECT_NAME  = 'CIS Deployment'

        // Image names pushed to Nexus
        IMAGE_BACKEND       = 'cis-backend'
        IMAGE_CONNECT       = 'cis-connect-engine'
        IMAGE_VISUALIZATION = 'cis-visualization-engine'
        IMAGE_SIMULATION    = 'cis-device-simulation'
        IMAGE_NGINX         = 'cis-nginx'

        REGISTRY            = "${NEXUS_HOST}:${NEXUS_PORT}"
        BUILD_VERSION       = "${env.BUILD_NUMBER}"
        GIT_COMMIT_SHORT    = "${env.GIT_COMMIT?.take(7) ?: 'local'}"
        IMAGE_TAG           = "${BUILD_VERSION}-${GIT_COMMIT_SHORT}"
        LOCAL_ARTIFACTS_PATH = '/opt/deployment/CIS-Deployment'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
        timestamps()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    echo "Building CIS Deployment - tag: ${IMAGE_TAG}"
                }
            }
        }

        stage('Prepare Artifacts') {
            steps {
                sh '''
                    set -e
                    JAR_BACKEND="CIS-Deployment/cisBackend/DragerCISBackend-0.0.1-SNAPSHOT.jar"
                    if [ ! -f "$JAR_BACKEND" ]; then
                        echo "JARs not in Git checkout - copying from local server path..."
                        if [ ! -d "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment" ]; then
                            echo "ERROR: Local artifacts not found at ${LOCAL_ARTIFACTS_PATH}"
                            exit 1
                        fi
                        cp -f "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment/cisBackend/"*.jar CIS-Deployment/cisBackend/ 2>/dev/null || true
                        cp -f "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment/connectEngine/"*.jar CIS-Deployment/connectEngine/ 2>/dev/null || true
                        cp -f "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment/visualizationEngine/"*.jar CIS-Deployment/visualizationEngine/ 2>/dev/null || true
                        cp -f "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment/deviceSimulation/"*.jar CIS-Deployment/deviceSimulation/ 2>/dev/null || true
                        if [ -d "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment/connectEngine/driverJarsDump" ]; then
                            mkdir -p CIS-Deployment/connectEngine/driverJarsDump
                            cp -f "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment/connectEngine/driverJarsDump/"*.jar CIS-Deployment/connectEngine/driverJarsDump/ 2>/dev/null || true
                            cp -f "${LOCAL_ARTIFACTS_PATH}/CIS-Deployment/connectEngine/driverJarsDump/drivers.xml CIS-Deployment/connectEngine/driverJarsDump/ 2>/dev/null || true
                        fi
                        echo "JAR files copied from ${LOCAL_ARTIFACTS_PATH}"
                    else
                        echo "JAR files already present in workspace"
                    fi
                '''
            }
        }

        stage('Validate Artifacts') {
            steps {
                sh '''
                    set -e
                    echo "Checking required JAR files..."
                    test -f CIS-Deployment/cisBackend/DragerCISBackend-0.0.1-SNAPSHOT.jar
                    test -f CIS-Deployment/connectEngine/device-connect-engine-0.0.1-SNAPSHOT.jar
                    test -f CIS-Deployment/visualizationEngine/device-visualization-engine-0.0.1-SNAPSHOT.jar
                    test -f CIS-Deployment/deviceSimulation/device-simulation-0.0.1-SNAPSHOT.jar
                    echo "All required JAR files found."
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                          -Dsonar.projectName="${SONAR_PROJECT_NAME}" \
                          -Dsonar.host.url=${SONAR_HOST}
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                sh '''
                    set -e
                    cd CIS-Deployment

                    docker build -t ${REGISTRY}/${IMAGE_BACKEND}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_BACKEND}:latest \
                                 ./cisBackend

                    docker build -t ${REGISTRY}/${IMAGE_CONNECT}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_CONNECT}:latest \
                                 ./connectEngine

                    docker build -t ${REGISTRY}/${IMAGE_VISUALIZATION}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_VISUALIZATION}:latest \
                                 ./visualizationEngine

                    docker build -t ${REGISTRY}/${IMAGE_SIMULATION}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_SIMULATION}:latest \
                                 ./deviceSimulation

                    docker build -t ${REGISTRY}/${IMAGE_NGINX}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_NGINX}:latest \
                                 -f nginx/Dockerfile.ci ./nginx
                '''
            }
        }

        stage('Push to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-docker-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set -e
                        echo "$NEXUS_PASS" | docker login ${REGISTRY} -u "$NEXUS_USER" --password-stdin

                        for IMAGE in ${IMAGE_BACKEND} ${IMAGE_CONNECT} ${IMAGE_VISUALIZATION} ${IMAGE_SIMULATION} ${IMAGE_NGINX}; do
                            docker push ${REGISTRY}/${IMAGE}:${IMAGE_TAG}
                            docker push ${REGISTRY}/${IMAGE}:latest
                        done

                        docker logout ${REGISTRY}
                    '''
                }
            }
        }

        stage('Archive Build Info') {
            steps {
                writeFile file: 'build-info.txt', text: """
CIS Deployment Build
====================
Build Number : ${BUILD_VERSION}
Git Commit   : ${GIT_COMMIT_SHORT}
Image Tag    : ${IMAGE_TAG}
Registry     : ${REGISTRY}

Images:
  ${REGISTRY}/${IMAGE_BACKEND}:${IMAGE_TAG}
  ${REGISTRY}/${IMAGE_CONNECT}:${IMAGE_TAG}
  ${REGISTRY}/${IMAGE_VISUALIZATION}:${IMAGE_TAG}
  ${REGISTRY}/${IMAGE_SIMULATION}:${IMAGE_TAG}
  ${REGISTRY}/${IMAGE_NGINX}:${IMAGE_TAG}
"""
                archiveArtifacts artifacts: 'build-info.txt', fingerprint: true
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded. Images pushed to Nexus: ${REGISTRY}"
        }
        failure {
            echo "Pipeline failed. Check SonarQube quality gate or Docker build logs."
        }
        always {
            sh '''
                docker image prune -f || true
            '''
        }
    }
}
