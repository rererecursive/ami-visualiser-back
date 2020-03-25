
pipeline {
  environment {
    APPLICATION = 'web'
    REGION      = 'ap-southeast-2'
    S3_BUCKET   = 'ztlewis-builds'
    S3_PREFIX   = 'packer-builds'
  }

  agent {
    node {
      label 'docker'
    }
  }

  stages {
    stage('Build Image') {
      steps {
        sh "make build"
      }
    }

    stage('Gather Information') {
      parallel {
        stage('Source AMI Details') {
          steps {
            sh "make get-produced-ami"
          }
        }
        stage('Produced AMI Details') {
          steps {
            sh "make get-source-ami"
          }
        }
        stage('Get Ohai Output') {
          steps {
            sh "make get-ohai-output"
          }
        }
      }
    }

    stage('Upload to S3') {
      steps {
        sh "make upload-to-s3"
      }
    }
  }
}
