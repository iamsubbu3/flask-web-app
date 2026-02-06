pipeline {
    agent any

    tools {
        jdk 'jdk21'
    }
    
    environment {
        SCANNER_HOME       = tool 'sonar-scanner'

        // Define your Docker Hub/Registry details here
        DOCKER_USER_NAME = 'iamsubbu3'
        DOCKER_IMAGE     = 'Flask-web-app'

        // Using the Jenkins Build Number ensures every build has a unique tag
        DOCKER_TAG       = "${env.BUILD_NUMBER}" 
        REGISTRY_CRED    = 'docker-credentials'
        EKS_CLUSTER_NAME   = "subbu-cluster"
        AWS_REGION         = "us-east-1"
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
        
        stage ('git checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/iamsubbu3/flask-web-app.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh """
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=Flask-web-app \
                        -Dsonar.projectName=Flask-web-app \
                        -Dsonar.sources=.
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script {
                    timeout(time: 2, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    // Logs into Docker Hub using the credentials stored in Jenkins
                    docker.withRegistry('', "${REGISTRY_CRED}") {

                        // 1. Build the image with the proper name/tag
                        def myImage = docker.build("${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG}", ".")

                        // 2. Push the specific version tag
                        myImage.push()

                        // 3. Push the 'latest' tag (common practice for the newest stable build)
                        myImage.push('latest')
                    }
                }
            }
        }

        stage('Trivy Security Scan') {
            steps {
                script {
                    // Full image path for the scan
                    def fullImageName = "${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG}"
                    
                    // 1. Informational scan: Shows all vulnerabilities in the Jenkins console
                    echo "Scanning image: ${fullImageName}"
                    sh "trivy image --severity LOW,MEDIUM,HIGH ${fullImageName}"
                    
                    // 2. Quality Gate: This will FAIL the build (exit code 1) if any CRITICAL issues are found
                    // This prevents the 'deploy to eks' stage from running if the image is unsafe.
                    sh "trivy image --exit-code 1 --severity CRITICAL ${fullImageName}"
                    
                    // 3. Generate a JSON report for archiving
                    sh "trivy image --format json -o trivy-report.json ${fullImageName}"
                }
            }
        }
        
        stage('deploy to eks') {
            environment {
                // This automatically exports these as shell environment variables
                AWS_ACCESS_KEY_ID     = credentials('aws-access-key')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
            }
            steps {
                script {
                    dir('k8s-manifests') {
                        with
                        // 1. Refresh the kubeconfig
                        sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}"

                        // 2. IMPORTANT: Update the image tag in your YAML file dynamically
                        // This replaces 'IMAGE_TAG' or a placeholder with the actual Build Number
                        sh "sed -i 's|IMAGE_PLACEHOLDER|${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG}|g' app-deployment.yaml"
                        
                        // 3. Apply manifests
                        sh "kubectl apply -f app-deployment.yaml"
                        sh "kubectl apply -f app-service.yaml"
                        // Note: For this to work, go into your app-deployment.yaml and set the image field to: image: IMAGE_PLACEHOLDER
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Python Flask Web App deployed successfully!"
            emailext(
                subject: "SUCCESS: SonarQube quality gate passed",
                body: """
                    Hi team,
                    
                    The SonarQube quality gate passed successfully.
                    You can view the report here:
                    http://56.125.220.102:9000
                    Username: admin, Passwd: pass
                    
                    Regards,
                    Team DevOps,
                    Learnbay Pvt Ltd.
                """,
                to: 'subramanyam9979@gmail.com'
            )
        }

        failure {
            echo "Pipeline failed. Check logs for details."
            emailext(
                subject: 'FAILED: SonarQube quality gate',
                body: """
                    Hi Team,
                    
                    The SonarQube quality gate has failed.
                    Please check the details below:
                    
                    http://56.125.220.102:9000
                    Username: admin, Passwd: pass
                    
                    Regards,
                    Team DevOps
                    XYZ Pvt Ltd.
                """,
                to: 'subramanyam9979@gmail.com'
            )
        }

        always {
            // Clean up the local image to save disk space on the Jenkins agent
            sh "docker rmi ${DOCKER_USER_NAME}/${DOCKER_IMAGE}:${DOCKER_TAG} || true"
            sh "docker rmi ${DOCKER_USER_NAME}/${DOCKER_IMAGE}:latest || true"
        }
    }
}


