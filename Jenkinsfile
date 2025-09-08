pipeline {
    agent { label 'JAgent-Node' }

    environment {
        APP_NAME               = "frontend-app"
        RELEASE                = "1.0.0"
        IMAGE_TAG              = "${RELEASE}-${BUILD_NUMBER}"
        DOCKERHUB_USER         = "registry2002"
        DOCKERHUB_REPO         = "ecomm"
        ACR_NAME               = "eocmm"
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
                dir('.') {
                    sh '''
                      set -e
                      # Build Docker image using Dockerfile from repo root
                      docker build -t ${APP_NAME}:${IMAGE_TAG} .
                      docker images | grep ${APP_NAME}
                    '''
                }
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
                      az account set --subscription 72d81257-1d17-40e1-89f6-ce5a59e7956f
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
                      az account set --subscription 72d81257-1d17-40e1-89f6-ce5a59e7956f
                      az storage blob upload --account-name ${AZURE_STORAGE_ACCOUNT} \
                                             --container-name ${AZURE_CONTAINER} \
                                             --file ${APP_NAME}-${IMAGE_TAG}.zip \
                                             --name ${APP_NAME}-${IMAGE_TAG}.zip \
                                             --auth-mode login
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
                        name: frontend-app
                      spec:
                        replicas: 2
                        selector:
                          matchLabels:
                            app: frontend-app
                        template:
                          metadata:
                            labels:
                              app: frontend-app
                          spec:
                            containers:
                            - name: frontend-app
                              image: ${ACR_NAME}.azurecr.io/${APP_NAME}:${IMAGE_TAG}
                              imagePullPolicy: Always
                              ports:
                              - containerPort: 3000
                      ---
                      apiVersion: v1
                      kind: Service
                      metadata:
                        name: ecommerce-service
                      spec:
                        type: LoadBalancer
                        selector:
                          app: frontend-app
                        ports:
                        - protocol: TCP
                          port: 80
                          targetPort: 3000
                      EOF

                      kubectl apply -f ecomm-deployment.yaml
                      # Force pods to restart with new image
                     kubectl rollout restart deployment/frontend-app
                     kubectl rollout status deployment/frontend-app

                     echo "===== Pod Status ====="
                     kubectl get pods -l app=frontend-app -o wide

                    echo "===== Pod Description ====="
                    kubectl describe pod $(kubectl get pods -l app=frontend-app -o jsonpath='{.items[0].metadata.name}')

                    echo "===== Pod Logs ====="
                    kubectl logs $(kubectl get pods -l app=frontend-app -o jsonpath='{.items[0].metadata.name}')
                      
                    '''
                }
            }
        }
    }
}
