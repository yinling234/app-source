pipeline {
    agent {
        kubernetes {
            yaml """
                apiVersion: v1
                kind: Pod
                spec:
                  tolerations:
                  - key: node-role.kubernetes.io/control-plane
                    operator: Exists
                    effect: NoSchedule
                  containers:
                  - name: golang
                    image: golang:1.21-alpine
                    command: ['cat']
                    tty: true
                    resources:
                      requests:
                        cpu: 100m
                        memory: 256Mi
                      limits:
                        cpu: 500m
                        memory: 512Mi
                  - name: docker
                    image: docker:24.0.7-dind
                    command: ['cat']
                    tty: true
                    privileged: true
                    resources:
                      requests:
                        cpu: 100m
                        memory: 256Mi
                      limits:
                        cpu: 500m
                        memory: 512Mi
                  - name: kubectl
                    image: alpine/k8s:1.28.0
                    command: ['sleep', 'infinity']
                    tty: true
                    resources:
                      requests:
                        cpu: 50m
                        memory: 128Mi
                      limits:
                        cpu: 200m
                        memory: 256Mi
            """
        }
    }

    options {
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    parameters {
        string(name: 'APP_VERSION', defaultValue: 'v1.0.0', description: '应用版本号')
        string(name: 'IMAGE_REGISTRY', defaultValue: '192.168.30.11:30002', description: '镜像仓库地址')
        choice(name: 'DEPLOY_ENV', choices: ['dev', 'staging', 'prod'], description: '部署环境')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: '是否运行单元测试')
        booleanParam(name: 'SKIP_DEPLOY', defaultValue: false, description: '是否跳过部署')
    }

    environment {
        APP_NAME = 'myapp'
        IMAGE_NAME = "${params.IMAGE_REGISTRY}/library/${APP_NAME}"
        IMAGE_TAG = "${params.APP_VERSION}-${env.BUILD_NUMBER}"
        GITOPS_CONFIG_REPO = "git@github.com:yinling234/app-source.git"
        COMMIT_HASH = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        BUILD_TIME = sh(script: 'date -u +"%Y-%m-%dT%H:%M:%SZ"', returnStdout: true).trim()
    }

    stages {
        stage('📥 代码检出') {
            steps {
                checkout scm
                echo "✅ 代码检出完成，Commit: ${env.COMMIT_HASH}"
            }
        }

        stage('🧪 单元测试') {
            when { expression { params.RUN_TESTS } }
            steps {
                container('golang') {
                    sh '''
                        cd src
                        CGO_ENABLED=0 go test -v ./... -coverprofile=coverage.out
                    '''
                }
            }
        }

        stage('🔨 构建镜像') {
            steps {
                container('docker') {
                    sh """
                        docker build \\
                          --build-arg VERSION=${params.APP_VERSION} \\
                          --build-arg BUILD_TIME=${env.BUILD_TIME} \\
                          --build-arg COMMIT_HASH=${env.COMMIT_HASH} \\
                          -t ${IMAGE_NAME}:${IMAGE_TAG} \\
                          -t ${IMAGE_NAME}:latest .
                    """
                }
            }
        }

        stage('📤 推送镜像') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(
                        credentialsId: 'harbor-credentials',
                        usernameVariable: 'HARBOR_USER',
                        passwordVariable: 'HARBOR_PWD'
                    )]) {
                        script {
                            sh """
                                docker login ${params.IMAGE_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PWD}
                                docker push ${IMAGE_NAME}:${IMAGE_TAG}
                                docker push ${IMAGE_NAME}:latest
                                docker logout ${params.IMAGE_REGISTRY}
                            """
                        }
                    }
                }
            }
        }

        stage('📝 更新 GitOps 配置') {
            when { expression { !params.SKIP_DEPLOY } }
            steps {
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
                        withCredentials([sshUserPrivateKey(
                            credentialsId: 'git-ssh-key',
                            keyFileVariable: 'GIT_KEY'
                        )]) {
                            sh """
                                mkdir -p ~/.kube
                                cp ${KUBECONFIG_FILE} ~/.kube/config
                                chmod 600 ~/.kube/config

                                mkdir -p ~/.ssh
                                cp ${GIT_KEY} ~/.ssh/id_rsa
                                chmod 600 ~/.ssh/id_rsa
                                echo -e "Host *\\n\\tStrictHostKeyChecking no\\n\\tUserKnownHostsFile /dev/null" > ~/.ssh/config

                                git clone ${GITOPS_CONFIG_REPO} gitops-config-tmp || true
                                cd gitops-config-tmp
                                git pull
                            """
                        }
                    }
                }
            }
        }

    }

    post {
        success { echo "🎉 流水线执行成功！" }
        failure { echo "❌ 流水线执行失败！" }
    }
}
