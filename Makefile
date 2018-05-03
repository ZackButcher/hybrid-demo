HUB := gcr.io/istio-release
TAG := release-0.8-20180503-19-07

SHELL := /bin/zsh

CLUSTER_A :="gke_google.com:zbutcher-test_us-west1-c_a"
CLUSTER_A_DIR :=./cluster-a

CLUSTER_B :="gke_google.com:zbutcher-test_us-west1-c_b"
CLUSTER_B_DIR :=./cluster-b

ISTIO_FILE_NAME := istio-auth.yaml
APP_FILE_NAME := app.yaml

##############

cluster-roles:
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account) --context=${CLUSTER_A}
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account) --context=${CLUSTER_B}

##############

ctxa:
	kubectl config use-context ${CLUSTER_A}

deploy-a:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ${CLUSTER_A_DIR}/${APP_FILE_NAME} |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_A}
deploy-a.istio:
	kubectl apply -f ${CLUSTER_A_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_A}
deploy-a.addons:
	kubectl apply -f ${CLUSTER_A_DIR}/addons --context=${CLUSTER_A}

delete-a:
	kubectl delete -f ${CLUSTER_A_DIR}/${APP_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.istio:
	kubectl delete -f ${CLUSTER_A_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.addons:
	kubectl delete -f ${CLUSTER_A_DIR}/addons --context=${CLUSTER_A} || true

##############

ctxb:
	kubectl config use-context ${CLUSTER_B}

deploy-b:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ${CLUSTER_B_DIR}/${APP_FILE_NAME} |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_B}
deploy-b.istio:
	kubectl apply -f ${CLUSTER_B_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_B}
	# kubectl apply -f ${CLUSTER_B_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_B}
deploy-b.addons:
    kubectl apply -f ${CLUSTER_B_DIR}/addons --context=${CLUSTER_A}
	
delete-b:
	kubectl delete -f ${CLUSTER_B_DIR}/${APP_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.istio:
	kubectl delete -f ${CLUSTER_B_DIR}/${ISTIO_FILE_NAME}-default-namespace --context=${CLUSTER_B}
	# kubectl delete -f ${CLUSTER_B_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.addons:
	kubectl delete -f ${CLUSTER_B_DIR}/addons --context=${CLUSTER_A} || true

##############

deploy: deploy-a deploy-b
deploy.istio: deploy-a.istio deploy-b.istio
deploy.addons: deploy-a.addons deploy-b.addons
delete: delete-a delete-b
delete.istio: delete-a.istio delete-b.istio
delete.addons: delete-a.addons delete-b.addons

deploy-all: deploy.istio deploy.addons deploy