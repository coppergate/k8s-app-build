kubectl -n rook-ceph apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: rook-ceph-mgr-dashboard-loadbalancer
  namespace: rook-ceph # namespace:cluster
  labels:
    app: rook-ceph-mgr-dashboard
    rook_cluster: rook-ceph # namespace:cluster
spec:
  ports:
    - name: dashboard
      port: 8443
      protocol: TCP
      targetPort: 8443
  selector:
    app: rook-ceph-mgr-dashboard
    mgr_role: active
    rook_cluster: rook-ceph # namespace:cluster
  sessionAffinity: None
  type: LoadBalancer
EOF