#macOS DNS Benchmark
ARGS_COUNT="$#"
ARGS_ARR=("$@")
BENCHMARK_DNS_IPS=("1.1.1.1" "8.8.8.8")
BENCHMARK_DNS_TEXT=("Cloudflare DNS" "Google DNS")
SYSTEM_DNS_SERVERS=($(grep nameserver <(scutil --dns) | awk '{print $3}' | sort -u))
DEFAULT_GATEWAY=$(route get default | grep gateway | awk '{print $2}')
DEFAULT_GATEWAY_IN_SYSTEM_DNS=false
DEFAULT_GATEWAY_IS_DNS=false
DOMAINS=($(curl -s https://raw.githubusercontent.com/gyroworld/macOS-DNS-Benchmark/main/domains.list))

function get_dns_servers() {
    #Check if default gateway in part of system DNS servers
    for i in "${!SYSTEM_DNS_SERVERS[@]}"; do
        if [[ "${SYSTEM_DNS_SERVERS[$i]}" == "${DEFAULT_GATEWAY}" ]]; then
            DEFAULT_GATEWAY_IN_SYSTEM_DNS=true
            DEFAULT_GATEWAY_IS_DNS=true
        fi

        #Remove IPv6 addresses
        if [[ "${SYSTEM_DNS_SERVERS[$i]}" == *":"* ]]; then
            unset 'SYSTEM_DNS_SERVERS[i]'
        fi

    done

    #If it's not, check if it has a DNS server running
    if [ $DEFAULT_GATEWAY_IN_SYSTEM_DNS = false ]; then
        check=$(nslookup -retry=1 -timeout=1 example.com $DEFAULT_GATEWAY)
        if [[ "${check}" == *"connection timed out"* ]]; then
            printf "INFO: Default gateway is not a DNS server.\n"
        else
            DEFAULT_GATEWAY_IS_DNS=true
        fi
    fi
}

function query_dns_server() {
    dscacheutil -flushcache
    printf "\n"
    printf "\e[1;32mDNS Server: $1 ($2)\e[0m"
    time for i in ${DOMAINS[@]}; do dig @$1 $i +noall +answer > /dev/null; done
}

function run_benchmark() {
    for i in "${!BENCHMARK_DNS_IPS[@]}"; do
        query_dns_server ${BENCHMARK_DNS_IPS[$i]} "${BENCHMARK_DNS_TEXT[$i]}"
    done

    for j in "${!SYSTEM_DNS_SERVERS[@]}"; do
        query_dns_server ${SYSTEM_DNS_SERVERS[$j]} "Current DNS"
    done

    if [ $DEFAULT_GATEWAY_IN_SYSTEM_DNS = false ] && [ $DEFAULT_GATEWAY_IS_DNS = true ]; then
        query_dns_server $DEFAULT_GATEWAY "Router DNS [not in use]"
    fi

    if (($ARGS_COUNT > 0)); then
        for item in "${ARGS_ARR[@]}"; do
            query_dns_server "${item}" "User added DNS"
        done

    fi

}

function main() {
    clear
    printf "\e[1;34mmacOS DNS Benchmark\e[0m\n"
    printf "\n"
    printf "\e[1;37mQuerying ${#DOMAINS[@]} domains...\e[0m\n"
    get_dns_servers
    run_benchmark
}

main
