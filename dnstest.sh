#macOS DNS Benchmark
IFS=$' '
BENCHMARK_DNS_IPS=("1.1.1.1" "8.8.8.8")
BENCHMARK_DNS_TEXT=("Cloudflare DNS" "Google DNS")
SYSTEM_DNS_SERVERS=($(grep nameserver <(scutil --dns) | awk '{print $3}' | uniq))
DEFAULT_GATEWAY=$(route get default | grep gateway | awk '{print $2}')
DEFAULT_GATEWAY_IN_SYSTEM_DNS=false
DEFAULT_GATEWAY_IS_DNS=false
DOMAINS=$(curl -s https://raw.githubusercontent.com/gyroworld/macOS-DNS-Benchmark/main/domains.list)
DOMAIN_COUNT=$(echo $DOMAINS | wc -l | awk '{print $1}')

function get_dns_servers() {
    #Check if default gateway in part of system DNS servers
    for i in "${!SYSTEM_DNS_SERVERS[@]}"; do
        if [[ "${SYSTEM_DNS_SERVERS[$i]}" == "${DEFAULT_GATEWAY}" ]]; then
            DEFAULT_GATEWAY_IN_SYSTEM_DNS=true
            DEFAULT_GATEWAY_IS_DNS=true
            #break
        fi

        #Remove IPv6 addresses
        if [[ "${SYSTEM_DNS_SERVERS[$i]}" == *":"* ]]; then
            unset "${SYSTEM_DNS_SERVERS[$i]}"
        fi

    done

    #If it's not, check if it has a DNS server running
    if [ $DEFAULT_GATEWAY_IN_SYSTEM_DNS = false ]; then
        check=$(nslookup -retry=1 -timeout=1 example.com $DEFAULT_GATEWAY)
        if [[ "${check}" == *"connection timed out"* ]]; then
            echo "Default gateway not a DNS server."
        else
            DEFAULT_GATEWAY_IS_DNS=true
        fi
    fi
}

function query_dns_server() {
    dscacheutil -flushcache
    printf "\n"
    printf "\e[1;32mDNS Server: $1 ($2)\e[0m"
    time dig +tries=1 +time=2 @$1 -f <(echo $DOMAINS) +noall +answer >/dev/null
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
}

function main() {
    clear
    printf "\e[1;34mmacOS DNS Benchmark\e[0m\n"
    printf "\n"
    printf "\e[1;37mQuerying $DOMAIN_COUNT domains...\e[0m\n"
    get_dns_servers
    run_benchmark
}

main
