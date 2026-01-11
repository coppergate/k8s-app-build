
# install the cnpg kubectl plugin
# this plugin provides operators for cloudnative postgress install

curl -sSfL \
  https://github.com/cloudnative-pg/cloudnative-pg/raw/main/hack/install-cnpg-plugin.sh | \
  sudo sh -s -- -b /usr/local/bin

# setup auto complete

cat > kubectl_complete-cnpg <<EOF
#!/usr/bin/env sh

# Call the __complete command passing it all arguments
kubectl cnpg __complete "\$@"
EOF

chmod +x kubectl_complete-cnpg

# Important: the following command may require superuser permission

kubectl cnpg install generate \
  -n postgres  \
  --version 1.25.1 \
  --replicas 3 \
  > operator.yaml

# The flags in the above command have the following meaning:
# -n <ns> install the CNPG operator into the <ns> namespace
# --version -  install the latest patch version for minor version 1.23
# --replicas  -  install the operator with 3 replicas
# --watch-namespace "albert, bb, freddie" have the operator watch for changes in the albert, bb and freddie namespaces only

kubectl create -n postgres -f operator.yaml

# note the storage class for the cluster volume should exists before this is run

kubectl create namespace postgres
kubectl label --overwrite namespace postgres pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

kubectl create -n postgres -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql-db
  namespace: postgres
spec:
  instances: 3
  storage:
    storageClass: rook-ceph-fs-sc
    size: 20Gi
  bootstrap:
    initdb:
      postInitTemplateSQL:
        - CREATE EXTENSION timescaledb;
        - CREATE EXTENSION postgis;
        - CREATE EXTENSION postgis_topology;
        - CREATE EXTENSION fuzzystrmatch;
        - CREATE EXTENSION postgis_tiger_geocoder;
  postgresql:
    shared_preload_libraries:
      - timescaledb
EOF

sleep 1m;

kubectl expose  service postgresql-db-rw --name postgresql --port=5432 --target-port=5432 --type=LoadBalancer -n postgres
# kubec delete crd backups.postgresql.cnpg.io clusterimagecatalogs.postgresql.cnpg.io clusters.postgresql.cnpg.io databases.postgresql.cnpg.io imagecatalogs.postgresql.cnpg.io poolers.postgresql.cnpg.io publications.postgresql.cnpg.io scheduledbackups.postgresql.cnpg.io subscriptions.postgresql.cnpg.io 

# kubectl create secret generic timescale-secret --from-literal=PGHOST=<your-pg-host> --from-literal=PGPORT=<your-pg-port> --from-literal=PGDATABASE=<your-pg-database> --from-literal=PGUSER=<your-pg-user> --from-literal=PGPASSWORD=<your-pg-password>

helm repo add timescale 'https://charts.timescale.com/'



#
## connect to a CLI for the cluster
#kubectl cnpg psql postgresql-test-2
#
## setup a user
#postgres=# CREATE USER wjones WITH PASSWORD 'wjones';
#postgres=# CREATE DATABASE wjones_db OWNER wjones;
#
##	set a password onto the 'postgres' login....
#postgres=# \password wjones
#
#
## remove the installed cluster
#kubectl delete cluster postgres-test-2 -n default
#
