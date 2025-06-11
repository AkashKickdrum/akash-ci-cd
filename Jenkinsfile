pipeline {
  agent any

  /* Jenkins tool installations (names from Global Tool Configuration) */
  tools {
    jdk   'jdk21'
    maven 'maven3'
  }

  /* global variables used in the shell scripts */
  environment {
    AWS_DEFAULT_REGION = 'ap-northeast-1'
    EB_APP  = 'spring-version-app'
    EB_ENV  = 'spring-version-env'
    SONARQUBE = 'SonarQube'          // Server name in “Configure System”
  }

  stages {

    /* ─────────────── Source code ─────────────── */
    stage('Checkout') {
      steps { checkout scm }
    }

    /* ─────── Build, test, publish coverage ───── */
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

    /* ───────────── SonarQube analysis (no gate wait) ───────────── */
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

    /* ─────────────── Package Spring Boot JAR ─────────────── */
    stage('Package') {
      steps {
        dir('spring-app') {
          withMaven(jdk: 'jdk21', maven: 'maven3') {
            sh 'mvn -B package -DskipTests'
          }
        }
      }
    }

    /* ───────────────── Deploy to Elastic Beanstalk ───────────────── */
    stage('Deploy to Elastic Beanstalk') {
      steps {
        sh '''
          cd spring-app && VERSION=$(date +%Y%m%d%H%M%S)

          # bundle JAR at top level so EB Java platform finds application.jar
          cp target/*.jar ../application.jar
          cd .. && zip -j app-$VERSION.zip application.jar

          aws s3 cp app-$VERSION.zip s3://$EB_APP-artifacts/app-$VERSION.zip

          aws elasticbeanstalk create-application-version \
              --application-name $EB_APP --version-label $VERSION \
              --source-bundle S3Bucket=$EB_APP-artifacts,S3Key=app-$VERSION.zip

          aws elasticbeanstalk update-environment \
              --environment-name $EB_ENV --version-label $VERSION

          aws elasticbeanstalk wait environment-updated \
              --environment-name $EB_ENV
        '''
      }
    }
  }

  post {
    failure { echo "Pipeline failed → ${env.BUILD_URL}" }
  }
}
