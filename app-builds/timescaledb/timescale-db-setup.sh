kubectl create namespace timescaledb
kubectl label --overwrite namespace timescaledb pod-security.kubernetes.io/audit=privileged  pod-security.kubernetes.io/warn=privileged pod-security.kubernetes.io/enforce=privileged

kubectl create -f  - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: timescaledb
  namespace: timescaledb
label:
  release: timescaledb
spec:
  instances: 1
  imageName: ghcr.io/imusmanmalik/timescaledb-postgis:14-3.5
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
  storage:
  # timescaledb.timescaledb.svc.cluster.local
# 
# To get your password for superuser run:
# 
#     #   storageClass: rook-ceph-fs-sc
    size: 15Gi
EOF



# 
# NOTES:
# TimescaleDB can be accessed via port 5432 on the following DNS name from within your cluster:
superuser password
#     PGPASSWORD_POSTGRES=$(kubectl get secret --namespace timescaledb "timescaledb-credentials" -o jsonpath="{.data.PATRONI_SUPERUSER_PASSWORD}" | base64 --decode)
# 
#     # admin password
#     PGPASSWORD_ADMIN=$(kubectl get secret --namespace timescaledb "timescaledb-credentials" -o jsonpath="{.data.PATRONI_admin_PASSWORD}" | base64 --decode)
# 
# To connect to your database, choose one of these options:
# 
# 1. Run a postgres pod and connect using the psql cli:
#     # login as superuser
#     kubectl run -i --tty --rm psql --image=postgres \
#       --env "PGPASSWORD=$PGPASSWORD_POSTGRES" \
#       --command -- psql -U postgres \
#       -h timescaledb.timescaledb.svc.cluster.local postgres
# 
#     # login as admin
#     kubectl run -i --tty --rm psql --image=postgres \
#       --env "PGPASSWORD=$PGPASSWORD_ADMIN" \
#       --command -- psql -U admin \
#       -h timescaledb.timescaledb.svc.cluster.local postgres
# 
# 2. Directly execute a psql session on the master node
# 
#    MASTERPOD="$(kubectl get pod -o name --namespace timescaledb -l release=timescaledb,role=master)"
#    kubectl exec -i --tty --namespace timescaledb ${MASTERPOD} -- psql -U postgres
# 
