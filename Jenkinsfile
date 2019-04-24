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

def devDeployment(projectName,msName){
    openshift.withCluster() {
        openshift.withProject(projectName) {
            openshiftDeploy(namespace: projectName,deploymentConfig: msName)
        } 
    }
}


def testDeployment(sourceProjectName,destinationProjectName,msName){
    openshift.withCluster() {
        openshift.withProject(destinationProjectName){
	          def dcSelector = openshift.selector( "dc", msName)
            def dcExists = dcSelector.exists()
	          if(!dcExists){
	    	      openshift.newApp(sourceProjectName+"/"+msName+":"+"test")   
	          }
            else {
                openshiftDeploy(namespace: destinationProjectName,deploymentConfig: msName) 
            } 
        }
    }
}

def prodDeployment(sourceProjectName,destinationProjectName,msName){
    openshift.withCluster() {
        openshift.withProject(destinationProjectName){
	          def dcSelector = openshift.selector( "dc", msName)
            def dcExists = dcSelector.exists()
	          if(!dcExists){
	    	        openshift.newApp(sourceProjectName+"/"+msName+":"+"prod")   
	          }
            else {
                openshiftDeploy(namespace: destinationProjectName,deploymentConfig: msName)
            } 
        }
    }
}

def buildApp(projectName,msName){
    openshift.withCluster() {
        openshift.withProject(projectName){
            def bcSelector = openshift.selector( "bc", msName)
            def bcExists = bcSelector.exists()
	          if(!bcExists){
	    	        openshift.newApp("${GIT_SOURCE_URL}","--strategy=docker")
                def rm = openshift.selector("dc", msName).rollout()
                timeout(15) { 
                  openshift.selector("dc", msName).related('pods').untilEach(1) {
                    return (it.object().status.phase == "Running")
                  }
                }  
	          }
            else {
                openshift.startBuild(msName,"--wait")  
            }    
        }
    }
}

def deployApp(projectName,msName){
    openshift.withCluster() {
        openshift.withProject(projectName){
            openshiftDeploy(namespace: projectName,deploymentConfig: msName)
        }
    }
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
   def myRepo = checkout scm
   def gitCommit = myRepo.GIT_COMMIT
   
    stage('Checkout'){
       checkout([$class: 'GitSCM', branches: [[name: "master"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[url: "https://github.com/sourabhgupta385/sample-angular-app"]]])
       readProperties() 
    }
   
   /* node ('jenkins-pipeline'){
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
*/
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
        CHECK_DEPLOYMENT = sh (script: 'kubectl get deployment sample-angular-app',
           returnStatus: true)
        if(CHECK_DEPLOYMENT == 1){
          sh 'kubectl create -f sample-app-kube.yaml'
        }
        else{
          sh "WEB_IMAGE_NAME='sourabh385/myapp:${gitCommit}'"
          sh 'kubectl set image deployment/sample-angular-app sample-angular-app=$WEB_IMAGE_NAME'
        }
      }
    }
  }
}
   /*stage('Dev - Deploy Application'){
        devDeployment("${APP_NAME}-dev", "${MS_NAME}")
   }
   
   stage('Tagging Image for Testing'){
        openshiftTag(namespace: '$APP_NAME-dev', srcStream: '$MS_NAME', srcTag: 'latest', destStream: '$MS_NAME', destTag: 'test')
   }
   
   stage('Test - Deploy Application'){
        testDeployment("${APP_NAME}-dev", "${APP_NAME}-test", "${MS_NAME}")
   }

   if(env.FUNCTIONAL_TESTING == 'True'){
        node ('jenkins-pipeline'){
            container ('chrome'){
                stage("Functional Testing"){
                    sh 'cd "${WORKSPACE}"'
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

   stage('Tagging Image for Production'){
        openshiftTag(namespace: '$APP_NAME-dev', srcStream: '$MS_NAME', srcTag: 'latest', destStream: '$MS_NAME', destTag: 'prod')
   }	
    
   stage('Deploy to Production approval'){
        input "Deploy to Production Environment?"
   }
	
   stage('Prod - Deploy Application'){
        prodDeployment("${APP_NAME}-dev", "${APP_NAME}-prod", "${MS_NAME}")
   }	
  */
}
}
