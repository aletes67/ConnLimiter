#!/bin/bash

ignoreregex="\/images\/.*|.*\/assets\/.*|.*\/css\/.*|.*\/js\/.*|.*\/fonts\/.*|.*favicon.*|.*captcha.*|.*bk_admin.*|.*admin\.lulop\.com.*|.*lulopsecureph pmyadmin.*|.*\/track\/pixel\/.*|.*Pingdom.*|.*newsletter.*|.*\/proxy\/.*|.*l og\/preview.*|.*\/Footer.*|.*log\/download\/.*|.*apple-touch.*|.*asyncjs.php .*|.*adserver\.lulop\.com.*|.*handshake failure.*|.*cron.*"

cache_file="whois_cache.txt"

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 ora_inizio ora_fine (esempio: $0 \"Aug 25 20:24\" \"Aug 25 20:25\")"
    exit 1
fi

ora_inizio=$1
ora_fine=$2

# Funzione per estrarre il netname, organization e l'email di abuse
extract_info() {
    local whois_output="$1"

    # Estrai l'organizzazione, se disponibile
    local organization=$(echo "$whois_output" | grep -iE "(organization:|Cus tName:)" | awk -F': ' '{print $2}' | head -n 1)

    # Se l'organizzazione non \Uffffffffisponibile, estrai il netname
    if [ -z "$organization" ]; then
        organization=$(echo "$whois_output" | grep -iE "(netname:)" | awk -F ': ' '{print $2}' | head -n 1)
    fi

    # Estrai la prima email di contatto abuse (sia "Abuse contact" sia "OrgA buseEmail" sia linee con "abuse")
    local abuse_email=$(echo "$whois_output" | grep -iE "(Abuse contact|OrgA buseEmail:|abuse)" | grep -Eo "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2, }" | head -n 1)

    echo "$organization <$abuse_email>"
}

# Funzione per verificare la cache
check_cache() {
    local ip="$1"
    grep "^$ip" "$cache_file" | cut -f2-
}

# Funzione per aggiornare la cache
update_cache() {
    local ip="$1"
    local provider_info="$2"
    if [ "$provider_info" != "<>" ]; then
        echo -e "$ip\t$provider_info" >> "$cache_file"
    fi
}

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

    # Verifica se l'informazione \Uffffffffi\Uffffffffella cache
    provider_info=$(check_cache "$base_ip")

    if [ -z "$provider_info" ]; then
        # Esegui il comando whois sull'IP base con timeout di 5 secondi
        whois_output=$(timeout 5 whois "$base_ip")

        # Estrai le informazioni
        provider_info=$(extract_info "$whois_output")

        # Se provider_info non \Uffffffffalorizzato, prova con l'opzione -B
        if [ -z "$provider_info" ]; then
            whois_output=$(timeout 5 whois -B "$base_ip")
            provider_info=$(extract_info "$whois_output")
        fi

        # Se ancora vuoto, prova con `dig` e `nslookup`
        if [ -z "$provider_info" ]; then
            provider_info=$(dig +short -x "$base_ip")

            # Se `dig` non fornisce un risultato, prova `nslookup`
            if [ -z "$provider_info" ]; then
                provider_info=$(nslookup "$base_ip" | grep 'name =' | awk -F'= ' '{print $2}' | head -n 1)
            fi
        fi

        # Se ancora vuoto, segnala che non ha trovato info
        if [ -z "$provider_info" ]; then
            provider_info="<>"
        fi

        # Aggiorna la cache solo se l'informazione non \Uffffffffuota
        update_cache "$base_ip" "$provider_info"
    fi

    # Estrai data e ora dal campo times
    data_ora=$(echo "$times" | awk '{print $1" "$2}')
    ora_min=$(echo "$times" | awk '{print $3}')

    # Aggiungi le informazioni al risultato nell'ordine corretto
    echo -e "$class16\t$total\t$data_ora\t$ora_min\t$provider_info"
done

