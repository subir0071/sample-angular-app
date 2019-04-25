def readProperties(){
	def properties_file_path = "${workspace}" + "/properties.yml"
	def property = readYaml file: properties_file_path

    env.APP_NAME = property.APP_NAME
    env.MS_NAME = property.MS_NAME
    env.BRANCH = property.BRANCH
    env.GIT_SOURCE_URL = property.GIT_SOURCE_URL
    env.GIT_CREDENTIALS = property.GIT_CREDENTIALS
    env.CODE_QUALITY = property.CODE_QUALITY
    env.UNIT_TESTING = property.UNIT_TESTING
    env.CODE_COVERAGE = property.CODE_COVERAGE
    env.FUNCTIONAL_TESTING = property.FUNCTIONAL_TESTING
    env.LOAD_TESTING = property.LOAD_TESTING
}

podTemplate(cloud: 'kubernetes', 
			containers: [
                containerTemplate(command: 'cat', image: 'garunski/alpine-chrome:latest', name: 'jnlp-chrome', ttyEnabled: true,workingDir:'/home/jenkins'), 
				containerTemplate(command: '', image: 'selenium/standalone-chrome:3.14', name: 'jnlp-selenium', ports: [portMapping(containerPort: 4444)], ttyEnabled: false,workingDir:'/home/jenkins')],
			label: 'jenkins-pipeline', 
			name: 'jenkins-pipeline'
			){
node{
   def NODEJS_HOME = tool "NODE_PATH"
   env.PATH="${env.PATH}:${NODEJS_HOME}/bin"
   //def myRepo = checkout scm
   //def gitCommit = myRepo.GIT_COMMIT
   
    stage('Checkout'){
       //checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
       def myRepo = checkout scm
       env.gitCommit = myRepo.GIT_COMMIT
       readProperties() 
    }
   
    node ('jenkins-pipeline'){
        container ('jnlp-chrome'){
            stage('Initial Setup'){
                checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
                sh 'npm install'
            }
   
            if(env.UNIT_TESTING == 'True'){
                stage('Unit Testing'){
                    sh ' $(npm bin)/ng test -- --no-watch --no-progress --browsers Chrome_no_sandbox'
   	            }
            }
  
            if(env.CODE_COVERAGE == 'True'){
                stage('Code Coverage'){
	                sh ' $(npm bin)/ng test -- --no-watch --no-progress --code-coverage --browsers Chrome_no_sandbox'
   	            }
            }
   
            if(env.CODE_QUALITY == 'True'){
                stage('Code Quality Analysis'){ 
                    sh 'npm run lint'
                }
            }
        }
    }

    podTemplate(label: 'dockerNode', yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: docker
    image: docker:1.11
    command: ['cat']
    tty: true
    volumeMounts:
    - name: dockersock
      mountPath: /var/run/docker.sock
  volumes:
  - name: dockersock
    hostPath:
      path: /var/run/docker.sock
"""
  ){
    node('dockerNode') {
		stage('Dev - Build Application') {
			container('docker') {
				checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
                withCredentials([[$class: 'UsernamePasswordMultiBinding',
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_HUB_USER',
                    passwordVariable: 'DOCKER_HUB_PASSWORD']]) {
                        sh """
                                docker login -u ${DOCKER_HUB_USER} -p ${DOCKER_HUB_PASSWORD}
                                docker build -t sourabh385/myapp:${gitCommit} .
                                docker push sourabh385/myapp:${gitCommit}
                        """
                    }
			}
		}
	}
}

podTemplate(label: 'kubectlnode', containers: [
  containerTemplate(name: 'kubectl', image: 'lachlanevenson/k8s-kubectl:v1.8.8', command: 'cat', ttyEnabled: true)
  
]) {
  node('kubectlnode') {
    stage('Dev - Deploy Application') {
      container('kubectl') {
        checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
        CHECK_DEV_DEPLOYMENT = sh (script: 'kubectl get deployment sample-angular-app -n dev', returnStatus: true)
        if(CHECK_DEV_DEPLOYMENT == 1){
          //Create new deployment and service  
          sh 'kubectl create -f sample-app-kube.yaml -n dev'
        }
        else{
          //Update previous deployment with new image  
          sh "kubectl set image deployment/sample-angular-app sample-angular-app=sourabh385/myapp:${gitCommit} -n dev"
        }
      }
    }

    stage('Deploy to test environment?'){
        input "Deploy to Testing Environment?"
    }

    stage('Test - Deploy Application') {
      container('kubectl') {
        checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
        CHECK_TEST_DEPLOYMENT = sh (script: 'kubectl get deployment sample-angular-app -n test', returnStatus: true)
        if(CHECK_TEST_DEPLOYMENT == 1){
          //Create new deployment and service  
          sh 'kubectl create -f sample-app-kube.yaml -n test'
        }
        else{
          //Update previous deployment with new image  
          sh "kubectl set image deployment/sample-angular-app sample-angular-app=sourabh385/myapp:${gitCommit} -n test"
        }
      }
    }
  }
}
   

   if(env.FUNCTIONAL_TESTING == 'True'){
        node ('jenkins-pipeline'){
            container ('jnlp-chrome'){
                stage("Functional Testing"){
                    checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
                    sh '$(npm bin)/ng e2e -- --protractor-config=e2e/protractor.conf.js'
                }
            }
        }
   }
   
   if(env.LOAD_TESTING == 'True'){
        stage("Load Testing"){
            sh 'artillery run -o load.json perfTest.yml' 
        }
   }
   
   podTemplate(label: 'kubectlnode', containers: [
  containerTemplate(name: 'kubectl', image: 'lachlanevenson/k8s-kubectl:v1.8.8', command: 'cat', ttyEnabled: true)
  
]) {
  node('kubectlnode') {
    stage('Deploy to prod environment?'){
        input "Deploy to Production Environment?"
    }

    stage('Prod - Deploy Application') {
      container('kubectl') {
        checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
        CHECK_PROD_DEPLOYMENT = sh (script: 'kubectl get deployment sample-angular-app -n prod', returnStatus: true)
        if(CHECK_PROD_DEPLOYMENT == 1){
          //Create new deployment and service  
          sh 'kubectl create -f sample-app-kube.yaml -n prod'
        }
        else{
          //Update previous deployment with new image  
          sh "kubectl set image deployment/sample-angular-app sample-angular-app=sourabh385/myapp:${gitCommit} -n prod"
        }
      }
    }
  }
}
}
}
