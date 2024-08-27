#!/bin/bash

ignoreregex="\/images\/.*|.*\/assets\/.*|.*\/css\/.*|.*\/js\/.*|.*\/fonts\/.*|.*favicon.*|.*captcha.*|.*bk_admin.*|.*admin\.lulop\.com.*|.*lulopsecureph pmyadmin.*|.*\/track\/pixel\/.*|.*Pingdom.*|.*newsletter.*|.*\/proxy\/.*|.*l og\/preview.*|.*\/Footer.*|.*log\/download\/.*|.*apple-touch.*|.*asyncjs.php .*|.*adserver\.lulop\.com.*|.*handshake failure.*|.*cron.*"

cache_file="whois_cache.txt"

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 ora_inizio ora_fine (esempio: $0 \"Aug 25 20:24\" \"Aug 25 20:25\")"
    exit 1
fi

ora_inizio=$1
ora_fine=$2
awk -v start="$ora_inizio" -v end="$ora_fine" '
$0 ~ start {p=1} $0 ~ end {e=1} e && $0 !~ end {p=0} p
' /var/log/haproxy.log | grep -Ev "$ignoreregex" |
awk '
{
    ip = $6;
    split(ip, parts, ".");
    class16 = parts[1] "." parts[2] ".0.0/16";
    event_time = $1 " " $2 " " substr($3, 1, 5);
    count[class16]++;
    if (!match(times[class16], event_time)) {
        times[class16] = times[class16] ? times[class16] ", " event_time : e vent_time;
    }
    full_ip[ip] = $6;
}
END {
    for (c in count) {
        print c "\t" count[c] "\t" times[c] "\t" full_ip[c];
    }
}' | sort -t '.' -k 1,2n |
while IFS=$'\t' read -r class16 total times full_ip; do
    # Rimuovi la parte `/16` dall'indirizzo IP per passare solo l'IP di base a whois
    base_ip=$(echo "$class16" | sed 's/\/16//')


    # Estrai data e ora dal campo times
    data_ora=$(echo "$times" | awk '{print $1" "$2}')
    ora_min=$(echo "$times" | awk '{print $3}')

    # Aggiungi le informazioni al risultato nell'ordine corretto
    echo -e "$total\t$class16"
done

