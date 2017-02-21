server=$(kubectl config view -o jsonpath='{.clusters[?(@.name == "aws_kubernetes")].cluster.server}')
user=$(kubectl config view -o jsonpath='{.users[?(@.name == "aws_kubernetes-basic-auth")].user.username}')
pass=$(kubectl config view -o jsonpath='{.users[?(@.name == "aws_kubernetes-basic-auth")].user.password}')
elastic_path='api/v1/proxy/namespaces/kube-system/services/elasticsearch-logging'
ok=0
timeout=3
normal_rotation_period='7 days'
until [ $ok -eq 1 ]; do
	json=$(curl --insecure -u $user:$pass "$server/$elastic_path/_cluster/health?level=indices")
    indices=$(echo $json | jq .indices | jq 'keys')
	status=$(echo $json | jq -r .status)
    if [ $status != 'red' ]; then
    	rotated=$(date --date="${normal_rotation_period} ago" +"logstash-%Y.%m.%d")
    	for indice in $(echo $indices | jq -r '.[]' | tail -n +2); do
        	if [[ "$rotated" > "$indice" ]]; then
            	echo "normally rotating $indice"
                curl --insecure -u $user:$pass -XDELETE "$server/$elastic_path/$indice"
            fi
        done
    	echo "status ok"
    	ok=1
    else
        total_indices=$(echo $indices | jq 'length')
        if [ $total_indices -gt 2 ]; then
        	oldest=$(echo $indices | jq -r .[1])
            echo "status RED - rotating.."
            curl --insecure -u $user:$pass -XDELETE "$server/$elastic_path/$oldest"
            sleep $timeout
        else
        	echo "status RED - unrecognized problem"
        	ok=1
        fi
    fi
done
