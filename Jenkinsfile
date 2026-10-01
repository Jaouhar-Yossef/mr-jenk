pipeline {
    agent any

    environment {
        COMPOSE_PROJECT_NAME = 'buy-01'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
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
                }

                stage('API Gateway Tests') {
                    steps {
                        dir('api-gateway') {
                            sh './mvnw clean test'
                        }
                    }
                }

                stage('User Service Tests') {
                    steps {
                        dir('user-service') {
                            sh './mvnw clean test'
                        }
                    }
                }

                stage('Product Service Tests') {
                    steps {
                        dir('product-service') {
                            sh './mvnw clean test'
                        }
                    }
                }

                stage('Media Service Tests') {
                    steps {
                        dir('media-service') {
                            sh './mvnw clean test'
                        }
                    }
                }
            }
        }

        stage('Frontend Tests') {
            steps {
                dir('frontend') {
                    sh '''
                docker run --rm \
                    -v jenkins_home:/var/jenkins_home \
                    -w "$PWD" \
                    node:22 \
                    sh -c "echo '=== FILE ==='; ls -l package-lock.json; echo '=== LOCKFILE VERSION ==='; node -e \\"const p=require('./package-lock.json'); console.log(p.lockfileVersion)\\"; echo '=== NPM CI ==='; npm ci && npm test"
            '''
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker compose -f compose.prod.yml build'
            }
        }

        stage('Deploy') {
            steps {
                sh 'docker compose -f compose.prod.yml up -d'
            }
        }
    }

    post {
        success {
            echo 'CI/CD pipeline completed successfully!'
        }

        failure {
            echo 'Pipeline failed. Deployment was not completed successfully.'
        }

        always {
            echo 'Pipeline finished.'
        }
    }
}
