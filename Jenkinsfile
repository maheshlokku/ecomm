pipeline {
    agent { label 'JAgent-Node' }

    environment {
        APP_NAME               = "ecomm"
        RELEASE                = "1.0.0"
        IMAGE_TAG              = "${RELEASE}-${BUILD_NUMBER}"
        DOCKERHUB_USER         = "registry2002"
        DOCKERHUB_REPO         = "ecomm"
        ACR_NAME               = "eocmm.azurecr.io"
        AZURE_STORAGE_ACCOUNT  = "ecommstr"
        AZURE_CONTAINER        = "ecommctr"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/maheshlokku/ecomm.git'
            }
        }

        stage('Build SCSS') {
            steps {
                nodejs(nodeJSInstallationName: 'Node18') {
                    sh '''
                      set -e
                      npm install -g sass
                      mkdir -p css
                      sass scss:css --no-source-map
                    '''
                }
            }
        }

        stage('Package Artifacts') {
            steps {
                sh '''
                  set -e
                  mkdir -p build
                  cp -r css fonts img js *.html style.css build/
                  echo "Contents of build folder:"
                  ls -l build
                  zip -r ${APP_NAME}-${IMAGE_TAG}.zip build
                '''
            }
            post {
                success {
                    archiveArtifacts artifacts: '*.zip', fingerprint: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                  set -e
                  # Build Docker image using Dockerfile from repo
                  docker build -t ${APP_NAME}:${IMAGE_TAG} .
                  docker images | grep ${APP_NAME}
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'ecommhub-token', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                      set -e
                      echo "$PASS" | docker login -u "$USER" --password-stdin
                      docker tag ${APP_NAME}:${IMAGE_TAG} ${DOCKERHUB_USER}/${DOCKERHUB_REPO}:${IMAGE_TAG}
                      docker push ${DOCKERHUB_USER}/${DOCKERHUB_REPO}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('Push to Azure Container Registry (ACR)') {
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'ecomm-azctry')]) {
                    sh '''
                      set -e
                      az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
                      az acr login --name ${ACR_NAME}
                      docker tag ${APP_NAME}:${IMAGE_TAG} ${ACR_NAME}.azurecr.io/${APP_NAME}:${IMAGE_TAG}
                      docker push ${ACR_NAME}.azurecr.io/${APP_NAME}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('Upload Zip to Azure Blob Storage') {
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'ecomm-azctry')]) {
                    sh '''
                      set -e
                      az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
                      az storage blob upload --account-name ${AZURE_STORAGE_ACCOUNT} \
                                             --container-name ${AZURE_CONTAINER} \
                                             --file ${APP_NAME}-${IMAGE_TAG}.zip \
                                             --name ${APP_NAME}-${IMAGE_TAG}.zip
                    '''
                }
            }
        }

        stage('Deploy to AKS') {
            steps {
                withCredentials([azureServicePrincipal(credentialsId: 'aks-json-key')]) {
                    sh '''
                      set -e
                      az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
                      az aks get-credentials --resource-group datavalley_resource_groups --name crm-clstr --overwrite-existing

                      cat > ecomm-deployment.yaml <<EOF
                      apiVersion: apps/v1
                      kind: Deployment
                      metadata:
                        name: ecommerce-deployment
                      spec:
                        replicas: 2
                        selector:
                          matchLabels:
                            app: ecommerce
                        template:
                          metadata:
                            labels:
                              app: ecommerce
                          spec:
                            containers:
                            - name: ecommerce
                              image: ${ACR_NAME}.azurecr.io/${APP_NAME}:${IMAGE_TAG}
                              ports:
                              - containerPort: 80
                      ---
                      apiVersion: v1
                      kind: Service
                      metadata:
                        name: ecommerce-service
                      spec:
                        type: LoadBalancer
                        selector:
                          app: ecommerce
                        ports:
                        - protocol: TCP
                          port: 80
                          targetPort: 80
                      EOF

                      kubectl apply -f ecomm-deployment.yaml
                    '''
                }
            }
        }
    }
}
