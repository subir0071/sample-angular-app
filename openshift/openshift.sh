#Give actual value of token before running this file
oc login https://masterdnsj2p5wq2nzrzvo.southindia.cloudapp.azure.com:443 --token=

oc new-project angular-demo-cicd

oc new-app -f jenkins_template.json -e INSTALL_PLUGINS=configuration-as-code-support,credentials:2.1.16,matrix-auth:2.3,sonar,nodejs,ssh-credentials,jacoco -e CASC_JENKINS_CONFIG=https://raw.githubusercontent.com/sourabhgupta385/openshift-jenkins/master/jenkins.yaml -n angular-demo-cicd

oc new-project angular-demo-dev
oc new-project angular-demo-test
oc new-project angular-demo-prod

oc policy add-role-to-user system:image-puller system:serviceaccount:angular-demo-test:default -n angular-demo-dev
oc policy add-role-to-user system:image-puller system:serviceaccount:angular-demo-prod:default -n angular-demo-dev

oc policy add-role-to-user edit system:serviceaccount:angular-demo-cicd:jenkins -n angular-demo-dev
oc policy add-role-to-user edit system:serviceaccount:angular-demo-cicd:jenkins -n angular-demo-test
oc policy add-role-to-user edit system:serviceaccount:angular-demo-cicd:jenkins -n angular-demo-prod

oc new-app https://github.com/sourabhgupta385/sample-angular-app.git --strategy=pipeline --name=angular-demo-pipeline -n angular-demo-cicd
