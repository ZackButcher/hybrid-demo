SHELL := /bin/zsh

HUB := gcr.io/istio-release
TAG := release-0.8-20180504-18-37

#CLUSTER_A := "gke_zack-butcher_us-west1-a_a"
CLUSTER_A := "gke_zack-butcher_us-central1-a_bookinfo-a"
ADMIN_CLUSTER_A_DIR := ./cluster-admin/cluster-a

#CLUSTER_B := "gke_zack-butcher_us-west1-b_b"
CLUSTER_B := "gke_zack-butcher_us-central1-b_bookinfo-b"
ADMIN_CLUSTER_B_DIR := ./cluster-admin/cluster-b

TEST_SERVER_FILE_NAME := app.yaml
TEST_SERVER_CLUSTER_A_DIR := ./test-server/cluster-a
TEST_SERVER_CLUSTER_B_DIR := ./test-server/cluster-b

BOOKINFO_CLUSTER_A_DIR := ./bookinfo
BOOKINFO_CLUSTER_B_DIR := ./bookinfo

ISTIO_FILE_NAME := istio.yaml
# TODO: not tested w/ auth. We need to wire up same certs to both CAs.
# ISTIO_FILE_NAME := istio-auth.yaml
CROSS_CLUSTER_CONFIG_FILE_NAME := cross-cluster.yaml
CORE_DNS_FILE_NAME := coredns.yaml

##############

cluster-roles:
	kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(shell gcloud config get-value core/account) --context=${CLUSTER_A}
	kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(shell gcloud config get-value core/account) --context=${CLUSTER_B}

##############

ctxa:
	kubectl config use-context ${CLUSTER_A}

deploy-a:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ${TEST_SERVER_CLUSTER_A_DIR}/${TEST_SERVER_FILE_NAME} |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_A}
deploy-a.bookinfo:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ./bookinfo/ratings/cluster-a/ratings.yaml |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_A}
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ./bookinfo/details/cluster-a/details.yaml |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_A}
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ./bookinfo/productpage/cluster-a/productpage.yaml |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_A}
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ./bookinfo/reviews/cluster-a/reviews.yaml |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_A}

deploy-a.istio:
	kubectl apply -f ${ADMIN_CLUSTER_A_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_A}
deploy-a.istio.cross-cluster.dns:
	kubectl apply -f ${ADMIN_CLUSTER_A_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_A}
deploy-a.istio.cross-cluster:
	$(eval CORE_DNS_IP := $(shell kubectl get svc core-dns -n istio-system -o jsonpath='{.spec.clusterIP}' --context=${CLUSTER_A}))
	$(eval INGRESS_B_IP := $(shell kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CLUSTER_B}))
	sed -e "s/INGRESS_IP_ADDRESS/${INGRESS_B_IP}/g" \
		-e "s/CORE_DNS_IP/${CORE_DNS_IP}/g" \
		${ADMIN_CLUSTER_A_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} | \
	kubectl  --context=${CLUSTER_A} apply -f -

deploy-a.addons:
	kubectl apply -f ${ADMIN_CLUSTER_A_DIR}/addons --context=${CLUSTER_A}

delete-a:
	kubectl delete -f ${TEST_SERVER_CLUSTER_A_DIR}/${TEST_SERVER_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.bookinfo:
	kubectl delete -f ${BOOKINFO_CLUSTER_A_DIR}/ --context=${CLUSTER_A} || true
delete-a.istio:
	kubectl delete -f ${ADMIN_CLUSTER_A_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.istio.cross-cluster:
	kubectl delete -f ${ADMIN_CLUSTER_A_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.istio.cross-cluster.dns:
	kubectl delete -f ${ADMIN_CLUSTER_A_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_A} || true
delete-a.addons:
	kubectl delete -f ${ADMIN_CLUSTER_A_DIR}/addons --context=${CLUSTER_A} || true

##############

ctxb:
	kubectl config use-context ${CLUSTER_B}

deploy-b:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ${TEST_SERVER_CLUSTER_B_DIR}/${TEST_SERVER_FILE_NAME} |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_B}
deploy-b.bookinfo:
	# TODO: set env var to use proxyv2 instead of sed
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ./bookinfo/reviews/cluster-b/reviews.yaml |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_B}
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ./bookinfo/ratings/cluster-b/ratings.yaml |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_B}
	kubectl apply -f <(./istioctl kube-inject --hub=${HUB} --tag=${TAG} -f ./bookinfo/details/cluster-b/details.yaml |\
		sed -e "s,${HUB}/proxy:,${HUB}/proxyv2:,g") --context=${CLUSTER_B}
deploy-b.istio:
	kubectl apply -f ${ADMIN_CLUSTER_B_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_B}
deploy-b.istio.cross-cluster.dns:
	kubectl apply -f ${ADMIN_CLUSTER_B_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_B}
deploy-b.istio.cross-cluster:
	$(eval CORE_DNS_IP := $(shell kubectl get svc core-dns -n istio-system -o jsonpath='{.spec.clusterIP}' --context=${CLUSTER_B}))
	$(eval INGRESS_A_IP := $(shell kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[*].ip}' --context=${CLUSTER_A}))
	sed -e "s/INGRESS_IP_ADDRESS/${INGRESS_A_IP}/g" \
		-e "s/CORE_DNS_IP/${CORE_DNS_IP}/g" \
		${ADMIN_CLUSTER_B_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} | \
	kubectl  --context=${CLUSTER_B} apply -f -

deploy-b.addons:
    kubectl apply -f ${ADMIN_CLUSTER_B_DIR}/addons --context=${CLUSTER_A}
	
delete-b:
	kubectl delete -f ${TEST_SERVER_CLUSTER_B_DIR}/${TEST_SERVER_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.bookinfo:
	kubectl delete -f ${BOOKINFO_CLUSTER_B_DIR}/ --context=${CLUSTER_B} || true
delete-b.istio:
	kubectl delete -f ${ADMIN_CLUSTER_B_DIR}/${ISTIO_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.istio.cross-cluster:
	kubectl delete -f ${ADMIN_CLUSTER_B_DIR}/${CROSS_CLUSTER_CONFIG_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.istio.cross-cluster.dns:
	kubectl delete -f ${ADMIN_CLUSTER_B_DIR}/${CORE_DNS_FILE_NAME} --context=${CLUSTER_B} || true
delete-b.addons:
	kubectl delete -f ${ADMIN_CLUSTER_B_DIR}/addons --context=${CLUSTER_A} || true

##############

deploy: deploy-a deploy-b
deploy.bookinfo: deploy-a.bookinfo deploy-b.bookinfo
deploy.istio: deploy-a.istio deploy-b.istio
deploy.istio.cross-cluster.dns: deploy-a.istio.cross-cluster.dns deploy-b.istio.cross-cluster.dns
deploy.istio.cross-cluster: deploy-a.istio.cross-cluster deploy-b.istio.cross-cluster
deploy.addons: deploy-a.addons deploy-b.addons

delete: delete-a delete-b
delete.bookinfo: delete-a.bookinfo delete-b.bookinfo
delete.istio: delete-a.istio delete-b.istio
delete.istio.cross-cluster: delete-a.istio.cross-cluster delete-b.istio.cross-cluster
delete.istio.cross-cluster.dns: delete-a.istio.cross-cluster.dns delete-b.istio.cross-cluster.dns
delete.addons: delete-a.addons delete-b.addons

deploy-all: deploy.istio deploy.istio.cross-cluster.dns deploy deploy.istio.cross-cluster
delete-all: delete.istio.cross-cluster delete delete.istio.cross-cluster.dns delete.istio delete.bookinfo