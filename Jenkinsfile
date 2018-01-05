pipeline {
    agent any 

    environment {
        BASE_IMAGE="nginx:latest"
        TARGET_IMAGE="hleb/nginx-letsencrypt"
        GIT_TAG="$GIT_COMMIT".take(8)
        TARGET_IMAGE_TAG="$TARGET_IMAGE:git_$GIT_TAG"
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
                      set -e 
                      BRANCH_TAG=$(echo "$GIT_BRANCH" | grep -o '[^/]*$')
                      for extra_tag in $BRANCH_TAG latest ; do 
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
