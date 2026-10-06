pipeline {
    agent any

    environment {
        COMPOSE_PROJECT_NAME = 'mr-jenk'
        APP_VERSION = "${BUILD_NUMBER}"
    }

    stages {
        // ==========================================
        // 1. CHECKOUT
        // ==========================================
        stage('Checkout') {
            steps {
                checkout scm

                sh '''
                    rm -f .deployment-successful
                    rm -f .deployment-attempted
                '''
            }
        }

        // ==========================================
        // 2. BACKEND TESTS
        // ==========================================
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

        // ==========================================
        // 3. FRONTEND TESTS
        // ==========================================
        stage('Frontend Tests') {
            steps {
                sh '''
                    docker run --rm \
                        -v jenkins_home:/var/jenkins_home \
                        -w /var/jenkins_home/workspace/mr-jenk-pipeline/frontend \
                        node:22 \
                        sh -c "npm ci && npm test -- --watch=false --reporters=junit --output-file=test-results.xml"
                '''
            }

            post {
                always {
                    junit allowEmptyResults: true,
                          testResults: 'frontend/test-results.xml'
                }
            }
        }

        // ==========================================
        // 4. DOCKER BUILD
        // ==========================================
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
                    sh '''
                        set +x

                        test -f "$KEYSTORE_FILE"
                        test -f "$ENV_FILE"

                        install -D "$KEYSTORE_FILE" api-gateway/src/main/resources/keystore.p12

                        trap 'rm -f api-gateway/src/main/resources/keystore.p12' EXIT

                        echo "Building Docker images: $APP_VERSION"

                        docker compose --env-file "$ENV_FILE" -f compose.prod.yml build
                    '''
                }
            }
        }

        // ==========================================
        // 5. DEPLOY
        // ==========================================
        stage('Deploy') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'production-env',
                        variable: 'ENV_FILE'
                    )
                ]) {
                    sh '''
                        set +x

                        test -f "$ENV_FILE"

                        echo "Deploying version $APP_VERSION"

                        touch .deployment-attempted

                        docker compose --env-file "$ENV_FILE" -f compose.prod.yml up -d

                        touch .deployment-successful

                        echo "Deployment completed: $APP_VERSION"
                    '''
                }
            }
        }

        // ==========================================
        // 6. HEALTH CHECK
        // ==========================================
        stage('Health Check') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'production-env',
                        variable: 'ENV_FILE'
                    )
                ]) {
                    sh '''
                        set +x

                        test -f "$ENV_FILE"

                        echo "Checking application health..."

                        for i in $(seq 1 30); do

                            DISCOVERY_STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' discovery-server)

                            GATEWAY_STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' api-gateway)

                            MONGO_STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' mongodb)

                            if [ "$DISCOVERY_STATUS" = "healthy" ] && [ "$GATEWAY_STATUS" = "healthy" ] && [ "$MONGO_STATUS" = "healthy" ]; then

                                echo "Application health check passed."

                                exit 0
                            fi

                            echo "Health check $i/30: Discovery=$DISCOVERY_STATUS Gateway=$GATEWAY_STATUS MongoDB=$MONGO_STATUS"

                            sleep 5
                        done

                        echo "Application health check failed."

                        docker compose --env-file "$ENV_FILE" -f compose.prod.yml ps

                        exit 1
                    '''
                }
            }
        }

        // ==========================================
        // 7. SAVE STABLE VERSION
        // ==========================================
        stage('Save Stable Version') {
            steps {
                sh '''
                    echo "$BUILD_NUMBER" > /var/jenkins_home/last-stable-version

                    echo "Stable version: $BUILD_NUMBER"
                '''
            }
        }
    }

    // ==========================================
    // POST ACTIONS
    // ==========================================
    post {
        // ==========================================
        // SUCCESS
        // ==========================================
        success {
            echo 'CI/CD pipeline completed successfully.'
            echo "Stable version: ${env.BUILD_NUMBER}"
        }

        // ==========================================
        // FAILURE + AUTOMATIC ROLLBACK
        // ==========================================
        failure {
            script {
                if (!fileExists('.deployment-attempted')) {
                    echo 'Pipeline failed before deployment.'
                    echo 'No rollback required.'
                } else {
                    echo 'Deployment failed.'
                    echo 'Starting automatic rollback...'

                    def stableVersion = sh(
                        script: '''
                            cat /var/jenkins_home/last-stable-version 2>/dev/null || true
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!stableVersion) {
                        echo 'No stable version available.'

                        error('Rollback cannot be performed.')
                    }

                    echo "Rolling back from ${env.BUILD_NUMBER} to ${stableVersion}."

                    // ==========================================
                    // ROLLBACK DEPLOYMENT
                    // ==========================================
                    withCredentials([
                        file(
                            credentialsId: 'production-env',
                            variable: 'ENV_FILE'
                        )
                    ]) {
                        sh """
                            set +x

                            test -f "\$ENV_FILE"

                            APP_VERSION=${stableVersion} docker compose --env-file "\$ENV_FILE" -f compose.prod.yml up -d --force-recreate

                            echo "Rollback deployment completed."
                        """
                    }

                    // ==========================================
                    // ROLLBACK HEALTH CHECK
                    // ==========================================
                    withCredentials([
                        file(
                            credentialsId: 'production-env',
                            variable: 'ENV_FILE'
                        )
                    ]) {
                        sh '''
                            set +x

                            test -f "$ENV_FILE"

                            echo "Checking rollback health..."

                            for i in $(seq 1 30); do

                                DISCOVERY_STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' discovery-server)

                                GATEWAY_STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' api-gateway)

                                MONGO_STATUS=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' mongodb)

                                if [ "$DISCOVERY_STATUS" = "healthy" ] && [ "$GATEWAY_STATUS" = "healthy" ] && [ "$MONGO_STATUS" = "healthy" ]; then

                                    echo "Rollback health check passed."

                                    exit 0
                                fi

                                echo "Rollback health check $i/30: Discovery=$DISCOVERY_STATUS Gateway=$GATEWAY_STATUS MongoDB=$MONGO_STATUS"

                                sleep 5
                            done

                            echo "Rollback health check failed."

                            docker compose --env-file "$ENV_FILE" -f compose.prod.yml ps

                            exit 1
                        '''
                    }

                    echo "Rollback completed successfully: ${stableVersion}"
                }
            }
        }

        // ==========================================
        // ALWAYS
        // ==========================================
        always {
            echo 'Pipeline finished.'
        }
    }
}
