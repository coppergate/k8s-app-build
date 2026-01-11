
function re() {
        local height length
        
        width=$(tput col)
        height=$(tput line)
        
        tput cup $height $width
		tput ed
    }

fetch_cursor_position() {
  local pos

  IFS='[;' read -p $'\e[6n' -d R -a pos -rs || echo "failed with error: $? ; ${pos[*]}"
  echo "${pos[1]}:${pos[2]}"
}

function DelayWhileNotRunning() {

	tput init

	ABORT_COUNT=50
	currentCount=0
	
	notRunning=1
	
	namespace=$1
	grepStrings=$2
	sleepDelay=$3
    printf "waiting for startup...\n"; 
	
	IFS='[;' read -p $'\e[6n' -d R -a pos -rs || echo "failed with error: $? ; ${pos[*]}"
	row=${pos[1]}
	col=${pos[2]}
	
	totalLines=tput lines
	
	while [[ $notRunning -eq 1 && $currentCount -lt $ABORT_COUNT ]] ; do
		check_result=($(kubectl get pods --namespace $namespace | grep -i -E $grepStrings | sed -e "s/ \+  /\t/g" | cut --fields=1,3))

		
		tput cup $row $col
		tput ed;
		echo "$row $col"
		
		if [[ ${#check_result[@]} -gt 0 ]] ; then
		
			
			notRunning=0
			for key in "${!check_result[@]}"; do
				if [[ $((key % 2)) -eq 0 ]]; then
					name="${check_result[$key]}"
					running="${check_result[$key + 1]}"
					printf "%s is %s\n" "$name" "$running"
					if [[ "$running" != "Running" ]]; then
						notRunning=1
					fi
				fi
			done
			if [[ $row -eq $totalLines ]] ; then
				row=($row - ${#check_result[@]})
			fi
			
			if  [[ $notRunning -eq 1 ]]; then
				sleep $sleepDelay
				((currentCount+=1))
			fi
		else
			echo "Waiting for init ..."
			if [[ $row -eq $totalLines ]] ; then
				row=($row - 1)
			fi
			sleep 5
			((currentCount+=1))
		fi
	done
}


repeat(){
    count=$1
	char="$2"
	for (( c=1; c<=$count; c++ )) 
	do 
		echo -n "$char"; 
	done
}


echo "get check results"
echo ""

repeat 90 "+"

echo ""


# tput cup
# echo "call for delay"
# DelayWhileNotRunning "observability" "tim"

