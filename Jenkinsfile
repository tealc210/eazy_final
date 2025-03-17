pipeline {

/*
BUILD
CODE QUALITY
TESTS
PACKAGE
REVIEW TEST
PROD
*/

    environment {
        IMAGE_NAME = "ic-webapp"
        //IMAGE_TAG = "latest"
        SONAR_TOKEN = credentials('sonarcloud')
        SRVKEY = credentials('SSHKEY')
        DOCKERHUB_CREDENTIALS = credentials('DOCKER_HUB')
        ENV_PRD = "eazy-prd.agbo.fr"
        ENV_STG = "eazy-stg.agbo.fr"
        ODOO_TST = "172.17.0.1"
        PGADMIN_TST = "172.17.0.1"
        ODOO_RVW = "172.17.0.1"
        PGADMIN_RVW = "172.17.0.1"
        DB_HOST_STG = "172.31.28.19"
        DB_HOST_PRD = "172.31.80.69"
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
                MVN3 = tool name: 'mvn3'
                JAVA17 = tool name: 'java17'
                SONARCLD_ORG = "tealc-210"
                SONARCLD_PJ_KEY = "${SONARCLD_ORG}_jenkins"
            }
            steps {
                withSonarQubeEnv('SonarCloud') {
                    sh '''
                    export PATH="${PATH}:${MVN3}/bin"
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

        stage('Run generated image in container') {
            agent any
            environment {
                IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' releases.txt""", returnStdout: true)
            }
            steps{
                script {
                    sh 'echo $SRVKEY > .prvkey && chmod 600 .prvkey'
                    if (env.BRANCH_NAME == 'main') {
                        ansiblePlaybook(
                        //credentialsId: 'private_key',
                        inventory: 'IC_deploy/inventory/inventory.ini',
                        playbook: 'IC_deploy/deploy.yml')
                        sh '''
                        docker run -d -p 80:8080 --name $IMAGE_NAME-$BranchName $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME:$IMAGE_TAG
                        sleep 30
                        '''
                    } else {
                        ansiblePlaybook(
                        //credentialsId: 'private_key',
                        inventory: 'IC_deploy/inventory/inventory.ini',
                        playbook: 'IC_deploy/deploy.yml')
                        sh '''
                        docker run -d -p 81:8080 --add-host --add-host --name $IMAGE_NAME-$BranchName $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME-$BranchName:$IMAGE_TAG
                        sleep 30
                        '''
                    }
                    sh 'rm .prvkey'
                }
            }
        }

        stage('Check application') {
            agent any
            steps{
                script {
                    if (env.BRANCH_NAME == 'main') {
                        sh 'curl -L http://$ENV_TST | grep "odoo"'
                    } else {
                        sh 'curl -L http://$ENV_TST:81 | grep "odoo"'
                    }
                }
            }
        }

        /*stage('Cleanup') {
            agent any
            steps{
                script {
                    sh '''
                    docker stop $IMAGE_NAME-$BranchName mysql-$BranchName
                    docker rm -v $IMAGE_NAME-$BranchName mysql-$BranchName
                    docker volume rm sql-$BranchName
                    '''
                }
            }
        }

        stage ('Push generated image on docker hub') {
            agent any
            environment {
                IMAGE_TAG = sh(script: """awk '/version/ {sub(/^.* *version/, ""); print \$2}' /tmp/releases.txt""", returnStdout: true)
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

        stage ('Deploy to Staging Env') {
            agent any
            when {
                not {
                    branch 'main'
                    }
            }
            environment {
                DEPLOY_ENV = "${ENV_STG}"
                DB_HOST = "${DB_HOST_STG}"
                DB_CREDS = credentials('DB_CREDS')
            }
            steps {
                sshagent(credentials: ['SSHKEY']) {
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa,ed25519 ${DEPLOY_ENV} >> ~/.ssh/known_hosts
                        command1="docker login -u $DOCKERHUB_CREDENTIALS_USR -p $DOCKERHUB_CREDENTIALS_PSW"
                        command2="docker pull $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME-$BranchName:$IMAGE_TAG"
                        command3="docker ps -a | grep $IMAGE_NAME-$BranchName && docker rm -f $IMAGE_NAME-$BranchName || echo 'app does not exist'"
                        command4="docker run -d -p 80:8080 -e SPRING_DATASOURCE_USERNAME='${DB_CREDS_USR}' -e SPRING_DATASOURCE_PASSWORD='${DB_CREDS_PSW}' -e SPRING_DATASOURCE_URL='jdbc:mysql://${DB_HOST}:3306/db_paymybuddy' --name $IMAGE_NAME-$BranchName $DOCKERHUB_CREDENTIALS_USR/$IMAGE_NAME-$BranchName:$IMAGE_TAG"
                        ssh -t ubuntu@${DEPLOY_ENV} \
                            -o SendEnv=IMAGE_NAME \
                            -o SendEnv=BranchName \
                            -o SendEnv=IMAGE_TAG \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_USR \
                            -o SendEnv=DOCKERHUB_CREDENTIALS_PSW \
                            -C "$command1 && $command2 && $command3 && $command4 && sleep 30"
                    '''
                }
            }
        }

        stage('Check staging deployed application') {
            agent any
            when {
                not {
                    branch 'main'
                    }
            }
            steps{
                sh 'curl -L http://$ENV_STG | grep "Pay My Buddy button"'
            }
        }

        stage ('Deploy to Prod Env') {
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
