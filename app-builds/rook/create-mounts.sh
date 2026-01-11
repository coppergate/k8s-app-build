mkdir /mnt/ceph
mon_endpoints="191.16.192.38:6789,191.16.192.35:6789,191.16.192.36:6789"
my_secret="AQBo3NFnrt31LxAAZlvtV9SWGQuHWs4/PPhy9Q=="
mount -t fuse.ceph -o mds_namespace=cephfs,name=admin,secret=$my_secret $mon_endpoints:/ /mnt/ceph


mkdir /mnt/ceph
mon_endpoints="10.105.130.68:6789,10.106.34.196:6789,10.103.184.247:6789"
my_secret="AQBo3NFnrt31LxAAZlvtV9SWGQuHWs4/PPhy9Q=="
mount -t fuse.ceph -o mds_namespace=cephfs,name=admin,secret=$my_secret $mon_endpoints:/ /mnt/ceph
