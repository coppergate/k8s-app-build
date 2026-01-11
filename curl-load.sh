
# using apache benchmark
# https://httpd.apache.org/docs/2.4/programs/ab.html
# apt-get install ab
# curl-load 1000 10 8080 "weatherforecast"

numberOfCalls=$1
concurrencyOfCalls=$2
localhostPort=$3
restPath=$4

ab -n $numberOfCalls -c $concurrencyOfCalls http://localhost:$localhostPort/$restPath