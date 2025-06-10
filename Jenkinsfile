pipeline {
  agent any
  environment {
    AWS_DEFAULT_REGION = 'ap-northeast-1'
    EB_APP  = 'spring-version-app'
    EB_ENV  = 'spring-version-env'
    SONARQUBE = 'SonarQube'
    SONAR_TOKEN = credentials('sonar-token')
  }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build + Unit tests') {
      steps { sh 'mvn -B clean test' }
      post {
        always {
          junit '**/target/surefire-reports/*.xml'
          jacoco execPattern: '**/jacoco.exec'
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withSonarQubeEnv(SONARQUBE) {
          sh """
            mvn -B sonar:sonar \
              -Dsonar.projectKey=version-service \
              -Dsonar.login=$SONAR_TOKEN
          """
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
      steps { sh 'mvn -B package -DskipTests' }
    }

    stage('Deploy to Elastic Beanstalk') {
      steps {
        sh '''
          VERSION=$(date +%Y%m%d%H%M%S)
          mkdir -p eb-bundle && cp target/*.jar eb-bundle/application.jar
          zip -r app-$VERSION.zip eb-bundle
          aws elasticbeanstalk create-application-version \
              --application-name $EB_APP \
              --version-label $VERSION \
              --source-bundle S3Bucket=$EB_APP-artifacts,S3Key=app-$VERSION.zip || true
          aws s3 cp app-$VERSION.zip s3://$EB_APP-artifacts/
          aws elasticbeanstalk update-environment \
              --environment-name $EB_ENV \
              --version-label $VERSION
          aws elasticbeanstalk wait environment-updated --environment-name $EB_ENV
        '''
      }
    }
  }

  post {
    failure { mail to: 'your@email', subject: 'Pipeline failed', body: env.BUILD_URL }
  }
}
