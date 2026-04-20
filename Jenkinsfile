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
                  # 🔥 绝对能用的官方 kubectl 镜像！
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
        GITOPS_CONFIG_REPO = "git@github.com:your-org/gitops-config.git"
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
                    sh """
                        cd src
                        go test -v -race ./... -coverprofile=coverage.out
                        go tool cover -func=coverage.out
                    """
                }
            }
        }

        stage('🔍 代码安全扫描') {
            when { expression { params.RUN_TESTS } }
            steps {
                container('golang') {
                    script {
                        try {
                            sh 'cd src && go install golang.org/x/vuln/cmd/govulncheck@latest'
                            sh 'cd src && govulncheck ./...'
                        } catch (Exception e) {
                            echo "⚠️ 安全扫描发现漏洞，但不阻断构建: ${e.getMessage()}"
                        }
                    }
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

        stage('🛡️ 镜像安全扫描') {
            steps {
                container('docker') {
                    script {
                        try {
                            sh """
                                docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                                    aquasec/trivy:latest image --severity HIGH,CRITICAL \\
                                    --exit-code 0 \\
                                    ${IMAGE_NAME}:${IMAGE_TAG}
                            """
                        } catch (Exception e) {
                            echo "⚠️ 镜像扫描发现高危漏洞: ${e.getMessage()}"
                        }
                    }
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
                            def maxRetries = 3
                            def retryCount = 0
                            def pushSuccess = false
                            while (retryCount < maxRetries && !pushSuccess) {
                                try {
                                    sh """
                                        docker login ${params.IMAGE_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PWD}
                                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                                        docker push ${IMAGE_NAME}:latest
                                        docker logout ${params.IMAGE_REGISTRY}
                                    """
                                    pushSuccess = true
                                    echo "✅ 镜像推送成功 (尝试第${retryCount + 1}次)"
                                } catch (Exception e) {
                                    retryCount++
                                    if (retryCount >= maxRetries) {
                                        error("❌ 镜像推送失败，已达到最大重试次数")
                                    }
                                    echo "⚠️ 镜像推送失败，10秒后重试..."
                                    sleep 10
                                }
                            }
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

                                git clone ${GITOPS_CONFIG_REPO} gitops-config-tmp
                                cd gitops-config-tmp

                                yq eval ".spec.template.spec.containers[0].image = \\"${IMAGE_NAME}:${IMAGE_TAG}\\"" \\
                                    overlays/${params.DEPLOY_ENV}/deployment-patch.yaml -i

                                git config --global user.name "Jenkins CI"
                                git config --global user email "jenkins@company.com"
                                git add overlays/${params.DEPLOY_ENV}/deployment-patch.yaml
                                git commit -m "chore(deploy): update ${APP_NAME} to ${IMAGE_TAG} for ${params.DEPLOY_ENV}"

                                for i in 1 2 3; do
                                    if git push origin main; then
                                        echo "✅ Git 推送成功"
                                        break
                                    else
                                        sleep 5
                                        git pull --rebase origin main
                                    fi
                                done

                                cd .. && rm -rf gitops-config-tmp
                            """
                        }
                    }
                }
            }
        }

        stage('✅ 验证部署') {
            when { expression { !params.SKIP_DEPLOY } }
            steps {
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
                        script {
                            timeout(time: 5, unit: 'MINUTES') {
                                waitUntil {
                                    try {
                                        sh """
                                            mkdir -p ~/.kube
                                            cp ${KUBECONFIG_FILE} ~/.kube/config
                                            chmod 600 ~/.kube/config
                                            kubectl rollout status deployment/${APP_NAME} -n ${params.DEPLOY_ENV} --timeout=60s
                                        """
                                        return true
                                    } catch (Exception e) {
                                        return false
                                    }
                                }
                            }
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
