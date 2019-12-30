# Detectores de intrusiones (Suricata)

## TAREA ENTREGABLE

### Reglas emerging-chat.rules

Se interceptarán paquetes similares a los enviados por aplicaciones de chat conocidas. En este caso, la regla que activaremos será:

```
alert tcp $HOME_NET any ->
$EXTERNAL_NET 6666:7000 (msg:
"GPL CHAT IRC Channel join";
flow:to_server,established; content:
"JOIN |3a 20||23|"; fast_pattern;
nocase; flowbits:set,is_proto_irc;
classtype:policy-violation; sid:2101729;
rev:11; metadata:created_at 2010_09_23,
updated_at 2019_10_07;)
```

Observamos que cualquier conexión desde la víctima hacia la red externa por medio de cualquier puerto **TCP** entre **6666** al **7000** con la cadena `
JOIN` y tres bytes concretos será registrada.

Por ello, levantaremos un servidor con `nc` en la máquina `openvas` y nos conectaremos con la máquina `víctima`:

```
openvas:~# nc -lp 6666 
victima:~# echo -e "JOIN \x3a\x20\x23"
	| nc openvas.ssi.net 6666   [^C]
```

Como vemos, esto simula una conexión `IRC` en la cual nos unimos a un canal IRC.

**Suricata** nos avisa de una posible violación de políticas corporativas:

```sh
ids:~# tail -f /var/log/suricata/fast.log 
	[...]
12/30/2019-20:28:26.653733  [**]
[1:2101729:11] GPL CHAT IRC Channel join [**]
[Classification: Potential Corporate Privacy
Violation] [Priority: 1] {TCP}
192.168.100.111:36972 -> 193.147.87.47:6666
```

### Reglas emerging-p2p.rules

Esta vez registraremos cualquier uso de aplicaciones `p2p`. En concreto, registraremos el uso de la aplicación **FFTorrent**:

```
alert http $HOME_NET any ->
$EXTERNAL_NET any (msg:
"ET P2P FFTorrent P2P Client User-Agent
(FFTorrent/x.x.x)"; flow:to_server,established;
content:"FFTorrent/"; depth:10; http_user_agent;
classtype:policy-violation; sid:2028942; rev:1;
metadata:affected_product
Windows_XP_Vista_7_8_10_Server_32_64_Bit,
attack_target Client_Endpoint, deployment
Perimeter, signature_severity Major,
created_at 2019_11_05, updated_at 2019_11_05;)
```

Como vemos, filtras las conexiones `HTTP` que usen como `User-Agent` la cadena `FFTorrent/`. Estas conexiones han de ser desde la máquina víctima hacia la red externa por medio de cualquier puerto.

Para replicarlo, levantaremos un servidor con **nc** o **apache2** en la máquina `openvas` y nos conectaremos con la máquina `víctima` usando **curl**:

```
openvas:~# nc -lp 80 || service apache2 start
victima:~# curl -A "FFTorrent/" openvas.ssi.net
```

Una vez simulada la conexión `p2p`,  **Suricata** nos avisa de otra posible violación de políticas corporativas:

```sh
ids:~# tail -f /var/log/suricata/fast.log 
	[...]
12/30/2019-20:40:41.141283  [**] [1:2028942:1]
ET P2P FFTorrent P2P Client User-Agent
(FFTorrent/x.x.x) [**]
[Classification: Potential Corporate
Privacy Violation] [Priority: 1] {TCP}
192.168.100.111:60360 -> 193.147.87.47:80
```

### Reglas emerging-policy.rules

Por último, registraremos el uso  *web crawlers*. En este caso, usaremos la herramienta `curl` con dicha finalidad:

```
alert http $EXTERNAL_NET any -> $HOME_NET any
(msg:"ET POLICY POSSIBLE Web Crawl using Curl";
flow:established,to_server;
content:"User-Agent|3a 20|curl"; http_header;
nocase; threshold: type both, track by_src,
count 10, seconds 60;
reference:url,curl.haxx.se;
reference:url,doc.emergingthreats.net/2002825;
classtype:attempted-recon; sid:2002825; rev:10;
metadata:created_at 2010_07_30, updated_at
2019_10_11;)
```

En este caso, si cualquier máquina externa hace más de **10** peticiones usando `curl` en menos de **60** segundos, *Suricata* nos avisará. Para replicarlo haremos lo siguiente:

```
victima:~# service apache2 start
openvas:~# for i in {1..10}; \
	do curl victima.ssi.net; done
```

El resultado es el esperado:

```sh
ids:~# tail -f /var/log/suricata/fast.log 
	[...]
12/30/2019-21:40:41.338921 
[**] [1:2002825:10]
ET POLICY POSSIBLE Web Crawl using Curl
[**] [Classification: Attempted Information Leak]
[Priority: 2] {TCP}
193.147.87.47:47820 -> 192.168.100.111:80
```























