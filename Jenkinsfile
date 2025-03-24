pipeline {

    environment {
        IMAGE_NAME = "ic-webapp"
        SONAR_TOKEN = credentials('sonarcloud')
        DOCKERHUB_CREDENTIALS = credentials('DOCKER_HUB')
        PORTAL_PRD = "ic-portal.training-dag.loc"
        PORTAL_TST = "ic-portal.tst.training-dag.loc"
        PORTAL_RVW = "ic-portal.rvw.training-dag.loc"
        DEPLOY_USER = "srvadm"
    }

    agent none

    stages{

        stage('BUILD') {
            agent any
            environment {
                IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt""", returnStdout: true)
                BranchName = sh(script: 'echo -n $BRANCH_NAME | sed \'s;/;_;g\'', returnStdout: true)
            }
            steps{
                script{
                    if (env.BRANCH_NAME == 'main') {
                        sh '''
                        sed -i '/^RVW/d' releases.txt
                        docker build -t $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG .
                        '''
                    } else {
                        sh '''
                        sed -i '/^RVW/,/^version/!d' releases.txt
                        sed -i s/"RVW_"/""/g releases.txt
                        docker build -t $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME-$BranchName:$IMAGE_TAG .
                        '''
                    }
                }
            }
        }

        stage('CODE QUALITY') {
            agent any
            environment {
                SNR_SCANNER = tool name: 'scanner'
                SONARCLD_ORG = "tealc-210"
                SONARCLD_PJ_KEY = "${SONARCLD_ORG}_final"
            }
            steps {
                withSonarQubeEnv('SonarCloud') {
                    sh '''
                    cd ./app-code/
                    ${SNR_SCANNER}/bin/sonar-scanner -Dsonar.organization=${SONARCLD_ORG} -Dsonar.projectKey=${SONARCLD_PJ_KEY} -Dsonar.sources=. -Dsonar.host.url=https://sonarcloud.io
                    '''

                }
            }
        }

        stage("QUALITY GATE") {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('TESTS') {
            agent any
            environment {
                IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt""", returnStdout: true)
                BranchName = sh(script: 'echo -n $BRANCH_NAME | sed \'s;/;_;g\'', returnStdout: true)
                ODOO_URL = sh(script: """awk '/ODOO/ {sub(/^.* *ODOO/, ""); print \$2}' releases.txt""", returnStdout: true)
                PGADMIN_URL = sh(script: """awk '/PGADMIN/ {sub(/^.* *PGADMIN/, ""); print \$2}' releases.txt""", returnStdout: true)
            }
            steps{
                script {
                      if (env.BRANCH_NAME == 'main') {
                          sh '''
                          docker run -d -p 80:8080 --name $IMAGE_NAME-$BranchName $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG
                          '''
                      } else {
                          sh '''
                          docker run -d -p 81:8080 --name $IMAGE_NAME-$BranchName $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME-$BranchName:$IMAGE_TAG
                          '''
                      }
                      sh 'sleep 10'
                      if (env.BRANCH_NAME == 'main') {
                          sh '''
                          curl -L http://$PORTAL_TST | grep "${ODOO_URL}"
                          curl -L http://$PORTAL_TST | grep "${PGADMIN_URL}"
                          '''
                      } else {
                          sh '''
                          curl -L http://$PORTAL_TST:81 | grep "${ODOO_URL}"
                          curl -L http://$PORTAL_TST:81 | grep "${PGADMIN_URL}"
                          '''
                      }
                      sh '''
                      docker stop $IMAGE_NAME-$BranchName
                      docker rm $IMAGE_NAME-$BranchName
                      '''
                }
            }
        }

        stage ('PACKAGE') {
            agent any
            environment {
              IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt""", returnStdout: true)
              BranchName = sh(script: 'echo -n $BRANCH_NAME | sed \'s;/;_;g\'', returnStdout: true)
            }
            steps {
                script {
                    if (env.BRANCH_NAME == 'main') {
                        sh '''
                        docker login -u $DOCKERHUB_CREDENTIALS_USR -p $DOCKERHUB_CREDENTIALS_PSW
                        docker push $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG
                        '''
                    } else {
                        sh '''
                        docker login -u $DOCKERHUB_CREDENTIALS_USR -p $DOCKERHUB_CREDENTIALS_PSW
                        docker push $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME-$BranchName:$IMAGE_TAG
                        '''
                    }
                }
            }
        }

        stage ('REVIEW/TEST') {
            agent any
            when {
                not {
                    branch 'main'
                    }
            }
            environment {
                DEPLOY_ENV = "${PORTAL_RVW}"
                IMAGE_TAG = sh(script: """echo -n \$(awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt)""", returnStdout: true)
                BranchName = sh(script: 'echo -n $BRANCH_NAME | sed \'s;/;_;g\'', returnStdout: true)
                ODOO = sh(script: """echo -n \$(awk '/RVW_ODOO/ {sub(/^.* *RVW_ODOO/, ""); print \$2}' releases.txt | sed \'s;http://;;\')""", returnStdout: true)
                PGADMIN = sh(script: """echo -n \$(awk '/RVW_PGADMIN/ {sub(/^.* *RVW_PGADMIN/, ""); print \$2}' releases.txt | sed \'s;http://;;\')""", returnStdout: true)

            }
            steps {
                sshagent(credentials: ['SSHKEY']) {
                    sh 'sed s/ODOOHOST/$ODOO/ IC_deploy/inventory/hosts.example | sed s/PGADMINHOST/$PGADMIN/ | sed s/SSHUSER/$DEPLOY_USER/ > IC_deploy/inventory/hosts'
                    ansiblePlaybook(
                    inventory: 'IC_deploy/inventory/hosts',
                    playbook: 'IC_deploy/deploy.yml')
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa,ed25519 ${DEPLOY_ENV} >> ~/.ssh/known_hosts
                        command1="docker login -u ${DOCKERHUB_CREDENTIALS_USR} -p ${DOCKERHUB_CREDENTIALS_PSW}"
                        command2="docker pull ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}-${BranchName}:${IMAGE_TAG}"
                        command3="docker ps -a | grep ${IMAGE_NAME}-${BranchName} && docker rm -f ${IMAGE_NAME}-${BranchName} || echo 'app does not exist'"
                        command4="docker run -d -p 80:8080 --name ${IMAGE_NAME}-${BranchName} ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}-${BranchName}:${IMAGE_TAG}"
                        ssh -t ${DEPLOY_USER}@${DEPLOY_ENV} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=BranchName \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_USR \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_PSW \
                            -C "$command1 && $command2 && $command3 && $command4 && sleep 10"
                    '''
                }

                sh '''
                    curl -L http://${DEPLOY_ENV} | grep "${ODOO}"
                    curl -L http://${DEPLOY_ENV} | grep "${PGADMIN}"
                    curl -L http://${ODOO}:8069 | grep "Warning, your Odoo database manager is not protected. To secure it, we have generated the following master password for it"
                    curl -L http://${PGADMIN}:8080 | grep "<title>pgAdmin 4</title>"
                '''
            }
        }

        stage ('PRODUCTION') {
            agent any
            when {
                branch 'main'
            }
            environment {
                DEPLOY_ENV = "${PORTAL_PRD}"
                IMAGE_TAG = sh(script: """echo -n \$(awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt)""", returnStdout: true)
                ODOO = sh(script: """echo -n \$(awk '/^ODOO/ {sub(/^.* *ODOO/, ""); print \$2}' releases.txt | sed \'s;http://;;\')""", returnStdout: true)
                PGADMIN = sh(script: """echo -n \$(awk '/^PGADMIN/ {sub(/^.* *PGADMIN/, ""); print \$2}' releases.txt | sed \'s;http://;;\')""", returnStdout: true)

            }
            steps {
                sshagent(credentials: ['SSHKEY']) {
                    sh 'sed s/ODOOHOST/$ODOO/ IC_deploy/inventory/hosts.example | sed s/PGADMINHOST/$PGADMIN/ | sed s/SSHUSER/$DEPLOY_USER/ > IC_deploy/inventory/hosts'
                    ansiblePlaybook(
                    inventory: 'IC_deploy/inventory/hosts',
                    playbook: 'IC_deploy/deploy.yml')
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa,ed25519 ${DEPLOY_ENV} >> ~/.ssh/known_hosts
                        command1="docker login -u ${DOCKERHUB_CREDENTIALS_USR} -p ${DOCKERHUB_CREDENTIALS_PSW}"
                        command2="docker pull ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:${IMAGE_TAG}"
                        command3="docker ps -a | grep ${IMAGE_NAME} && docker rm -f ${IMAGE_NAME} || echo 'app does not exist'"
                        command4="docker run -d -p 80:8080 --name ${IMAGE_NAME} ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}:${IMAGE_TAG}"
                        ssh -t ${DEPLOY_USER}@${DEPLOY_ENV} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_USR \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_PSW \
                            -C "$command1 && $command2 && $command3 && $command4 && sleep 10"
                    '''
                }

                sh '''
                    curl -L http://${DEPLOY_ENV} | grep "${ODOO}"
                    curl -L http://${DEPLOY_ENV} | grep "${PGADMIN}"
                    curl -L http://${ODOO}:8069 | grep "Warning, your Odoo database manager is not protected. To secure it, we have generated the following master password for it"
                    curl -L http://${PGADMIN}:8080 | grep "<title>pgAdmin 4</title>"
                '''
            }
        }
    }
    post {
        success {
            script {
                def message
                if (env.BRANCH_NAME == 'main') {
                  message = "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) - PROD URL => http://${PORTAL_PRD}"
                } else {
                    message = "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) - REVIEW URL => http://${PORTAL_RVW}"
                }
                slackSend(color: '#00FF00', message: message)
            }
        }
        failure {
            script {
                slackSend(color: '#FF0000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
            }
        }
    }
}
