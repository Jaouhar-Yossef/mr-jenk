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
            script {
                withCredentials([
                    file(
                        credentialsId: 'production-env',
                        variable: 'ENV_FILE'
                    )
                ]) {
                    def recipients = sh(
                        script: '''
                            grep '^JENKINS_EMAIL_RECIPIENTS=' "$ENV_FILE" \
                            | cut -d '=' -f2-
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!recipients) {
                        error(
                            'JENKINS_EMAIL_RECIPIENTS is missing from production.env'
                        )
                    }

                    echo 'CI/CD pipeline completed successfully.'
                    echo "Stable version: ${env.BUILD_NUMBER}"

                    emailext(

                        subject:
                            "SUCCESS | ${env.JOB_NAME} | Build #${env.BUILD_NUMBER} | Version ${env.BUILD_NUMBER}",

                        body:
"""
JENKINS CI/CD - BUILD SUCCESSFUL

========================================
BUILD INFORMATION
========================================

Job:
${env.JOB_NAME}

Build Number:
#${env.BUILD_NUMBER}

Build Status:
SUCCESS

Application Version:
${env.BUILD_NUMBER}

Build Duration:
${currentBuild.durationString}

========================================
PIPELINE RESULTS
========================================

Checkout:
SUCCESS

Backend Tests:
SUCCESS

Frontend Tests:
SUCCESS

Docker Build:
SUCCESS

Deployment:
SUCCESS

Health Check:
SUCCESS

========================================
STABLE VERSION
========================================

Stable Version:
${env.BUILD_NUMBER}

This version has been successfully deployed
and verified by the health check.

It can be used for future automatic rollback.

========================================
JENKINS BUILD
========================================

Build URL:
${env.BUILD_URL}

Console Output:
${env.BUILD_URL}console

========================================
MESSAGE
========================================

The CI/CD pipeline completed successfully.

The application was tested, built, deployed,
and verified successfully.

This is an automated Jenkins notification.
""",

                        to: recipients
                    )
                }
            }
        }

        failure {
            script {
                def deploymentAttempted =
                    fileExists('.deployment-attempted')

                def rollbackStatus =
                    'Not required'

                def stableVersion =
                    'Unknown'

                if (fileExists('/var/jenkins_home/last-stable-version')) {
                    stableVersion =
                        readFile(
                            '/var/jenkins_home/last-stable-version'
                        ).trim()
                }

                if (!deploymentAttempted) {
                    echo 'Pipeline failed before deployment.'
                    echo 'No rollback required.'

                    rollbackStatus =
                        'Not required - deployment was not attempted.'
                } else {
                    echo 'Deployment failed.'
                    echo 'Starting automatic rollback...'

                    try {
                        withCredentials([
                            file(
                                credentialsId: 'production-env',
                                variable: 'ENV_FILE'
                            )
                        ]) {
                            sh './scripts/rollback.sh'

                            sh './scripts/rollback-health-check.sh'
                        }

                        rollbackStatus =
                            'SUCCESS - previous stable version restored.'

                        echo 'Rollback completed successfully.'
                    }

                    catch (Exception rollbackError) {
                        rollbackStatus =
                            'FAILED - automatic rollback failed.'

                        echo 'Automatic rollback failed.'

                        echo "Rollback error: ${rollbackError}"
                    }
                }

                withCredentials([
                    file(
                        credentialsId: 'production-env',
                        variable: 'ENV_FILE'
                    )
                ]) {
                    def recipients = sh(
                        script: '''
                            grep '^JENKINS_EMAIL_RECIPIENTS=' "$ENV_FILE" \
                            | cut -d '=' -f2-
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!recipients) {
                        error(
                            'JENKINS_EMAIL_RECIPIENTS is missing from production.env'
                        )
                    }

                    emailext(

                        subject:
                            "FAILURE | ${env.JOB_NAME} | Build #${env.BUILD_NUMBER}",

                        body:
"""
JENKINS CI/CD - BUILD FAILED

========================================
BUILD INFORMATION
========================================

Job:
${env.JOB_NAME}

Build Number:
#${env.BUILD_NUMBER}

Build Status:
FAILURE

Application Version:
${env.BUILD_NUMBER}

Build Duration:
${currentBuild.durationString}

========================================
DEPLOYMENT INFORMATION
========================================

Deployment Attempted:
${deploymentAttempted ? 'YES' : 'NO'}

Previous Stable Version:
${stableVersion}

========================================
ROLLBACK INFORMATION
========================================

Rollback Status:
${rollbackStatus}

========================================
IMPORTANT
========================================

The Jenkins CI/CD pipeline failed.

If deployment was attempted, Jenkins
automatically tried to restore the previous
stable version.

Please check the Jenkins console output
to identify the exact failed stage and
the reason for the failure.

========================================
JENKINS BUILD
========================================

Build URL:
${env.BUILD_URL}

Console Output:
${env.BUILD_URL}console

========================================
ACTION REQUIRED
========================================

Please review the failed build.

If rollback was successful, the previous
stable version has been restored.

If rollback failed, manual intervention
may be required.

This is an automated Jenkins notification.
""",

                        to: recipients
                    )
                }
            }
        }

        always {
            echo 'Pipeline finished.'
        }
    }
}
