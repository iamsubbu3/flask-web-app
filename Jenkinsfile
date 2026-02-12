pipeline {
    agent any

    tools {
        jdk 'jdk21'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        /* ---------- SonarQube ---------- */
        SCANNER_HOME        = tool 'sonar-scanner'
        SONAR_HOST_URL      = 'http://sonarqube.company.com'
        SONAR_PROJECT_KEY   = 'Flask-web-app'

        /* ---------- Docker ---------- */
        DOCKER_USER_NAME    = 'iamsubbu3'
        DOCKER_IMAGE        = 'flask-web-app'
        DOCKER_TAG          = "${BUILD_NUMBER}"
        REGISTRY_CRED       = 'docker-credentials'

        /* ---------- AWS / EKS ---------- */
        EKS_CLUSTER_NAME    = 'subbu-1-cluster'
        AWS_REGION          = 'us-east-1'

        /* ---------- Notifications ---------- */
        NOTIFY_EMAILS       = 'subramanyam9979@gmail.com'
    }

    triggers {
        githubPush()
    }

    stages {

        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout Source Code') {
            steps {
                git branch: 'master',
                    url: 'https://github.com/iamsubbu3/flask-web-app.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh """
                        ${SCANNER_HOME}/bin/sonar-scanner \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.projectName=${SONAR_PROJECT_KEY} \
                        -Dsonar.sources=.
                    """
                }
            }
        }

        stage('Sonar Quality Gate') {
            steps {
                timeout(time: 3, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    withDockerRegistry([credentialsId: REGISTRY_CRED, url: '']) {
                        def image = docker.build("${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG}")
                        image.push()
                        // image.push('latest')
                    }
                }
            }
        }

        stage('Trivy Security Scan') {
            steps {
                script {
                    def IMAGE = "${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG}"

                    echo "🔍 Running Trivy scan on ${IMAGE}"

                    sh "trivy image --severity LOW,MEDIUM,HIGH ${IMAGE}"
                    sh "trivy image --exit-code 1 --severity CRITICAL ${IMAGE}"
                    sh "trivy image --format json -o trivy-report.json ${IMAGE}"

                    archiveArtifacts artifacts: 'trivy-report.json', fingerprint: true
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                dir('k8s-manifests') {
                    withCredentials([
                        aws(
                            credentialsId: 'aws-keys',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {

                        sh """
                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${EKS_CLUSTER_NAME}
                        """

                        sh """
                        sed -i 's|IMAGE_PLACEHOLDER|${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG}|g' app-deployment.yaml
                        """

                        sh "kubectl apply -f app-deployment.yaml"
                        sh "kubectl apply -f app-service.yaml"
                    }
                }
            }
        }
    }

    post {

        success {
            emailext(
                subject: "✅ SUCCESS | ${JOB_NAME} #${BUILD_NUMBER}",
                body: """
Hi Team,

✅ Pipeline executed successfully.

🔹 Job Name   : ${JOB_NAME}
🔹 Build No   : ${BUILD_NUMBER}
🔹 Status     : SUCCESS

🔗 Jenkins Build:
${BUILD_URL}

🔗 SonarQube Report:
${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}

🔗 Docker Image:
${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG}

Regards,
DevOps Automation
""",
                to: "${NOTIFY_EMAILS}"
            )
        }

        failure {
            emailext(
                subject: "❌ FAILURE | ${JOB_NAME} #${BUILD_NUMBER}",
                body: """
Hi Team,

❌ Pipeline execution FAILED.

🔹 Job Name  : ${JOB_NAME}
🔹 Build No  : ${BUILD_NUMBER}

🔗 Jenkins Logs:
${BUILD_URL}console

🔗 SonarQube Report:
${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}

Please review logs and take action.

Regards,
DevOps Automation
""",
                to: "${NOTIFY_EMAILS}"
            )
        }

        always {
            echo "🧹 Cleaning Docker images from Jenkins agent..."

            sh """
            docker rmi ${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG} || true
            docker rmi ${DOCKER_USER_NAME}/${DOCKER_IMAGE}:latest || true
            """
        }
    }
}
