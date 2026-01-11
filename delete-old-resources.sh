# clean up k8s resources that are not running...  mostly after a reboot all of the rook-ceph pods are left stale
# and need to be deleted to make things less ugly


check_result=($(kubectl get pods --all-namespaces | sed -e "s/ \+  /\t/g" | cut --fields=1,2,3))

	for key in "${!check_result[@]}"; do
#		printf "key -> %s  -  %s\n" "$key" "${check_result[$key]}"
		
		if [[ $((key % 3)) -eq 0 ]]; then
			pod="${check_result[$key + 1]}"
			running="${check_result[$key + 2]}"
			namespace="${check_result[$key]}"
			if [[ ${check_result[$key + 2]} = 0* ]]; then
				printf "deleting : %s -> %s (%s)\n" "$pod" "$running" "$namespace"
				kubectl delete pod -n $namespace $pod
			fi
		fi

	done


check_result=($(kubectl get replicaset --all-namespaces | sed -e "s/ \+  /\t/g" | cut --fields=1,2,3))

	for key in "${!check_result[@]}"; do
#		printf "key -> %s  -  %s\n" "$key" "${check_result[$key]}"
		
		if [[ $((key % 3)) -eq 0 ]]; then
			pod="${check_result[$key + 1]}"
			running="${check_result[$key + 2]}"
			namespace="${check_result[$key]}"
			if [[ ${check_result[$key + 2]} = 0* ]]; then
				printf "deleting : %s -> %s (%s)\n" "$pod" "$running" "$namespace"
				kubectl delete replicaset -n $namespace $pod
			fi
		fi

	done


#		key1="${check_result[$key - 1]}"
#		key2="${check_result[$key]}"
#			printf "%s is %s\n" "$name" "$running"
#
