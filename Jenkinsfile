pipeline {
  agent any

  /* Make Jenkins add these tools to PATH for every sh step */
  tools {
    jdk   'jdk21'   // name exactly as in Global Tool Configuration
    maven 'maven3'  // idem
  }

  environment {
    AWS_DEFAULT_REGION = 'ap-northeast-1'
    EB_APP = 'spring-version-app'
    EB_ENV = 'spring-version-env'

    /* SonarQube connection is injected below; no token in plain env */
    SONARQUBE = 'SonarQube'
  }

  stages {

    /* ────────────────────────────  SCM  ──────────────────────────── */
    stage('Checkout') {
      steps { checkout scm }
    }

    /* ─────────────────────  Compile + Unit tests  ─────────────────── */
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

            /* JaCoCo XML → publish via Coverage plugin */
            publishCoverage adapters: [
              jacocoAdapter('target/site/jacoco/jacoco.xml')
            ]
          }
        }
      }
    }

    /* ───────────────────────  Static analysis  ────────────────────── */
    stage('SonarQube Analysis') {
      steps {
        dir('spring-app') {
          withMaven(maven: 'maven3', jdk: 'jdk21') {
            withSonarQubeEnv(SONARQUBE) {
              /* SONAR_AUTH_TOKEN is injected automatically */
              sh 'mvn -B sonar:sonar -Dsonar.projectKey=version-service -Dsonar.token=$SONAR_AUTH_TOKEN'
            }
          }
        }
      }
    }

    /* ────────────────  Wait for Quality Gate result  ──────────────── */
    stage('Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {        // was 5 min → 10 min
          waitForQualityGate abortPipeline: true
        }
      }
    }

    /* ────────────────────────  Package JAR  ───────────────────────── */
    stage('Package') {
      steps {
        dir('spring-app') {
          withMaven(maven: 'maven3', jdk: 'jdk21') {
            sh 'mvn -B package -DskipTests'
          }
        }
      }
    }

    /* ───────────  Upload & deploy to Elastic Beanstalk  ───────────── */
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
    failure { echo "Pipeline failed ➜ ${env.BUILD_URL}" }
  }
}
