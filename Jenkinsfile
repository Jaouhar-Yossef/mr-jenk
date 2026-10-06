pipeline {
    agent any

    environment {
        COMPOSE_PROJECT_NAME = 'mr-jenk'
        APP_VERSION = "${BUILD_NUMBER}"
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

                /*
                 * Remove deployment markers from previous builds.
                 * This prevents an old marker from triggering
                 * a false rollback.
                 */
                sh '''
                    rm -f .deployment-successful
                    rm -f .deployment-attempted
                '''
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
         * ==========================================
         * 3. FRONTEND TESTS
         * ==========================================
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

                        echo "=========================================="
                        echo "Building Docker images"
                        echo "Version: $APP_VERSION"
                        echo "=========================================="

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
            file(credentialsId: 'production-env', variable: 'ENV_FILE')
        ]) {
                    sh '''
                set +x

                echo "=========================================="
                echo "Deploying application"
                echo "Version: $APP_VERSION"
                echo "=========================================="

                test -f "$ENV_FILE"

                touch .deployment-attempted
                echo "Deployment attempt marker created."

                docker compose --env-file "$ENV_FILE" -f compose.prod.yml up -d

                echo "Deployment command completed successfully."

                touch .deployment-successful
                echo "Deployment success marker created."

                echo "=========================================="
                echo "Deployment completed"
                echo "=========================================="
            '''
        }
            }
        }

        /*
         * ==========================================
         * 6. HEALTH CHECK
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
                                echo "=========================================="

                                /*
                                 * INTENTIONAL FAILURE
                                 *
                                 * This is currently exit 1 on purpose
                                 * to test automatic rollback.
                                 *
                                 * After rollback testing is finished,
                                 * change this to:
                                 *
                                 * exit 0
                                 */
                                echo "INTENTIONAL FAILURE: Testing automatic rollback..."

                                exit 1
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
                /*
                 * Check whether deployment was attempted.
                 *
                 * If this file does not exist, the pipeline failed
                 * before deployment:
                 *
                 * - Backend tests
                 * - Frontend tests
                 * - Docker build
                 *
                 * Therefore no rollback is necessary.
                 */
                if (!fileExists('.deployment-attempted')) {
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
                     * ==========================================
                     * READ LAST STABLE VERSION
                     * ==========================================
                     */

                    def stableVersion = sh(
                        script: '''
                            cat /var/jenkins_home/last-stable-version 2>/dev/null || true
                        ''',
                        returnStdout: true
                    ).trim()

                    /*
                     * ==========================================
                     * CHECK STABLE VERSION
                     * ==========================================
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
                    echo "Current failed version: ${env.BUILD_NUMBER}"
                    echo "Rolling back to version ${stableVersion}..."

                    /*
                     * ==========================================
                     * ROLLBACK DEPLOYMENT
                     * ==========================================
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

                            echo "=========================================="
                            echo "Starting rollback"
                            echo "Rollback version: ${stableVersion}"
                            echo "=========================================="

                            APP_VERSION=${stableVersion} docker compose \
                                --env-file "\$ENV_FILE" \
                                -f compose.prod.yml \
                                up -d --force-recreate

                            echo "Rollback deployment completed."
                        """
                    }

                    /*
                     * ==========================================
                     * ROLLBACK HEALTH CHECK
                     * ==========================================
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
