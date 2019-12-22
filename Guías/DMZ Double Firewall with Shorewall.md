# Zonas desmilitarizadas con Shorewall (doble firewall)

## Tarea: DMZ con doble firewall usando Shorewall

### Cortafuegos de acceso

En la máquina **ACCESO** creamos los siguientes archivos:

Creamos una zona para cada segmento (red externa, DMZ, red interna)
```sh
# /etc/shorewall/zones
# ZONE  TYPE    	OPTIONS
fw	firewall
net	ipv4
dmz     ipv4     
loc     ipv4    
```
Como dos zonas tienen la misma interfaz de red, especificamos sus segmentos:
```sh
# /etc/shorewall/host
# ZONE	HOST			OPTIONS
dmz	enp0s3:10.20.20.0/24	-
loc	enp0s3:10.10.10.0/24	-
```
A la interfaz no le designamos una zona en concreto
```sh
# /etc/shorewall/interfaces
#ZONE           INTERFACE       OPTIONS
-               enp0s3          -
net		enp0s8		-
```
Hacemos que las políticas por defecto sean de denegar:
```sh
# /etc/shorewall/policy
net	all	DROP	info
dmz	all	DROP	info
loc	all	DROP	info
all	all	REJECT	info
```
Enmascaramos el tráfico de la red interna y la DMZ:
```sh
# /etc/shorewall/masq
enp0s3	10.10.10.0/24	# LOC
enp0s3	10.20.20.0/24	# DMZ
```
Permitimos conexiones HTTP, HTTPS, SMTP, POP3.
```sh
# /etc/shorewall/rules
?SECTION ALL
?SECTION ESTABLISHED
?SECTION RELATED
?SECTION INVALID
?SECTION UNTRACKED
?SECTION NEW

Invalid(DROP)	net		all		tcp
DNS(ACCEPT)	dmz		net
Ping(DROP)   	net             $FW

Ping(ACCEPT)    loc             $FW
Ping(ACCEPT)    dmz             $FW
Ping(ACCEPT)    loc             dmz
Ping(ACCEPT)    dmz             loc
Ping(ACCEPT)    dmz             net

ACCEPT		$FW		net		icmp
ACCEPT		$FW		loc		icmp
ACCEPT		$FW		dmz		icmp

# Redireccion puertos http, https, smtp, pop3 de la red externa a la DMZ
DNAT    net             dmz:10.20.20.22 tcp     80,443
DNAT    net             dmz:10.20.20.22 tcp     25,110
# Acceso DNS desde la red interna y la DMZ a la red externa
DNS(ACCEPT)     loc     net
DNS(ACCEPT)     dmz     net
```


### Cortafuegos de contención

En la máquina **CONTENCIÓN** creamos los siguientes archivos:

Creamos una zona para cada segmento (red externa con DMZ, red interna)
```sh
# /etc/shorewall/zones
# ZONE  TYPE    	OPTIONS
fw	firewall
net	ipv4
dmz:net	ipv4     
loc     ipv4    
```

```sh
# /etc/shorewall/host
# ZONE	HOST			OPTIONS
dmz     enp0s8:10.20.20.0/24    broadcast

```
Especificamos los host según su interfaz (como DMZ pertenece a la externa, no se pone)
```sh
# /etc/shorewall/interfaces
#ZONE               INTERFACE           OPTIONS
loc                 enp0s3              -
net		    enp0s8		-
```
Hacemos que las políticas por defecto sean de denegar todo aquello ajeno a la red interna o DMZ:
```sh
# /etc/shorewall/policy
net	loc	DROP	info
dmz	loc	NONE	info
loc	all	NONE	info
all	all	REJECT	info
```

No enmascararemos ni usaremos un archivo rules para el FW de contención dado que no es necesario en nuestro caso.

### Algunas comprobaciones

Con el comando `iptables -L [nombre de la cadena]` podemos ver las reglas definidas por Shorewall:

```
# iptables -L net-dmz
# Regla de acceso hacia la DMZ desde el exterior
ACCEPT     tcp  --  anywhere 
	multiport dports http,https,smtp,pop3
```

Escaneando la red desde fuera y sólo nos muestra el resultado para el FW :
```
25/tcp  open   smtp
80/tcp  closed http
110/tcp open   pop3
443/tcp closed https
```
En mi caso, en la DMZ, `apache2` estaba parado, por lo que muestra el puerto `80` y el `443` como cerrado.

Si ponemos el comando `service apache2 start` y repetimos el escaneo, el resultado es:
```
25/tcp  open   smtp
80/tcp  open   http
110/tcp open   pop3
443/tcp closed https
```
El puerto `https`está cerrado debido a que no lo tenemos implementado.
