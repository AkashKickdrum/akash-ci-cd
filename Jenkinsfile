pipeline {
  agent any

  /* Tell Jenkins which tool installations to put on PATH */
  tools {
    jdk   'jdk21'   // the name you added in “Global Tool Configuration”
    maven 'maven3'  // ditto
  }

  environment {
    AWS_DEFAULT_REGION = 'ap-northeast-1'
    EB_APP  = 'spring-version-app'
    EB_ENV  = 'spring-version-env'

    SONARQUBE   = 'SonarQube'
    SONAR_TOKEN = credentials('sonar-token')
  }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build & Unit tests') {
      steps {
        dir('spring-app') {
          withMaven(maven: 'maven3', jdk: 'jdk21') {
            sh 'mvn -B clean test'
          }
        }
      }
      post {
        always {
          dir('spring-app') {
            junit  '**/target/surefire-reports/*.xml'
            jacoco execPattern: '**/jacoco.exec'
          }
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        dir('spring-app') {
          withMaven(maven: 'maven3', jdk: 'jdk21') {
            withSonarQubeEnv(SONARQUBE) {
              sh "mvn -B sonar:sonar -Dsonar.projectKey=version-service -Dsonar.login=$SONAR_TOKEN"
            }
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Package') {
      steps {
        dir('spring-app') {
          withMaven(maven: 'maven3', jdk: 'jdk21') {
            sh 'mvn -B package -DskipTests'
          }
        }
      }
    }

    stage('Deploy to Elastic Beanstalk') {
      steps {
        sh '''
          cd spring-app
          VERSION=$(date +%Y%m%d%H%M%S)

          mkdir -p ../eb-bundle
          cp target/*.jar ../eb-bundle/application.jar
          cd ..
          zip -r app-$VERSION.zip eb-bundle

          aws s3 cp app-$VERSION.zip s3://$EB_APP-artifacts/app-$VERSION.zip

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

  post {
    failure {
      echo "Pipeline failed ➜ ${env.BUILD_URL}"
      /* mail step removed until SMTP is available */
    }
  }
}
