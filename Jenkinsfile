pipeline {
    agent any 

    environment {
        BASE_IMAGE="nginx:latest"
        TARGET_IMAGE="hleb/nginx-letsencrypt"
        TARGET_IMAGE_TAG=$TARGET_IMAGE:git_$GIT_COMMIT
    }

    stages {
        stage('Pull') {
            sh 'docker pull $BASE_IMAGE'
        }
        stage('Build') {
            sh 'docker build -t $TARGET_IMAGE_TAG .'
        }
        stage('Tag') {
            sh 'for extra tag in $GIT_BRANCH latest ; do docker tag $TARGET_IMAGE_TAG $TARGET_IMAGE:$tag ; done '
        }
        stage('Push') {
            sh 'docker push $TARGET_IMAGE'
        }
    }
}
