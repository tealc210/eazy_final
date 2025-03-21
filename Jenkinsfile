pipeline {

/*
CODE QUALITY
PACKAGE
REVIEW TEST
PROD
*/

    environment {
        IMAGE_NAME = "ic-webapp"
        SONAR_TOKEN = credentials('sonarcloud')
        DOCKERHUB_CREDENTIALS = credentials('DOCKER_HUB')
        PORTAL_PRD = "ic-portal.training-dag.loc"
        PORTAL_TST = "ic-portal.tst.training-dag.loc"
        PORTAL_RVW = "ic-portal.rvw.training-dag.loc"
        DEPLOY_USER = "srvadm"
        ODOO_RVW = "ic-odoo.rvw.training-dag.loc"
        PGADMIN_RVW = "ic-pgadmin.rvw.training-dag.loc"
    }

    agent none

    stages{

        stage('Build IC image') {
            agent any
            environment {
                IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt""", returnStdout: true)
                BranchName = sh(script: 'echo -n $BRANCH_NAME | sed \'s;/;_;g\'', returnStdout: true)
            }
            steps{
                script{
                    if (env.BRANCH_NAME == 'main') {
                        sh '''
                        docker build -t $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG .
                        '''
                    } else {
                        sh '''
                        docker build -t $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME-$BranchName:$IMAGE_TAG .
                        '''
                    }
                }
            }
        }

        /*stage('Scan') {
            agent any
            environment {
                JAVA17 = tool name: 'java17'
                SONARCLD_ORG = "tealc-210"
                SONARCLD_PJ_KEY = "${SONARCLD_ORG}_jenkins"
            }
            steps {
                withSonarQubeEnv('SonarCloud') {
                    sh '''
                    export JAVA_HOME="$JAVA17"
                    cd ./app_code/
                    mvn verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar -Dsonar.organization=${SONARCLD_ORG} -Dsonar.projectKey=${SONARCLD_PJ_KEY}
                    '''

                }
            }
        }

        stage("Quality Gate") {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }*/

        stage('Deploy and test portal') {
            agent any
            environment {
                IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt""", returnStdout: true)
                BranchName = sh(script: 'echo -n $BRANCH_NAME | sed \'s;/;_;g\'', returnStdout: true)
                ODOO_URL = sh(script: """awk '/ODOO/ {sub(/^.* *ODOO/, ""); print \$2}' releases.txt""", returnStdout: true)
                PGADMIN_URL = sh(script: """awk '/PGADMIN/ {sub(/^.* *PGADMIN/, ""); print \$2}' releases.txt""", returnStdout: true)
            }
            steps{
                script {
                    /*sh '''
                    sed s/ODOOIP/$ODOO_TST/ IC_deploy/inventory/hosts.example | sed s/PGADMINIP/$PGADMIN_TST/ | sed s/SSHUSER/$DEPLOY_USER/ > IC_deploy/inventory/hosts
                    '''*/
                    //sshagent(credentials: ['SSHKEY']) {
                      if (env.BRANCH_NAME == 'main') {
                          /*ansiblePlaybook(
                          inventory: 'IC_deploy/inventory/hosts',
                          playbook: 'IC_deploy/deploy.yml')*/
                          sh '''
                          docker run -d -p 80:8080 --name $IMAGE_NAME-$BranchName $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG
                          '''
                      } else {
                          /*ansiblePlaybook(
                          inventory: 'IC_deploy/inventory/hosts',
                          playbook: 'IC_deploy/deploy.yml')*/
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
                    //}
                }
            }
        }

        stage ('Push generated image on docker hub') {
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

        stage ('Deploy to Review Env') {
            agent any
            when {
                not {
                    branch 'main'
                    }
            }
            environment {
                DEPLOY_ENV = "${PORTAL_RVW}"
                IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt""", returnStdout: true)
                BranchName = sh(script: 'echo -n $BRANCH_NAME | sed \'s;/;_;g\'', returnStdout: true)
            }
            steps {
                sh 'sed s/ODOOHOST/$ODOO_RVW/ IC_deploy/inventory/hosts.example | sed s/PGADMINHOST/$PGADMIN_RVW/ | sed s/SSHUSER/$DEPLOY_USER/ > IC_deploy/inventory/hosts'
                ansiblePlaybook(
                inventory: 'IC_deploy/inventory/hosts',
                playbook: 'IC_deploy/deploy.yml')

                sshagent(credentials: ['SSHKEY']) {
                    sh 'sed s/ODOOHOST/$ODOO_RVW/ IC_deploy/inventory/hosts.example | sed s/PGADMINHOST/$PGADMIN_RVW/ | sed s/SSHUSER/$DEPLOY_USER/ > IC_deploy/inventory/hosts'
                    ansiblePlaybook(
                    inventory: 'IC_deploy/inventory/hosts',
                    playbook: 'IC_deploy/deploy.yml')
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0600 ~/.ssh
                        ssh-keyscan -t rsa,dsa,ed25519 ${DEPLOY_ENV} >> ~/.ssh/known_hosts
                        command1="docker login -u ${DOCKERHUB_CREDENTIALS_USR} -p ${DOCKERHUB_CREDENTIALS_PSW}"
                        command2="docker pull ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}-${BranchName}:${IMAGE_TAG}"
                        command3="docker ps -a | grep ${IMAGE_NAME}-${BranchName} && docker rm -f ${IMAGE_NAME}-${BranchName} || echo 'app does not exist'"
                        command4="docker run -d -p 80:8080 -e ODOO_URL='${ODOO_RVW}' -e PGADMIN_URL='${PGADMIN_RVW}' ${IMAGE_NAME}-${BranchName} ${DOCKERHUB_CREDENTIALS_USR}/${IMAGE_NAME}-${BranchName}:${IMAGE_TAG}"
                        ssh -t ${SSHUSER}@${DEPLOY_ENV} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=BranchName \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_USR \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_PSW \
                            -C "$command1 && $command2 && $command3 && $command4 && sleep 10"
                    '''
                }

                sh '''
                    curl -L http://${DEPLOY_ENV} | grep "${ODOO_RVW}"
                    curl -L http://${DEPLOY_ENV} | grep "${PGADMIN_RVW}"
                    curl -L http://${ODOO_RVW}:8069 | grep "body"
                    curl -L http://${PGADMIN_RVW}:8080 | grep "You must sign in to view this resource"
                '''
            }
        }

        /*stage ('Deploy to Prod Env') {
            agent any
            when {
                branch 'main'
            }
            environment {
                DEPLOY_ENV = "${ENV_PRD}"
                DB_HOST = "${DB_HOST_PRD}"
                DB_CREDS = credentials('DB_CREDS')
            }
            steps {
                sshagent(credentials: ['SSHKEY']) {
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa,ed25519 ${DEPLOY_ENV} >> ~/.ssh/known_hosts
                        command1="docker login -u $DOCKERHUB_CREDENTIALS_USR -p $DOCKERHUB_CREDENTIALS_PSW"
                        command2="docker pull $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG"
                        command3="docker ps -a | grep $IMAGE_NAME && docker rm -f $IMAGE_NAME || echo 'app does not exist'"
                        command4="docker run -d -p 80:8080 -e SPRING_DATASOURCE_USERNAME='${DB_CREDS_USR}' -e SPRING_DATASOURCE_PASSWORD='${DB_CREDS_PSW}' -e SPRING_DATASOURCE_URL='jdbc:mysql://${DB_HOST}:3306/db_paymybuddy' --name $IMAGE_NAME $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG"
                        ssh -t ubuntu@${DEPLOY_ENV} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_USR \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_PSW \
                            -C "$command1 && $command2 && $command3 && $command4 && sleep 30"
                    '''
                }
            }
        }

        stage('Check Prod deployed application') {
            agent any
            when {
                branch 'main'
            }
            steps{
                sh 'curl -L http://$ENV_PRD | grep "Pay My Buddy button"'
            }
        }*/

    }
    /*post {
        success {
            script {
                def message
                if (env.BRANCH_NAME == 'main') {
                  message = "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) - PROD URL => http://${ENV_PRD}"
                } else {
                    message = "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) - STAGING URL => http://${ENV_STG}"
                }
                slackSend(color: '#00FF00', message: message)
            }
        }
        failure {
            script {
                slackSend(color: '#FF0000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
            }
        }
    }*/
}
