pipeline {

    agent any

    environment {
        COMPOSE_PROJECT_NAME = 'mr-jenk'
        APP_VERSION = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    rm -f .deployment-successful
                    rm -f .deployment-attempted
                '''
            }
        }

        stage('Backend Tests') {
            parallel {

                stage('Discovery Server Tests') {
                    steps {
                        dir('discovery-server') {
                            sh './mvnw clean test'
                        }
                    }

                    post {
                        always {
                            dir('discovery-server') {
                                junit allowEmptyResults: true,
                                      testResults: 'target/surefire-reports/*.xml'
                            }
                        }
                    }
                }

                stage('API Gateway Tests') {
                    steps {
                        dir('api-gateway') {
                            sh './mvnw clean test'
                        }
                    }

                    post {
                        always {
                            dir('api-gateway') {
                                junit allowEmptyResults: true,
                                      testResults: 'target/surefire-reports/*.xml'
                            }
                        }
                    }
                }

                stage('User Service Tests') {
                    steps {
                        dir('user-service') {
                            sh './mvnw clean test'
                        }
                    }

                    post {
                        always {
                            dir('user-service') {
                                junit allowEmptyResults: true,
                                      testResults: 'target/surefire-reports/*.xml'
                            }
                        }
                    }
                }

                stage('Product Service Tests') {
                    steps {
                        dir('product-service') {
                            sh './mvnw clean test'
                        }
                    }

                    post {
                        always {
                            dir('product-service') {
                                junit allowEmptyResults: true,
                                      testResults: 'target/surefire-reports/*.xml'
                            }
                        }
                    }
                }

                stage('Media Service Tests') {
                    steps {
                        dir('media-service') {
                            sh './mvnw clean test'
                        }
                    }

                    post {
                        always {
                            dir('media-service') {
                                junit allowEmptyResults: true,
                                      testResults: 'target/surefire-reports/*.xml'
                            }
                        }
                    }
                }
            }
        }

        stage('Frontend Tests') {
            steps {
                sh './scripts/frontend-test.sh'
            }

            post {
                always {
                    junit allowEmptyResults: true,
                          testResults: 'frontend/test-results.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'gateway-keystore',
                        variable: 'KEYSTORE_FILE'
                    ),
                    file(
                        credentialsId: 'production-env',
                        variable: 'ENV_FILE'
                    )
                ]) {
                    sh './scripts/docker-build.sh'
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'production-env',
                        variable: 'ENV_FILE'
                    )
                ]) {
                    sh './scripts/deploy.sh'
                }
            }
        }

        stage('Health Check') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'production-env',
                        variable: 'ENV_FILE'
                    )
                ]) {
                    sh './scripts/health-check.sh'
                }
            }
        }

        stage('Save Stable Version') {
            steps {
                sh '''
                    echo "$BUILD_NUMBER" > /var/jenkins_home/last-stable-version
                    echo "Stable version: $BUILD_NUMBER"
                '''
            }
        }
    }

    post {

        success {
            echo 'CI/CD pipeline completed successfully.'
            echo "Stable version: ${env.BUILD_NUMBER}"
        }

        failure {
            script {

                if (!fileExists('.deployment-attempted')) {

                    echo 'Pipeline failed before deployment.'
                    echo 'No rollback required.'

                } else {

                    echo 'Deployment failed.'
                    echo 'Starting automatic rollback...'

                    withCredentials([
                        file(
                            credentialsId: 'production-env',
                            variable: 'ENV_FILE'
                        )
                    ]) {
                        sh './scripts/rollback.sh'
                        sh './scripts/rollback-health-check.sh'
                    }

                    echo 'Rollback completed successfully.'
                }
            }
        }

        always {
            echo 'Pipeline finished.'
        }
    }
}
