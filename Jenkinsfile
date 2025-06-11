pipeline {
  agent any

  tools { jdk 'jdk21'; maven 'maven3' }

  environment {
    AWS_DEFAULT_REGION = 'ap-northeast-1'
    EB_APP  = 'spring-version-app'
    EB_ENV  = 'spring-version-env'
    SONARQUBE = 'SonarQube'
  }

  stages {
    stage('Checkout') { steps { checkout scm } }

    stage('Build & Unit tests') {
      steps {
        dir('spring-app') {
          withMaven(jdk: 'jdk21', maven: 'maven3') {
            sh 'mvn -B clean test'
          }
        }
      }
      post {
        always {
          dir('spring-app') {
            junit  '**/target/surefire-reports/*.xml'
            jacoco execPattern: '**/target/jacoco.exec'
          }
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        dir('spring-app') {
          withMaven(jdk: 'jdk21', maven: 'maven3') {
            withSonarQubeEnv('SonarQube') {
              sh 'mvn -B sonar:sonar -Dsonar.projectKey=version-service -Dsonar.token=$SONAR_AUTH_TOKEN'
            }
          }
        }
      }
    }

    stage('Quality Gate (non-blocking)') {
  steps {
    script {
      def qg = waitForQualityGate(webhookSecretId: '', abortPipeline: false)
      echo "Quality Gate status: ${qg.status}"
    }
  }
}


    stage('Package') {
      steps {
        dir('spring-app') {
          withMaven(jdk: 'jdk21', maven: 'maven3') {
            sh 'mvn -B package -DskipTests'
          }
        }
      }
    }

    stage('Deploy to Elastic Beanstalk') {
      steps {
        sh '''
          VERSION=$(date +%Y%m%d%H%M%S)

          # copy JAR to workspace root and rename to application.jar
          cp spring-app/target/*.jar application.jar

          # create zip with the JAR at top level (no folder)
          zip -j app-$VERSION.zip application.jar

          # upload to artifacts bucket
          aws s3 cp app-$VERSION.zip s3://$EB_APP-artifacts/app-$VERSION.zip

          # register & deploy
          aws elasticbeanstalk create-application-version \
              --application-name $EB_APP \
              --version-label $VERSION \
              --source-bundle S3Bucket=$EB_APP-artifacts,S3Key=app-$VERSION.zip

          aws elasticbeanstalk update-environment \
              --environment-name $EB_ENV \
              --version-label $VERSION

          aws elasticbeanstalk wait environment-updated \
              --environment-name $EB_ENV
        '''
      }
    }
  }

  post { failure { echo "Pipeline failed → ${env.BUILD_URL}" } }
}
