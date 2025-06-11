pipeline {
  agent any

  /* ──────────── Jenkins Tool Installations to use ──────────── */
  tools {
    jdk   'jdk21'      // matches the name you configured in Global Tool Configuration
    maven 'maven3'     // idem
  }

  /* ────────────────────── Global environment ───────────────── */
  environment {
    AWS_DEFAULT_REGION = 'ap-northeast-1'
    EB_APP  = 'spring-version-app'
    EB_ENV  = 'spring-version-env'

    SONARQUBE = 'SonarQube'     // matches “Server name” in Configure System
    /* With withSonarQubeEnv Jenkins injects SONAR_AUTH_TOKEN automatically */
  }

  stages {

    /* ────────────────────────── SCM checkout ───────────────────────── */
    stage('Checkout') {
      steps { checkout scm }
    }

    /* ──────────────── Build, unit tests, coverage ──────────────────── */
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
            junit '**/target/surefire-reports/*.xml'

            /* Publish JaCoCo XML using the Coverage plugin */
            recordCoverage tools: [
              [$class: 'Jacoco', reportFile: 'target/site/jacoco/jacoco.xml']
            ]
          }
        }
      }
    }

    /* ────────────────────── Static analysis (Sonar) ────────────────── */
    stage('SonarQube Analysis') {
      steps {
        dir('spring-app') {
          withMaven(maven: 'maven3', jdk: 'jdk21') {
            withSonarQubeEnv(SONARQUBE) {
              sh 'mvn -B sonar:sonar -Dsonar.projectKey=version-service -Dsonar.token=$SONAR_AUTH_TOKEN'
            }
          }
        }
      }
    }

    /* ─────────────── Wait until quality gate == “Passed” ───────────── */
    stage('Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }

    /* ───────────────────────── Package the JAR ─────────────────────── */
    stage('Package') {
      steps {
        dir('spring-app') {
          withMaven(maven: 'maven3', jdk: 'jdk21') {
            sh 'mvn -B package -DskipTests'
          }
        }
      }
    }

    /* ─────────────── Deploy new version to Elastic Beanstalk ───────── */
    stage('Deploy to Elastic Beanstalk') {
      steps {
        sh '''
          cd spring-app
          VERSION=$(date +%Y%m%d%H%M%S)

          mkdir -p ../eb-bundle
          cp target/*.jar ../eb-bundle/application.jar
          cd ..
          zip -r app-$VERSION.zip eb-bundle

          # upload bundle
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

  /* ──────────────────────── Post-build section ─────────────────────── */
  post {
    failure {
      echo "Pipeline failed  ➜  ${env.BUILD_URL}"
      // e-mail step removed; add it later when SMTP is configured
    }
  }
}
