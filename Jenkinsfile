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
        REGISTRY_CREDENTIALS_ID=$TARGET_REGISTRY

        TARGET_IMAGE_TAG="$TARGET_IMAGE:git_$GIT_TAG"
    }

    stages {
        stage('Build') {
            steps {
                sh 'docker pull $BASE_IMAGE'

                newimage = docker.build($TARGET_IMAGE_TAG)

                withDockerRegistry([credentialsId: env.REGISTRY_CREDENTIALS_ID, url: "https://$PRIVATE_REGISTRY_URL"']) {
                    newimage.push('latest')
                    newimage.push("$GIT_TAG")
                    newimage.push("$BRANCH_TAG")
                }

            }
        }
    }
}
