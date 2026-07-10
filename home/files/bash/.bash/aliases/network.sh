# aliases/network.sh — networking, IPs, ports, and connectivity

alias digg='dig +short'                   # terse DNS lookup
alias extip='curl icanhazip.com'          # public IP via icanhazip
alias myip='curl ifconfig.me'             # public IP via ifconfig.me
alias hosts='cat /etc/hosts'
alias http='curl -I'                      # show HTTP headers only
alias ipinfo='ip a'                       # all interface addresses
alias netst='ss -tulpn'                   # listening sockets with pids
alias ports='netstat -tulanp'             # all active connections
alias pingg='ping 8.8.8.8'               # quick connectivity check
alias traceroute='traceroute -I'          # ICMP traceroute
alias weather='curl wttr.in'             # terminal weather report
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python -'
