def readProperties(){
	def properties_file_path = "${workspace}" + "@script/properties.yml"
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


podTemplate(cloud: 'openshift', 
			containers: [
				containerTemplate(command: 'cat', image: 'docker:18.06', name: 'docker', ttyEnabled: true,workingDir:'/var/lib/jenkins'), 
        containerTemplate(command: 'cat', image: 'garunski/alpine-chrome:latest', name: 'chrome', ttyEnabled: true,workingDir:'/var/lib/jenkins'), 
				containerTemplate(command: '', image: 'selenium/standalone-chrome:3.14', name: 'selenium', ports: [portMapping(containerPort: 4444)], ttyEnabled: false,workingDir:'/var/lib/jenkins')],
			label: 'jenkins-pipeline', 
			name: 'jenkins-pipeline', 
			serviceAccount: 'jenkins', 
			volumes: [persistentVolumeClaim(claimName: 'jenkins', mountPath: '/var/lib/jenkins', readOnly: false)] 
			){
node{
   def NODEJS_HOME = tool "NODE_PATH"
   env.PATH="${env.PATH}:${NODEJS_HOME}/bin"
   
   stage('Checkout'){
       checkout([$class: 'GitSCM', branches: [[name: "*/${BRANCH}"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: "${GIT_CREDENTIALS}", url: "${GIT_SOURCE_URL}"]]])
       env.WORKSPACE = "${workspace}"
   }
  
   node ('jenkins-pipeline'){
       container ('chrome'){
            stage('Initial Setup'){
                sh 'cd "${WORKSPACE}"'
                sh 'npm install'
            }
   
            if(env.UNIT_TESTING == 'True'){
                stage('Unit Testing'){   
                    sh 'cd "${WORKSPACE}"'
                    sh ' $(npm bin)/ng test -- --no-watch --no-progress --browsers Chrome_no_sandbox'
   	            }
            }
  
            if(env.CODE_COVERAGE == 'True'){
                stage('Code Coverage'){	
                    sh 'cd "${WORKSPACE}"'
	                sh ' $(npm bin)/ng test -- --no-watch --no-progress --code-coverage --browsers Chrome_no_sandbox'
   	            }
            }
   
            if(env.CODE_QUALITY == 'True'){
                stage('Code Quality Analysis'){ 
                    sh 'cd "${WORKSPACE}"'
                    sh 'npm run lint'
                }
            }
        }
    }
   
   stage('Dev - Build Application'){
        buildApp("${APP_NAME}-dev", "${MS_NAME}")
   }

   stage('Dev - Deploy Application'){
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
  
}
}
