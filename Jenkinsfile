pipeline {
    agent any

    environment {
        COMPOSE_PROJECT_NAME = 'mr-jenk'
        APP_VERSION = "${BUILD_NUMBER}"
        DEPLOYED = 'false'
    }

    stages {
        /*
         * ==========================================
         * 1. CHECKOUT
         * ==========================================
         */
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        /*
         * ==========================================
         * 2. BACKEND TESTS
         * ==========================================
         */

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

        /*
         * 3. FRONTEND TESTS
         */
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

        /*
         * ==========================================
         * 4. DOCKER BUILD
         * ==========================================
         */
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

                        echo "Checking required credentials..."

                        test -f "$KEYSTORE_FILE"
                        test -f "$ENV_FILE"

                        echo "Installing gateway keystore..."

                        install -D "$KEYSTORE_FILE" \
                            api-gateway/src/main/resources/keystore.p12

                        trap 'rm -f api-gateway/src/main/resources/keystore.p12' EXIT

                        echo "Building Docker images..."

                        docker compose \
                            --env-file "$ENV_FILE" \
                            -f compose.prod.yml \
                            build
                    '''
                }
            }
        }

        /*
         * ==========================================
         * 5. DEPLOY
         * ==========================================
         */
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

                        echo "Deploying application version $APP_VERSION..."

                        docker compose \
                            --env-file "$ENV_FILE" \
                            -f compose.prod.yml \
                            up -d
                    '''

                    script {
                        env.DEPLOYED = 'true'
                    }
                }
            }
        }

        /*
         * ==========================================
         * 6. NORMAL HEALTH CHECK
         * ==========================================
         */
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

                        echo "=========================================="
                        echo "Starting application health check"
                        echo "Version: $APP_VERSION"
                        echo "=========================================="

                        docker compose \
                            --env-file "$ENV_FILE" \
                            -f compose.prod.yml \
                            ps

                        for i in $(seq 1 30); do

                            echo ""
                            echo "Health check attempt $i/30"

                            DISCOVERY_STATUS=$(docker inspect \
                                --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
                                discovery-server)

                            GATEWAY_STATUS=$(docker inspect \
                                --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
                                api-gateway)

                            MONGO_STATUS=$(docker inspect \
                                --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
                                mongodb)

                            echo "Discovery Server: $DISCOVERY_STATUS"
                            echo "API Gateway:      $GATEWAY_STATUS"
                            echo "MongoDB:          $MONGO_STATUS"

                            if [ "$DISCOVERY_STATUS" = "healthy" ] && \
                               [ "$GATEWAY_STATUS" = "healthy" ] && \
                               [ "$MONGO_STATUS" = "healthy" ]; then

                                echo ""
                                echo "=========================================="
                                echo "All required services are healthy!"
                                echo "Deployment successful."
                                echo "=========================================="

                                exit 0
                            fi

                            sleep 5

                        done

                        echo ""
                        echo "=========================================="
                        echo "HEALTH CHECK FAILED"
                        echo "=========================================="

                        docker compose \
                            --env-file "$ENV_FILE" \
                            -f compose.prod.yml \
                            ps

                        exit 1
                    '''
                }
            }
        }

        /*
         * ==========================================
         * 7. SAVE STABLE VERSION
         * ==========================================
         */
        stage('Save Stable Version') {
            steps {
                sh '''
                    echo "$BUILD_NUMBER" > /var/jenkins_home/last-stable-version

                    echo ""
                    echo "=========================================="
                    echo "Stable version saved"
                    echo "Version: $BUILD_NUMBER"
                    echo "=========================================="

                    cat /var/jenkins_home/last-stable-version
                '''
            }
        }
    }

    /*
     * ==========================================
     * POST ACTIONS
     * ==========================================
     */
    post {
        /*
         * ==========================================
         * SUCCESS
         * ==========================================
         */
        success {
            echo '=========================================='
            echo 'CI/CD pipeline completed successfully!'
            echo "Stable version: ${env.BUILD_NUMBER}"
            echo '=========================================='
        }

        /*
         * ==========================================
         * FAILURE + AUTOMATIC ROLLBACK
         * ==========================================
         */
        failure {
            script {
                if (env.DEPLOYED != 'true') {
                    echo '=========================================='
                    echo 'Pipeline failed before deployment.'
                    echo 'No rollback is required.'
                    echo '=========================================='
                } else {
                    echo '=========================================='
                    echo 'Deployment or health check failed.'
                    echo 'Starting automatic rollback...'
                    echo '=========================================='

                    /*
                     * Read last stable version
                     */
                    def stableVersion = sh(
                        script: 'cat /var/jenkins_home/last-stable-version 2>/dev/null || true',
                        returnStdout: true
                    ).trim()

                    /*
                     * Check stable version
                     */
                    if (!stableVersion) {
                        echo '=========================================='
                        echo 'No previous stable version found.'
                        echo 'Rollback cannot be performed.'
                        echo '=========================================='

                        error(
                            'No stable version available for rollback.'
                        )
                    }

                    echo "Previous stable version: ${stableVersion}"
                    echo "Rolling back to version ${stableVersion}..."

                    /*
                     * Rollback deployment
                     */
                    withCredentials([
                        file(
                            credentialsId: 'production-env',
                            variable: 'ENV_FILE'
                        )
                    ]) {
                        sh """
                            set +x

                            test -f "\$ENV_FILE"

                            echo "Starting rollback..."

                            APP_VERSION=${stableVersion} docker compose \
                                --env-file "\$ENV_FILE" \
                                -f compose.prod.yml \
                                up -d
                        """
                    }

                    echo 'Rollback deployment completed.'

                    /*
                     * Rollback health check
                     */
                    echo '=========================================='
                    echo 'Checking rollback health...'
                    echo "Rollback version: ${stableVersion}"
                    echo '=========================================='

                    withCredentials([
                        file(
                            credentialsId: 'production-env',
                            variable: 'ENV_FILE'
                        )
                    ]) {
                        sh '''
                            set +x

                            test -f "$ENV_FILE"

                            for i in $(seq 1 30); do

                                echo ""
                                echo "Rollback health check attempt $i/30"

                                DISCOVERY_STATUS=$(docker inspect \
                                    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
                                    discovery-server)

                                GATEWAY_STATUS=$(docker inspect \
                                    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
                                    api-gateway)

                                MONGO_STATUS=$(docker inspect \
                                    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
                                    mongodb)

                                echo "Discovery Server: $DISCOVERY_STATUS"
                                echo "API Gateway:      $GATEWAY_STATUS"
                                echo "MongoDB:          $MONGO_STATUS"

                                if [ "$DISCOVERY_STATUS" = "healthy" ] && \
                                   [ "$GATEWAY_STATUS" = "healthy" ] && \
                                   [ "$MONGO_STATUS" = "healthy" ]; then

                                    echo ""
                                    echo "=========================================="
                                    echo "Rollback health check PASSED!"
                                    echo "Application is healthy again."
                                    echo "=========================================="

                                    exit 0
                                fi

                                sleep 5

                            done

                            echo ""
                            echo "=========================================="
                            echo "ROLLBACK HEALTH CHECK FAILED"
                            echo "=========================================="

                            docker compose \
                                --env-file "$ENV_FILE" \
                                -f compose.prod.yml \
                                ps

                            exit 1
                        '''
                    }

                    echo '=========================================='
                    echo "Rollback completed successfully to version ${stableVersion}"
                    echo '=========================================='
                }
            }
        }

        /*
         * ==========================================
         * ALWAYS
         * ==========================================
         */
        always {
            echo '=========================================='
            echo 'Pipeline finished.'
            echo '=========================================='
        }
    }
}
