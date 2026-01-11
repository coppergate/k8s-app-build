helm repo add mysql-operator https://mysql.github.io/mysql-operator/
helm repo update

helm install my-mysql-operator mysql-operator/mysql-operator \
--namespace mysql-operator --create-namespace

kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/9.2.0-2.2.3/deploy/deploy-crds.yaml

kubectl create secret generic mysql-pwds --from-literal=rootUser=root --from-literal=rootHost=%
--from-literal=rootPassword="mysqlpassword"

helm install mysql-cluster mysql-operator/mysql-innodbcluster \
--namespace mysql --create-namespace \
--set credentials.root.user='root' \
--set credentials.root.password='mysqlpassword' \
--set credentials.root.host='%' \
--set serverInstances=3 \
--set routerInstances=1

kubectl apply -n my-sql -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: mysql-pv-claim
spec:
storageClassName: cfs-sc
accessModes:
- ReadWriteOnce
resources:
requests:
storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
name: mysql
spec:
selector:
matchLabels:
app: mysql
strategy:
type: Recreate
template:
metadata:
labels:
app: mysql
spec:
containers:
- image: mysql:5.6
name: mysql
env:
# Use secret in real usage
- name: MYSQL_ROOT_PASSWORD
value: password
ports:
- containerPort: 3306
name: mysql
volumeMounts:
- name: mysql-persistent-storage
mountPath: /var/lib/mysql
volumes:
- name: mysql-persistent-storage
persistentVolumeClaim:
claimName: mysql-pv-claim
EOF

curl -v "http://<master-ip>:17010/vol/delete?name=pvc-8e35cd96-df3f-4eaf-b4f6-bd246f584f49&authKey=<md5(owner)>"

kubectl apply -n my-sql -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
name: pvc-8e35cd96-df3f-4eaf-b4f6-bd246f584f49
spec:
storageClassName: cfs-sc
volumeMode: Filesystem
capacity:
storage: 5Gi
accessModes:
- ReadWriteOnce
EOF
