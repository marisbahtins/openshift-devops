#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

# To be Implemented by Student

echo "Create Production project for homework"
oc project ${GUID}-parks-prod

echo "Create poliy to build for jenkins"
oc policy add-role-to-group system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod
oc policy add-role-to-user system:image-puller system:serviceaccount:${GUID}-parks-prod:builder -n ${GUID}-parks-prod
oc policy add-role-to-user system:image-pusher system:serviceaccount:${GUID}-parks-prod:builder -n ${GUID}-parks-prod

echo "Deploy mongodb by using StatFulSet"
echo 'kind: Service
apiVersion: v1
metadata:
  name: "mongodb-internal"
  labels:
    name: "mongodb"
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
spec:
  clusterIP: None
  ports:
    - name: mongodb
      port: 27017
  selector:
    name: "mongodb"' | oc create -f -
echo 'kind: Service
apiVersion: v1
metadata:
  name: "mongodb"
  labels:
    name: "mongodb"
spec:
  ports:
    - name: mongodb
      port: 27017
  selector:
    name: "mongodb"' | oc create -f -
echo 'kind: StatefulSet
apiVersion: apps/v1
metadata:
  name: "mongodb"
spec:
  serviceName: "mongodb-internal"
  replicas: 3
  selector:
    matchLabels:
      name: mongodb
  template:
    metadata:
      labels:
        name: "mongodb"
    spec:
      containers:
        - name: mongo-container
          image: "registry.access.redhat.com/rhscl/mongodb-34-rhel7:latest"
          ports:
            - containerPort: 27017
          args:
            - "run-mongod-replication"
          volumeMounts:
            - name: mongo-data
              mountPath: "/var/lib/mongodb/data"
          env:
            - name: MONGODB_DATABASE
              value: "parks"
            - name: MONGODB_USER
              value: "mongodb"
            - name: MONGODB_PASSWORD
              value: "mongodb"
            - name: MONGODB_ADMIN_PASSWORD
              value: "mongodb"
            - name: MONGODB_REPLICA_NAME
              value: "rs0"
            - name: MONGODB_KEYFILE_VALUE
              value: "12345678901234567890"
            - name: MONGODB_SERVICE_NAME
              value: "mongodb-internal"
          readinessProbe:
            exec:
              command:
                - stat
                - /tmp/initialized
  volumeClaimTemplates:
    - metadata:
        name: mongo-data
        labels:
          name: "mongodb"
      spec:
        accessModes: [ ReadWriteOnce ]
        resources:
          requests:
            storage: "4Gi"' | oc create -f -


echo "Create parksmap's App Template"
oc create -f ./Infrastructure/templates/mlbparks.json -n ${GUID}-parks-prod
oc create -f ./Infrastructure/templates/nationalparks.json -n ${GUID}-parks-prod
oc create -f ./Infrastructure/templates/parksmap.json -n ${GUID}-parks-prod

echo "Deploy mlbparks App"
oc new-app --template=mlbparks --param APPLICATION_NAME=mlbparks-blue --param APP_NAME=mlbparks-bluegreen --param APPLICATION_HOSTNAME=mlbparks-blue.${GUID}-parks-prod.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="MLB Parks (Blue)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-prod
oc new-app --template=mlbparks --param APPLICATION_NAME=mlbparks-green --param APP_NAME=mlbparks-bluegreen --param APPLICATION_HOSTNAME=mlbparks-green.${GUID}-parks-prod.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="MLB Parks (Green)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-prod

echo "Deploy naltionalparks App"
oc new-app --template=nationalparks --param APPLICATION_NAME=nationalparks-blue --param APP_NAME=nationalparks-bluegreen --param APPLICATION_HOSTNAME=nationalparks-blue.${GUID}-parks-prod.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="National Parks (Blue)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-prod
oc new-app --template=nationalparks --param APPLICATION_NAME=nationalparks-green --param APP_NAME=nationalparks-bluegreen --param APPLICATION_HOSTNAME=nationalparks-green.${GUID}-parks-prod.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="National Parks (Green)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-prod

echo "Deploy parksmap App"
oc new-app --template=parksmap-web --param APPLICATION_NAME=parksmap-blue --param APP_NAME=parksmap-bluegreen --param APPLICATION_HOSTNAME=parksmap-blue.${GUID}-parks-prod.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="ParksMap (Blue)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-prod
oc new-app --template=parksmap-web --param APPLICATION_NAME=parksmap-green --param APP_NAME=parksmap-bluegreen --param APPLICATION_HOSTNAME=parksmap-green.${GUID}-parks-prod.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="ParksMap (Green)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-prod

echo "Expose bluegreen route"
oc expose svc/mlbparks-blue --name=mlbparks-bluegreen
oc expose svc/nationalparks-blue --name=nationalparks-bluegreen
oc expose svc/parksmap-blue --name=parksmap


echo "Delete All Tirggers"
oc set triggers dc/parksmap-blue --remove-all -n ${GUID}-parks-prod
oc set triggers dc/parksmap-green --remove-all -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blude --remove-all -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-blue --remove-all -n ${GUID}-parks-prod
oc set triggers dc/mlbparks-green --remove-all -n ${GUID}-parks-prod

echo "Add route label"
oc label route nationalparks-blue type=parksmap-backend -n ${GUID}-parks-prod
oc label route mlbparks-blue type=parksmap-backend -n ${GUID}-parks-prod
oc label route nationalparks-green type=parksmap-backend -n ${GUID}-parks-prod
oc label route mlbparks-green type=parksmap-backend -n ${GUID}-parks-prod

echo "Add green route to bluegreen"
oc patch route/mlbparks-bluegreen -p '{"spec":{"to":{"name":"mlbparks-green"}}}' -n ${GUID}-parks-prod
oc patch route/nationalparks-bluegreen -p '{"spec":{"to":{"name":"nationalparks-green"}}}' -n ${GUID}-parks-prod
oc patch route/parksmap -p '{"spec":{"to":{"name":"parksmap-green"}}}' -n ${GUID}-parks-prod

echo "Set up traffic for router"
oc set route-backends mlbparks-bluegreen mlbparks-green=0 mlbparks-blue=100 -n ${GUID}-parks-prod
oc set route-backends parksmap-bluegreen parksmap-green=0 parksmap-blue=100 -n ${GUID}-parks-prod
oc set route-backends nationalparks-bluegreen nationalparks-green=0 nationalparks-blue=100 -n ${GUID}-parks-prod
