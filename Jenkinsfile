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
        PATH                   = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        JAVA_HOME              = '/opt/java/openjdk'
        DOCKER_BIN             = '/usr/local/bin/docker'
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
                sh """
                    set -e
                    LOCAL_PATH='${LOCAL_ARTIFACTS_PATH}'
                    JAR_BACKEND='CIS-Deployment/cisBackend/DragerCISBackend-0.0.1-SNAPSHOT.jar'

                    if [ ! -f "\$JAR_BACKEND" ]; then
                        echo "JARs not in Git checkout - copying from local server path..."
                        if [ ! -d "\$LOCAL_PATH/CIS-Deployment" ]; then
                            echo "ERROR: Local artifacts not found at \$LOCAL_PATH"
                            exit 1
                        fi
                        mkdir -p CIS-Deployment/cisBackend CIS-Deployment/connectEngine CIS-Deployment/visualizationEngine CIS-Deployment/deviceSimulation CIS-Deployment/connectEngine/driverJarsDump
                        cp -f "\$LOCAL_PATH/CIS-Deployment/cisBackend/"*.jar CIS-Deployment/cisBackend/ 2>/dev/null || true
                        cp -f "\$LOCAL_PATH/CIS-Deployment/connectEngine/"*.jar CIS-Deployment/connectEngine/ 2>/dev/null || true
                        cp -f "\$LOCAL_PATH/CIS-Deployment/visualizationEngine/"*.jar CIS-Deployment/visualizationEngine/ 2>/dev/null || true
                        cp -f "\$LOCAL_PATH/CIS-Deployment/deviceSimulation/"*.jar CIS-Deployment/deviceSimulation/ 2>/dev/null || true
                        cp -f "\$LOCAL_PATH/CIS-Deployment/connectEngine/driverJarsDump/"*.jar CIS-Deployment/connectEngine/driverJarsDump/ 2>/dev/null || true
                        cp -f "\$LOCAL_PATH/CIS-Deployment/connectEngine/driverJarsDump/drivers.xml" CIS-Deployment/connectEngine/driverJarsDump/ 2>/dev/null || true
                        echo "JAR files copied from \$LOCAL_PATH"
                    else
                        echo "JAR files already present in workspace"
                    fi
                """
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
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    withSonarQubeEnv('cis-deployment') {
                        withCredentials([string(credentialsId: 'sonarqube-token-CIS', variable: 'SONAR_TOKEN')]) {
                            sh '''
                                export JAVA_HOME=/opt/java/openjdk
                                SCANNER_JAR=/opt/sonar-scanner-5.0.1.3006-linux/lib/sonar-scanner-cli-5.0.1.3006.jar

                                $JAVA_HOME/bin/java -jar "$SCANNER_JAR" \
                                  -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                  -Dsonar.projectName="${SONAR_PROJECT_NAME}" \
                                  -Dsonar.host.url=${SONAR_HOST} \
                                  -Dsonar.token=${SONAR_TOKEN}
                            '''
                        }
                    }
                }
            }
        }

        stage('SonarQube Metrics') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    withCredentials([string(credentialsId: 'sonarqube-token-CIS', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            echo "========== SonarQube Quality Report (informational only) =========="
                            echo "Dashboard: ${SONAR_HOST}/dashboard?id=${SONAR_PROJECT_KEY}"
                            echo ""

                            if [ -f .scannerwork/report-task.txt ]; then
                                TASK_ID=$(grep '^ceTaskId=' .scannerwork/report-task.txt | cut -d= -f2 || true)
                                if [ -n "$TASK_ID" ]; then
                                    for i in $(seq 1 12); do
                                        RESPONSE=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST}/api/ce/task?id=${TASK_ID}")
                                        STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
                                        echo "CE task status: ${STATUS:-unknown}"
                                        [ "$STATUS" = "SUCCESS" ] && break
                                        [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "CANCELED" ] && break
                                        sleep 10
                                    done
                                fi
                            else
                                echo "No scanner report found - analysis may have been skipped"
                            fi

                            echo ""
                            echo "--- Quality Gate Status ---"
                            QG=$(curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" || true)
                            echo "$QG" | grep -o '"status":"[^"]*"' | head -1 || echo "$QG"

                            echo ""
                            echo "--- Code Metrics ---"
                            METRICS=$(curl -s -u "${SONAR_TOKEN}:" \
                                "${SONAR_HOST}/api/measures/component?component=${SONAR_PROJECT_KEY}&metricKeys=bugs,vulnerabilities,code_smells,coverage,duplicated_lines_density,ncloc,security_hotspots" || true)
                            echo "$METRICS" | grep -oE '"metric":"[^"]+"|"value":"[^"]*"' | paste - - | sed 's/"metric":"//;s/"value":"//;s/"//g;s/\t/ = /' || echo "Metrics not available yet - check dashboard"

                            echo ""
                            echo "NOTE: Quality gate does NOT block this pipeline."
                            echo "=================================================================="
                        '''
                    }
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                sh '''
                    set -e
                    DOCKER_BIN=/usr/local/bin/docker
                    test -x "$DOCKER_BIN" || DOCKER_BIN=$(command -v docker)
                    test -x "$DOCKER_BIN" || { echo "ERROR: docker not found. Rebuild Jenkins with --no-cache"; exit 1; }
                    cd CIS-Deployment

                    $DOCKER_BIN build -t ${REGISTRY}/${IMAGE_BACKEND}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_BACKEND}:latest \
                                 ./cisBackend

                    $DOCKER_BIN build -t ${REGISTRY}/${IMAGE_CONNECT}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_CONNECT}:latest \
                                 ./connectEngine

                    $DOCKER_BIN build -t ${REGISTRY}/${IMAGE_VISUALIZATION}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_VISUALIZATION}:latest \
                                 ./visualizationEngine

                    $DOCKER_BIN build -t ${REGISTRY}/${IMAGE_SIMULATION}:${IMAGE_TAG} \
                                 -t ${REGISTRY}/${IMAGE_SIMULATION}:latest \
                                 ./deviceSimulation

                    $DOCKER_BIN build -t ${REGISTRY}/${IMAGE_NGINX}:${IMAGE_TAG} \
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
                        DOCKER_BIN=/usr/local/bin/docker
                        test -x "$DOCKER_BIN" || DOCKER_BIN=$(command -v docker)
                        echo "$NEXUS_PASS" | $DOCKER_BIN login ${REGISTRY} -u "$NEXUS_USER" --password-stdin

                        for IMAGE in ${IMAGE_BACKEND} ${IMAGE_CONNECT} ${IMAGE_VISUALIZATION} ${IMAGE_SIMULATION} ${IMAGE_NGINX}; do
                            $DOCKER_BIN push ${REGISTRY}/${IMAGE}:${IMAGE_TAG}
                            $DOCKER_BIN push ${REGISTRY}/${IMAGE}:latest
                        done

                        $DOCKER_BIN logout ${REGISTRY}
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
            echo "Pipeline failed during Docker build or Nexus push. Check console log."
        }
        always {
            sh '/usr/local/bin/docker image prune -f || true'
        }
    }
}
