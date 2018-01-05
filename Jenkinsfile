pipeline {
    agent any 

    environment {
        BASE_IMAGE="nginx:latest"
        TARGET_IMAGE="hleb/nginx-letsencrypt"
        TARGET_IMAGE_TAG="$TARGET_IMAGE:git_$GIT_COMMIT"
    }

    stages {
        stage('Build') {
            steps {
                sh 'docker pull $BASE_IMAGE'
                sh 'docker build -t $TARGET_IMAGE_TAG .'
            }
        }
        stage('Tag') {
            steps {
                sh '''#!/bin/bash
                      for extra_tag in $GIT_BRANCH latest ; do 
                         docker tag $TARGET_IMAGE_TAG $TARGET_IMAGE:$extra_tag ;
                      done 
                   '''
            }
        }
        stage('Push') {
            steps {
                sh 'docker push $TARGET_IMAGE'
            }
        }
    }
}
