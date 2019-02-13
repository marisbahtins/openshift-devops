#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Sonarqube in project $GUID-sonarqube"

# Code to set up the SonarQube project.
# Ideally just calls a template
# oc new-app -f ../templates/sonarqube.yaml --param .....

# To be Implemented by Student

echo "Create Project for sonarqube"
oc project ${GUID}-sonarqube


echo "Deploy postgresql for sonarqube"
oc new-app --template=postgresql-persistent --param POSTGRESQL_USER=sonar --param POSTGRESQL_PASSWORD=sonar123 --param POSTGRESQL_DATABASE=sonar --param VOLUME_CAPACITY=4Gi --labels=app=sonarqube_db

echo "Deploy sonarqube App"
oc new-app --docker-image=wkulhanek/sonarqube:6.7.6 --env=SONARQUBE_JDBC_USERNAME=sonar --env=SONARQUBE_JDBC_PASSWORD=sonar123 --env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar --labels=app=sonarqube
echo "Expose router for sonarqube"
#oc rollout pause dc sonarqube
oc expose svc/sonarqube

echo "Set up checker for liveness and readiness"
oc set probe dc/sonarqube --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/sonarqube --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:9000/

echo "Change resources for sonarqube"
oc set resources dc sonarqube --limits=cpu=2,memory=3G --requests=cpu=1,memory=1.5G
oc patch dc sonarqube --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'

#echo "Rolling out sonarqube"
#oc rollout resume dc sonarqube