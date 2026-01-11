# here we have a collection of steps to establish and trouble-shoot a rook ceph cluster

# NB: any devices you hope to wrangle into the rook OSD pool need to be ABSOLUTELY clean

# if there is ANY indication that the disk has been enrolled already or is not empty

# the monitor process will not accept the disk... it has proven difficult to get devices

# cleaned appropriately (i think mostly because the device i was using was a second partition

# on a disk that i was establishing the worker node on the  first parition. so when the

# dev is cleaned it is still leaving MBR data that is being scanned by Ceph....

# this makes it so that the full disk needs to be scrubbed to get it discovered,

# which means the whole node needs to be wiped.... it would be better to use raw devices

# directly and then re-establishing wouldn't require wiping the node, just the OSD device.

# add in the rook repo

helm repo add rook-release https://charts.rook.io/release

kubec create namespace rook-ceph
kubectl label --overwrite namespace rook-ceph pod-security.kubernetes.io/audit=privileged
pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

# for the example crd:

cd /mnt/hegemon-share/code/kubernetes-app-setup/app-builds/rook/
git clone --single-branch --branch v1.16.5 https://github.com/rook/rook.git
cd /mnt/hegemon-share/code/kubernetes-app-setup/app-builds/rook/rook/deploy/examples

# from our app-build/rook directory

# there were instruction for helm that follows this pattern

# did not work as i was learning but it may be that i don't know what i am doing:

#helm install --namespace rook-ceph rook-ceph rook-release/rook-ceph -f
/mnt/hegemon-share/code/kubernetes-app-setup/app-builds/rook/values.yaml
#helm install --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph rook-release/rook-ceph-cluster
-f values.yaml

# taking the example yaml with some minor adjustments from /app-build/rook:

# forward the management interface port

kubectl create -f common.yaml
kubectl create -f crds.yaml
kubectl create -f operator.yaml
kubectl create -f cluster.yaml
kubectl create -f filesystem.yaml
kubectl create -f pool.yaml

kubectl -n rook-ceph port-forward svc/rook-ceph-mgr-dashboard 8443:8443 &

# get the 'admin' password for the managemement UI

kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode &&
echo

# admin

# ;%_!k^U'^$`&.9!ICf='

# if we have an external LB set up :

kubectl expose service rook-ceph-mgr-dashboard --name=rook-ceph-manager --port=8443 --target-port=8443
--type=LoadBalancer -n rook-ceph

# expose the mon endpoints to allow mounting from the host side...

kubectl expose service rook-ceph-mon-c --name=rook-ceph-ext-c --port=6789 --target-port=6789 --type=LoadBalancer -n
rook-ceph
kubectl expose service rook-ceph-mon-d --name=rook-ceph-ext-d --port=6789 --target-port=6789 --type=LoadBalancer -n
rook-ceph
kubectl expose service rook-ceph-mon-e --name=rook-ceph-ext-e --port=6789 --target-port=6789 --type=LoadBalancer -n
rook-ceph

mkdir /mnt/ceph
mon_endpoints="191.16.192.38:6789,191.16.192.35:6789,191.16.192.36:6789"
my_secret="QVFCbzNORm5ydDMxTHhBQVpsdnRWOVNXR1F1SFdzNC9QUGh5OVE9PQ=="
mount -t ceph -o mds_namespace=myfs,name=admin,secret=$my_secret $mon_endpoints:/ /mnt/ceph

# trouble shooting

# First of all install Rook Toolbox by following this howto

https://github.com/rook/rook/blob/master/Documentation/Troubleshooting/ceph-toolbox.md

# the delete of the namespace to clear the rook-ceph cluster can lock up due to 'finalizers'

# it seems these are holding the resources that the pods that have claims have established.

# to do a complete clean-up we need to remove the finalizers and then delete the namespace

kubectl delete namespace rook-ceph

# for trouble shooting within the cluster we can deploy the toolbox

kubectl create -f deploy/examples/toolbox.yaml
kubectl -n rook-ceph rollout status deploy/rook-ceph-tools

# If the 'orchestrator' is being stubborn:

## Then exec into toolbox:

kubectl create -f toolbox.yaml
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash

# from the toolbox container we can run the 'ceph' tools

# show the created filesystems

ceph fs ls

# show the connected services

ceph status

# show the disk compositions for the osd

ceph osd df

# from the cli run:

ceph mgr module enable rook
ceph orch set backend rook
ceph orch status

kubectl -n rook-ceph delete deploy/rook-ceph-tools

DISK="/dev/sda2"

# Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)

sgdisk --zap-all $DISK

# Wipe a large portion of the beginning of the disk to remove more LVM metadata that may be present

dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync

# SSDs may be better cleaned with blkdiscard instead of dd

blkdiscard $DISK

# Inform the OS of partition table changes

partprobe $DISK
