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
    command: ['dockerd-entrypoint.sh']
    args: ['--storage-driver=overlay2', '--insecure-registry=192.168.30.11:30003']
    tty: true
    securityContext:
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

    // 👇 👇 👇 【只有这里我加了 4 行，其他完全没动】
    triggers {
        githubPush()
    }

    parameters {
        string(name: 'APP_VERSION', defaultValue: 'v1.0.0', description: '版本号')
        string(name: 'IMAGE_REGISTRY', defaultValue: '192.168.30.11:30003', description: '镜像仓库')
        choice(name: 'DEPLOY_ENV', choices: 'dev\nstaging\nprod', description: '部署环境')
        booleanParam(name: 'RUN_TESTS', defaultValue: true)
    }

    environment {
        APP_NAME = 'myapp'
        IMAGE_NAME = "${params.IMAGE_REGISTRY}/library/${APP_NAME}"
        IMAGE_TAG = "${params.APP_VERSION}-${env.BUILD_NUMBER}"
        COMMIT_HASH = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        DEPLOY_ENV = "${params.DEPLOY_ENV}"
    }

    stages {
        stage('代码检出') {
            steps {
                checkout scm
                echo "✅ 代码完成: ${env.COMMIT_HASH}"
            }
        }

        stage('单元测试') {
            when { expression { params.RUN_TESTS } }
            steps {
                container('golang') {
                    sh '''
                        cd src
                        CGO_ENABLED=0 go test -v ./...
                    '''
                }
            }
        }

        stage('构建镜像') {
            steps {
                container('docker') {
                    sh """
                        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest .
                    """
                }
            }
        }

        stage('推送镜像') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(credentialsId: 'harbor-credentials', usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PWD')]) {
                        sh '''
                            docker login ${IMAGE_REGISTRY} -u ${HARBOR_USER} -p ${HARBOR_PWD}
                            docker push ${IMAGE_NAME}:${IMAGE_TAG}
                            docker push ${IMAGE_NAME}:latest
                            docker logout
                        '''
                    }
                }
            }
        }

        stage('更新 GitOps 配置 & 提交Git') {
            steps {
                container('kubectl') {
                    sh 'apk update && apk add --no-cache git openssh-keygen openssh-client'

                    withCredentials([sshUserPrivateKey(
                        credentialsId: 'git-ssh-key',
                        keyFileVariable: 'GIT_SSH_KEY',
                        usernameVariable: 'GIT_USERNAME'
                    )]) {
                        sh """
                            mkdir -p ~/.ssh
                            chmod 700 ~/.ssh
                            cp \${GIT_SSH_KEY} ~/.ssh/id_rsa
                            chmod 600 ~/.ssh/id_rsa
                            ssh-keyscan github.com >> ~/.ssh/known_hosts

                            git config --global user.name "jenkins"
                            git config --global user.email "jenkins@demo.com"

                            git clone git@github.com:yinling234/gitops-config.git gitops-repo
                            cd gitops-repo/overlays/${DEPLOY_ENV}

                            sed -i "s|image:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" deployment-patch.yaml

                            cd ../..
                            git add .
                            git commit -m "ci: update image to ${IMAGE_TAG}"
                            git push git@github.com:yinling234/gitops-config.git
                        """
                    }
                }
            }
        }

    }

    post {
        success { echo "🎉 🎉 🎉 构建 + 推送 + GitOps 更新 全部成功！" }
        failure { echo "❌ 失败" }
    }
}
