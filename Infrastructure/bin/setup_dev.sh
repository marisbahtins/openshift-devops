#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# To be Implemented by Student
echo "Change Project"
oc project ${GUID}-parks-dev
echo "Create poliy to build for jenkins"
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-dev
oc policy add-role-to-user system:image-puller system:serviceaccount:${GUID}-parks-dev:builder -n ${GUID}-parks-dev
oc policy add-role-to-user system:image-pusher system:serviceaccount:${GUID}-parks-dev:builder -n ${GUID}-parks-dev
oc policy add-role-to-user view --serviceaccount=default -n ${GUID}-parks-dev

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
  replicas: 1
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
oc create -f ./Infrastructure/templates/mlbparks.json -n ${GUID}-parks-dev
oc create -f ./Infrastructure/templates/nationalparks.json -n ${GUID}-parks-dev
oc create -f ./Infrastructure/templates/parksmap.json -n ${GUID}-parks-dev

echo "Deploy mlbparks App"
oc new-app --template=mlbparks --param APPLICATION_NAME=mlbparks --param APP_NAME=mlbparks --param APPLICATION_HOSTNAME=mlbparks.${GUID}-parks-dev.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="MLB Parks (Dev)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-dev

echo "Deploy naltionalparks App"
oc new-app --template=nationalparks --param APPLICATION_NAME=nationalparks --param APP_NAME=nationalparks --param APPLICATION_HOSTNAME=nationalparks.${GUID}-parks-dev.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="National Parks (Dev)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-dev

echo "Deploy parksmap App"
oc new-app --template=parksmap-web --param APPLICATION_NAME=parksmap --param APP_NAME=parksmap --param APPLICATION_HOSTNAME=parksmap-${GUID}-parks-dev.apps.na311.openshift.opentlc.com --param CONFIG_APPNAME="ParksMap (Dev)" --param MAVEN_MIRROR_URL=http://nexus3-${GUID}-nexus.apps.na311.openshift.opentlc.com/repository/maven-all-public/ -n ${GUID}-parks-dev

echo "Delete All triggers"
oc set triggers dc/mlbparks --remove-all -n ${GUID}-parks-dev
oc set triggers dc/nationalparks --remove-all -n ${GUID}-parks-dev
oc set triggers dc/parksmap --remove-all -n ${GUID}-parks-dev
