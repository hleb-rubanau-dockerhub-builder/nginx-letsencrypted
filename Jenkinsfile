pipeline {
    agent any 

    environment {
        BASE_IMAGE="nginx:latest"
        TARGET_IMAGE="hleb/nginx-letsencrypt"

        DEFAULT_TAG='latest'
        GIT_TAG="$GIT_COMMIT".take(8)

        TARGET_REGISTRY="$PRIVATE_REGISTRY_HOSTNAME"
        PRIVATE_REGISTRY_URL ="$TARGET_REGISTRY:$PRIVATE_REGISTRY_PORT"

        // convention
        REGISTRY_CREDENTIALS_ID="$TARGET_REGISTRY"

        TARGET_IMAGE_TAG="$TARGET_IMAGE:git_$GIT_TAG"
    }

    stages {
        stage('Build') {
            steps {
                sh 'docker pull $BASE_IMAGE'

                script {
                    newimage = docker.build(env.TARGET_IMAGE_TAG)

                    withDockerRegistry([credentialsId: env.REGISTRY_CREDENTIALS_ID, url: "https://"+env.PRIVATE_REGISTRY_URL]) {
                        newimage.push('latest')
                        newimage.push(env.GIT_TAG)
                        newimage.push(env.BRANCH_TAG)
                    }
                }

            }
        }
    }
}
