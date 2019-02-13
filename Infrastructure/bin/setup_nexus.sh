#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

# To be Implemented by Student

echo "Change Project"
oc project ${GUID}-nexus

echo "Deploy nexus3 App"
oc new-app sonatype/nexus3:latest

echo "expose router for nexus3"
oc expose svc nexus3

echo "Change resources for nexus3"
#oc rollout pause dc nexus3

echo "Nexus should be ready ... trying to config nexus"
#./Infrastructure/bin/setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus )

oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'
oc set resources dc nexus3 --limits=cpu=2,memory=2048Mi --requests=cpu=500m,memory=1024Mi

echo "Create PVC for nexus"
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f -

oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc

echo "Set up checker for liveness and readiness"
oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/


echo "Expose router for nexus3-registry"
oc expose dc nexus3 --port=5000 --name=nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000

echo "Add annotaion for route"
oc annotate route nexus3 console.alpha.openshift.io/overview-app-route=true
oc annotate route nexus-registry console.alpha.openshift.io/overview-app-route=false

echo "Rolling out nexus App"
#oc rollout resume dc nexus3