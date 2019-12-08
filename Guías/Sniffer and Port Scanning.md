# Escucha y análisis de tráfico + Escaneo de puertos

#### Diego Enrique Fontán Lorenzo - 77482931N

## Ejercicio 1

### TELNET
Primero iniciaremos **Wireshark** en la máquina **Observador**:

	root@observador: wireshark

Iniciamos la captura de tráfico *esnifando* la red `enp0s3`.
Luego vamos a la máquina **Interno1** y ejecutamos el comando `telnet` para conectarnos a **Interno 2**:

	root@interno1: telnet 192.168.100.22
	
	Trying 192.168.100.22...
	Connected to 192.168.100.22.
	Escape character is '^]'.

	Linux 4.9.0-11-amd64 (interno2.ssi.net) (pts/0)

	interno2.ssi.net nombre: usuario
	usuario
	Contraseña: usuario
		[...]
	usuario@interno2:~$ 

Como vemos, nos hemos podido conectar correctamente a la máquina **Interno2** usando las credenciales `usuario:usuario`.

Ahora volvemos a la máquina **Observador** y filtramos los paquetes mediante el filtro `telnet`. Una vez hecho esto, seguimos la primera conexión `TCP` que nos aparece y podemos observar en **texto plano** cómo ha sido el intercambio de datos:

	........... ..!.."..'.....#..%..&.....
	..#..'..$..%..&..$........!..".."...........P..
	....".....b........b.... B.

	.........................."......
	.....#.....'............38400,38400..
	..#.interno1.ssi.net:0.0....'..
	DISPLAY.interno1.ssi.net:0.0......
	xterm................!........".......
	........"......"...........

	Linux 4.9.0-11-amd64 (interno2.ssi.net) (pts/0)
  

	interno2.ssi.net nombre: usuario
	usuario
	Contrase..a: usuario	  
		[...]
	.]0;usuario@interno2: ~.usuario@interno2:~$ls -l
	ls -l
	total 0
	.]0;usuario@interno2: ~.usuario@interno2:~$ exit
	exit
	logout
	Connection to 192.168.100.22 closed.

Al realizarse la conexión mediante **telnet**, las comunicaciones no están cifradas, por lo que las credenciales quedan expuestas.

### SSH

Ahora vamos a repetir el mismo experimento usando `SSH` para conectarnos de la máquina **Interno1** a la máquina **Interno2**:

	root@interno1: ssh usuario@192.168.100.22

Curiosamente, también podemos apreciar que las conexiones van en texto plano dado que **Wireshark** comprueba que dichas conexiones van por el protocolo `telnet`:

	ssh usuario@192.168.100.22

	ssh usuario@192.168.100.22
	usuario@192.168.100.22's password: usuario

	..!...Linux interno2.ssi.net 4.9.0-11-amd64
		[...]
	Last login: Sun Dec 8 07:44:25 2019 from 192.168.100.22
	.]0;usuario@interno2: ~.usuario@interno2:~$ ls -l
	ls -l
	total 0
	.]0;usuario@interno2: ~.usuario@interno2:~$ exit
	exit
	logout
	Connection to 192.168.100.22 closed.
	.
	.]0;usuario@interno2: ~.usuario@interno2:~$

Me resulta extremadamente curioso este aspecto, dado que por defecto, `SSH` debería viajar cifrado.

Es más, leyendo el manual de `OpenSSH`, podemos ver que dice claramente:

	Finally, if other authentication methods fail,
	ssh prompts the user for a pass‐ word.
	The password is sent to the remote host
	for checking; however, since all communications
	are encrypted, the password cannot be seen by
	someone listening on the network.

> Dejaré el estudio de este tema para más adelante, por no ser parte de la práctica, pero me parece cuanto menos interesante...

### HTTP

Repetiremos el procedimiento de *esnifar* la red, pero esta vez realizaremos peticiones **HTTP**.

#### Lynx

Primero usaremos el navegador mediante consola llamado `Lynx` para realizar las peticiones al servidor web de la máquina **Interno2**:

	root@interno1: lynx 192.168.100.22

En mi caso no me ha respondido correctamente a la primera, así que he tenido que reiniciar el servidor **Apache** ejecutando `service apache2 restart`.

Si vamos a **Wireshark**, también podemos observar la petición en **texto plano**, igual que en los dos casos anteriores:

	lynx 192.168.100.22
	lynx 192.168.100.22
	Looking up '192.168.100.22' first
	.
		[...]
	..(B.[0;1m.[33m.[44m
	Getting http://192.168.100.22
	/.[K.[39;49m.(B.[m
	
	..(B.[0;1m.[33m.[44m
	Looking up 192.168.100.22
	.[K.[39;49m.(B.[m

	..(B.[0;1m.[33m.[44m
	Making HTTP connection to 192.168.100.22
	.[39;49m.(B.[m

	..(B.[0;1m.[33m.[44m
	Sending HTTP request..
	[K.[39;49m.(B.[m

	..(B.[0;1m.[33m.[44m
	HTTP request sent; waiting for response..
	[39;49m.(B.[m.[5G.(B.[0;1m.[33m.[44m
	/1.1 200 OK.
	[K.[39;49m.(B.[m

	..(B.[0;1m.[33m.[44m
	Data transfer complete
	.[39;49m.(B.[m.[2;27H.(B.[0;1m.[33m.[44m
	Aplicaciones web vulnerables

	.[4G.(B.[0m.[35m.[40m * .[32m.[40m
	Foro vulnerable (XSS + SQLi)
	.[4G.[35m.[40m * .[32m.[40m
	Damn Vulnerable Web Application (DVWA)
	.[4G.[35m.[40m * .[32m.[40m
	OWASP Mutillidae II
	..[21d.[39;49m.(B.[m

	.[3G.[37m.[40m
	Arrow keys: Up and Down to move.
	Right to follow a link; Left to go back.
	H)elp O)ptions P)rint G)o M)ain screen
	Q)uit /=search [delete]=history list
	.[39;49m.(B.[m..[22d.(B.[0;1m.[33m.[44m
	Commands: Use arrow keys to move, '?' for help,
	'q' to quit, '<-' to go back..
	[39;49m.(B.[m.[4;8H.(B.[0;1m.[33m.[40m
	Foro vulnerable (XSS + SQLi).[7G.[39;49m.(B.[m

#### QupZilla

Podemos repetir la prueba de `HTTP` usando un navegador con interfaz gráfica como **QupZilla**. Sólamente tenemos que abrirlo y acceder a la IP de la máquina **Interno2**.

En este caso, usaré la opción de **Wireshark** llamada `Follow HTTP Stream` dado que nos mostrará en un formato más legible la petición:

```http
GET / HTTP/1.1

Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8

User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/538.1 (KHTML, like Gecko) QupZilla/1.8.9 Safari/538.1

Accept-Language: es-ES,es;q=0.8

Connection: Keep-Alive

Accept-Encoding: gzip, deflate

Host: 192.168.100.22


HTTP/1.1 200 OK
Date: Sun, 08 Dec 2019 07:03:33 GMT
Server: Apache/2.4.25 (Debian)
Last-Modified: Sun, 14 Oct 2018 16:33:41 GMT
ETag: "151-57832e229507b-gzip"
Accept-Ranges: bytes
Vary: Accept-Encoding
Content-Encoding: gzip
Content-Length: 211
Keep-Alive: timeout=5, max=100
Connection: Keep-Alive
Content-Type: text/html

<html>
<body>
<h1>Aplicaciones web vulnerables</h1>
<ul>
<li> <a href="foro"> Foro vulnerable (XSS + SQLi)</a></li>
<!--
<li> <a href="wordpress"> Wordpress vulnerable </a></li>
-->
<li> <a href="DVWA"> Damn Vulnerable Web Application (DVWA) </a></li>
<li> <a href="mutillidae"> OWASP Mutillidae II </a></li>
</ul>
</body>
</html>
```

```http
GET /favicon.ico HTTP/1.1
Referer: http://192.168.100.22/
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/538.1 (KHTML, like Gecko) QupZilla/1.8.9 Safari/538.1
Accept: */*
Accept-Language: es-ES,es;q=0.8
Connection: Keep-Alive
Accept-Encoding: gzip, deflate
Host: 192.168.100.22

HTTP/1.1 404 Not Found
Date: Sun, 08 Dec 2019 07:03:33 GMT
Server: Apache/2.4.25 (Debian)
Content-Length: 289
Keep-Alive: timeout=5, max=99
Connection: Keep-Alive
Content-Type: text/html; charset=iso-8859-1

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL /favicon.ico
was not found on this server.</p>
<hr>
<address>Apache/2.4.25 (Debian) Server at
192.168.100.22 Port 80</address>
</body></html>
```

Siguiendo el *HTTP Stream* es más sencillo ver la speticiones realizadas. En este caso son dos peticiones de tipo `GET`:

1. Pide el archivo raíz de la página
2. Pide el archivo `favicon.ico` (el cual no encuentra)

## SSL

Ahora vamos a volver a realizar escuchas sobre las conexiones `HTTP`, con la diferencia de que vamos a habilitar el cifrado al servidor **Apache**. Para ello vamos a la máquina **Interno2** y ejecutamos los siguientes comandos:
	
	root@interno2: mkdir /etc/apache2/ssl/
	root@interno2: make-ssl-cert
		/usr/share/ssl-cert/ssleay.cnf
		/etc/apache2/ssl/apache.pem

 >

	Nombre: interno2.ssi.net

>

	root@interno2: openssl x509 -text -in
		/etc/apache2/ssl/apache.pem
	root@interno2: openssl rsa -text -in
		/etc/apache2/ssl/apache.pem
	root@interno2: nano
		/etc/apache2/sites-available/default-ssl.conf

Y editamos la configuración de **Apache** para añadir el certificado:

	SSLEngine on
		[...]
	SSLCertificateFile /etc/apache2/ssl/apache.pem              
	SSLCertificateKeyFile /etc/apache2/ssl/apache.pem

Por último, habilitamos el módulo de `SSL` de **Apache** y reiniciamos el servidor:

	root@interno2: a2enmod ssl
	root@interno2: a2ensite default-ssl 
	root@interno2: service apache2 restart

Lo que nos queda hacer es repetir las pruebas escuchando el tráfico de red a ver si ahora aparece encriptado.

Para ello, vamos a volver a entrar en la web usando `QupZilla` en modo de **navegación privada** y nos conectaremos a la URL `https://interno2.ssi.net/`.

Tras aceptar el certificado, podemos ver que accedemos correctamente.

Ahora, si vamos al observador, nos damos cuenta de que ya no podemos ver ninguna petición de tipo `HTTP`, pero sí vemos que aparecen varias de tipo `TLS`. Además, ninguna de estas nos muestra texto si seguimos sus respectivos *Streams*, así que intentaremos ver los *TCP Streams* de la petición:

	............l.<.....nN=.7...E...5H+v.o{Xf.D....
	0.,.(.$............k.j.i.h.9.8.7.6..
	.......2...*.&.......=.5...../.+.'.#...
	.........g.@.?.>.3.2.1.0.........E.D.C.B.1.-.).
	%.......<./...A.......C.........
	interno2.ssi.net..............................
	..... ..#...............................
	......................................
	.......................................
	........................................
	........................................
	........................................
	.............................F...B...B..
	......}..S....b.[;..5..[.4....0..................
	...#......................0...0.........
	......c..0. *.H..	.....0.1.0...U....
	interno2.ssi.net0..
	191208071246Z.
	291205071246Z0.1.0...U....interno2.ssi.net0.."0
		[...]
	..U....0.0...U....0...interno2.ssi.net0
		[...]
	....D.......5\...........P-..........
	m...F.M..0.g......?-......3FT.ea.o=...
	...Zn....H....O.+.c...........
	(....3.....JA.^P.... .....D...J.(......@.....SN.v..
	..=.s..Y..n..Ca.......[n.....;.....^.J.(U...
		[...]
	....g'....T...N.x..X.......gG....&.B_;
	<.......:Sr.9..lod....j.........=.".X{.oQ4
	.s^.c'x.'%q.a........6.....}O..C..2x.....=
	...@..w.L6?.M..\[.-f...L..~j..yr$[[..*.aT....-.hHM..&
	.=.A.<...:.....VW.|r...-....i....k]..z.J^w..g.

Queda comprobado que ahora las conexiones son prácticamente ilegibles, dado que sólamente podemos distinguir correctamente la dirección `interno2.ssi.net`, pero el resto de información parece totalmente arbitraria.

## Ejercicio 2

Ahora pasaremos al uso de `nmap`, la cual, personalmente, es de mi herramientas favoritas.

Lo primero de todo será realizar un *Ping Sweeping* para comprobar mediante *ICMP* las máquinas que están disponibles:

	root@observador: nmap -sP 192.168.100.*
	root@observador: nmap -sP 192.168.100.0/24

La respuesta es la esperada:

	Starting Nmap 7.40 ( https://nmap.org ) at
	2019-12-08 08:34 CET
	Nmap scan report for interno1.ssi.net (192.168.100.11)
	Host is up (-0.10s latency).
	MAC Address: 08:00:27:11:11:11
	(Oracle VirtualBox virtual NIC)
	Nmap scan report for interno2.ssi.net (192.168.100.22)
	Host is up (0.00072s latency).
	MAC Address: 08:00:27:22:22:22
	(Oracle VirtualBox virtual NIC)
	Nmap scan report for observador.ssi.net
	(192.168.100.33)
	Host is up.
	Nmap done: 256 IP addresses (3 hosts up)
	scanned in 2.95 seconds

Vemos que existen máquinas en las direcciones `.11` (interno1), `.22` (interno2) y `.33` (observador).

Ahora, realizaremos un escaneo más a fondo para enumerar servicios expuestos y sobre qué sistema operativo corren. Aunque en la práctica aparece este comando:

	nmap -sT -O -sV 192.168.100.11

Me voy a tomar la libertad de realizar un escaneo más completo y agresivo, al cual le añadamos la opción de guardar nuestros resultados para evitar tener que repetirlo:

	nmap -A -T5 -sT -O -sC -sV -oA interno1
		192.168.100.11

>

	Starting Nmap 7.40 ( https://nmap.org )
	at 2019-12-08 08:39 CET
	Nmap scan report for interno1.ssi.net
	(192.168.100.11)
	Host is up (0.00091s latency).
	Not shown: 992 closed ports
	PORT     STATE SERVICE VERSION
	21/tcp   open  ftp     OpenBSD ftpd 6.4
		(Linux port 0.17)
	22/tcp   open  ssh     OpenSSH 7.4p1
		Debian 10+deb9u7 (protocol 2.0)
	| ssh-hostkey: 
	|   2048 5c:c2:ce:3b:c0:34:83:00:af:6e:45:65:c2:f0:97:99
		(RSA)
	|_  256 8e:7f:44:51:7c:3f:b6:a0:c0:5e:76:98:5e:67:13:5e
		(ECDSA)
	23/tcp   open  telnet
	25/tcp   open  smtp    Postfix smtpd
	|_smtp-commands: base.home, PIPELINING,
	SIZE 10240000, VRFY, ETRN, STARTTLS, ENHANCEDSTATUSCODES, 8BITMIME, DSN, SMTPUTF8, 
	79/tcp   open  finger  Debian fingerd
	| finger: Login     Name       Tty      Idle  Login Time   Office     Office Phone\x0D
	|_root      root      *tty1     6:49  Dec  8 01:50\x0D
	110/tcp  open  pop3    Dovecot pop3d
	|_pop3-capabilities: RESP-CODES UIDL CAPA AUTH-RESP-CODE SASL TOP PIPELINING
	143/tcp  open  imap    Dovecot imapd
	|_imap-capabilities: LOGINDISABLEDA0001 ID more have listed post-login OK IMAP4rev1 capabilities Pre-login LOGIN-REFERRALS SASL-IR LITERAL+ IDLE ENABLE
	3306/tcp open  mysql   MariaDB (unauthorized)
	1 service unrecognized despite returning data. If you know the service/version, please submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
	SF-Port23-TCP:V=7.40%I=7%D=12/8%Time=5DECA8C4%P=x86_64-pc-linux-gnu%r(NULL
	SF:,15,"\xff\xfb%\xff\xfb&\xff\xfd\x18\xff\xfd\x20\xff\xfd#\xff\xfd'\xff\x
	SF:fd\$")%r(GenericLines,15,"\xff\xfb%\xff\xfb&\xff\xfd\x18\xff\xfd\x20\xf
	SF:f\xfd#\xff\xfd'\xff\xfd\$")%r(tn3270,15,"\xff\xfb%\xff\xfb&\xff\xfd\x18
	SF:\xff\xfd\x20\xff\xfd#\xff\xfd'\xff\xfd\$")%r(GetRequest,15,"\xff\xfb%\x
	SF:ff\xfb&\xff\xfd\x18\xff\xfd\x20\xff\xfd#\xff\xfd'\xff\xfd\$")%r(RPCChec
	SF:k,15,"\xff\xfb%\xff\xfb&\xff\xfd\x18\xff\xfd\x20\xff\xfd#\xff\xfd'\xff\
	SF:xfd\$")%r(Help,15,"\xff\xfb%\xff\xfb&\xff\xfd\x18\xff\xfd\x20\xff\xfd#\
	SF:xff\xfd'\xff\xfd\$")%r(SIPOptions,15,"\xff\xfb%\xff\xfb&\xff\xfd\x18\xf
	SF:f\xfd\x20\xff\xfd#\xff\xfd'\xff\xfd\$")%r(NCP,15,"\xff\xfb%\xff\xfb&\xf
	SF:f\xfd\x18\xff\xfd\x20\xff\xfd#\xff\xfd'\xff\xfd\$");
	MAC Address: 08:00:27:11:11:11 (Oracle VirtualBox virtual NIC)
	Device type: general purpose
	Running: Linux 3.X|4.X
	OS CPE: cpe:/o:linux:linux_kernel:3 cpe:/o:linux:linux_kernel:4
	OS details: Linux 3.2 - 4.6
	Network Distance: 1 hop
	Service Info: Host:  base.home; OS: Linux; CPE: cpe:/o:linux:linux_kernel

	TRACEROUTE
	HOP RTT     ADDRESS
	1   0.91 ms interno1.ssi.net (192.168.100.11)

	OS and Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
	Nmap done: 1 IP address (1 host up) scanned in 59.43 seconds

De este escaneo sacamos cosas muy interesantes:

1. El sistema operativo es **Linux**: 3.2 - 4.6
2. Existen varios puertos abiertos, que son: `21`, `22`, `23 `, `25`, `79`, `110`, `143`, `3306` (todos ellos **TCP**, dado que no hemos escaneado puertos **UDP**)
3. Tenemos la versión del software que maneja dichos servicios.
4. Nos aparecen comando que podemos usar en el servidor `SMTP`.
5. **Observamos que existe un usuario** `root` **que está conectado**.
6. Aparecen varios parámetros de configuración pertenecientes a varios de los servicios escaneados.

---

Como hemos dicho, tanto el escaneo estándar como el que he llevado a cabo son de caracter **agresivo**, por lo que dejan huella en los *logs* del sistema.

Para comprobarlo sólamente tendremos que ir a la máquina **Interno1** y ejecutar el siguiente comando:

		[...]
	Dec  8 08:39:42 interno1 inetd[371]: could not getpeername
	Dec  8 08:39:42 interno1 inetd[371]: could not getpeername
	Dec  8 08:39:42 interno1 in.fingerd[1916]: warning: can't get client address: Connection reset by peer
	Dec  8 08:39:42 interno1 in.fingerd[1916]: connect from unknown (unknown)
	Dec  8 08:39:42 interno1 dovecot: imap-login: Disconnected (disconnected before auth was ready, waited 0 secs): user=<>, rip=192.168.100.33, lip=192.168.100.11, session=<wpjWYSyZ1NnAqGQh>
	Dec  8 08:39:42 interno1 dovecot: pop3-login: Disconnected (no auth attempts in 0 secs): user=<>, rip=192.168.100.33, lip=192.168.100.11, session=<YhzXYSyZ6LjAqGQh>
	Dec  8 08:39:42 interno1 postfix/smtpd[1915]: connect from unknown[unknown]
	Dec  8 08:39:42 interno1 postfix/smtpd[1915]: lost connection after CONNECT from unknown[unknown]
	Dec  8 08:39:42 interno1 postfix/smtpd[1915]: disconnect from unknown[unknown] commands=0/0
	Dec  8 08:39:42 interno1 telnetd[1923]: connect from 192.168.100.33 (192.168.100.33)
	Dec  8 08:39:42 interno1 in.ftpd[1922]: connect from 192.168.100.33 (192.168.100.33)
	Dec  8 08:39:42 interno1 in.fingerd[1924]: connect from 192.168.100.33 (192.168.100.
		[...]

Para llenar el *log* con conexiones de tipo `SYN`, vamos a ejecutar el siguiente comando de `iptables`:

	root@interno1: iptables -A INPUT -i
		enp0s3 -p tcp --tcp-flags SYN SYN
		-m state --state NEW -j LOG
		--log-prefix "Inicio conex:"

Ahora vigilaremos el archivo de *logs* mediante `tail -f` y realizaremos diferentes tipos de escaneo.

### TCP Scanning

Comando:

	root@observador: nmap -sT 192.168.100.11

Como vemos, los *logs* son abundantes:

	Dec  8 08:55:20 interno1 kernel: [ 5273.094143] Inicio conex:IN=enp0s3 OUT= MAC=08:00:27:11:11:11:08:00:27:33:33:33:08:00 SRC=192.168.100.33 DST=192.168.100.11 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=43066 DF PROTO=TCP SPT=48636 DPT=8899 WINDOW=29200 RES=0x00 SYN URGP=0 
	Dec  8 08:55:20 interno1 telnetd[2012]: warning: can't get client address: Connection reset by peer
	Dec  8 08:55:20 interno1 in.ftpd[2013]: connect from unknown (unknown)
	Dec  8 08:55:20 interno1 ftpd[2013]: getpeername (in.ftpd): Transport endpoint is not connecte
	
### SYN Scanning

Comando:

	root@observador: nmap -sS 192.168.100.11

En este caso, también tenemos logs de gran tamaño, pero un poco menores en comparación con el escaneo anterior y con menos información:

	Dec  8 08:57:21 interno1 kernel: [ 5394.320124] Inicio conex:IN=enp0s3 OUT= MAC=08:00:27:11:11:11:08:00:27:33:33:33:08:00 SRC=192.168.100.33 DST=192.168.100.11 LEN=44 TOS=0x00 PREC=0x00 TTL=43 ID=59101 PROTO=TCP SPT=56599 DPT=4000 WINDOW=1024 RES=0x00 SYN URGP=0 
	Dec  8 08:57:21 interno1 kernel: [ 5394.320168] Inicio conex:IN=enp0s3 OUT= MAC=08:00:27:11:11:11:08:00:27:33:33:33:08:00 SRC=192.168.100.33 DST=192.168.100.11 LEN=44 TOS=0x00 PREC=0x00 TTL=58 ID=27543 PROTO=TCP SPT=56599 DPT=50300 WINDOW=1024 RES=0x00 SYN URGP=0 
	Dec  8 08:57:21 interno1 kernel: [ 5394.320393] Inicio conex:IN=enp0s3 OUT= MAC=08:00:27:11:11:11:08:00:27:33:33:33:08:00 SRC=192.168.100.33 DST=192.168.100.11 LEN=44 TOS=0x00 PREC=0x00 TTL=58 ID=52318 PROTO=TCP SPT=56599 DPT=2004 WINDOW=1024 RES=0x00 SYN URGP=0 
	Dec  8 08:57:21 interno1 kernel: [ 5394.320422] Inicio conex:IN=enp0s3 OUT= MAC=08:00:27:11:11:11:08:00:27:33:33:33:08:00 SRC=192.168.100.33 DST=192.168.100.11 LEN=44 TOS=0x00 PREC=0x00 TTL=44 ID=2874 PROTO=TCP SPT=56599 DPT=16018 WINDOW=1024 RES=0x00 SYN URGP=0

### NULL Scanning

Comando:

	root@observador: nmap -sN 192.168.100.11

En este caso vemos que no deja *log* ninguno, por lo que es totalmente invisible, pero que los resultados no son `100%` seguros, dado que los puertos aparecen como `open|filtered`. Aún así, nos muestra aquellos que **no** están cerrados, que es lo que nos interesa.

---

Con todo, podemos observar que para el atacante, la mayor diferencia es el tiempo empleado en cada escaneo:

| Tipo | Tiempo (seg) |
| --- | --- |
| TCP | 0.41 |
| SYN | 3.13 |
| NULL | 99.22 |

Elegir entre cada tipo dependerá de la huella que quiera dejar el atacante en el servidor remoto, dado que normalmente el tiempo no suele ser un impedimento.

# Corrigiendo dudas y errores

Me ha parecido muy curioso el tema de que por `SSH` mi conexión no fuera cifrada.

Es por ello que, aunque lo he solucionado, no voy a corregirlo arriba, sino que explicaré aquí mi razonamiento.

Lo que he hecho ha sido reiniciar el servicio mediante `service ssh restart` y volver a *esnifar* la conexión.

Resulta que ahora **sí** que encripta los datos:

	SSH-2.0-OpenSSH_7.4p1 Debian-10+deb9u7
	SSH-2.0-OpenSSH_7.4p1 Debian-10+deb9u7
	...4..v0.......}.va.......curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-
		[...]
	ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes128-cbc,aes192-cbc,aes256-cbc....umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1....umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1....none,zlib@openssh.com,zlib....none,zlib@openssh.com,zlib...........................,..... ...{..#J9.s f0...yh..e...1D.J.............
	....h....ecdsa-sha2-nistp256....nistp256...A...R.%L...$a{+..7a.U.........a._..........D.....%0....f`.&.>..x.p... q+...".QT.i..31..x...l...7.....J...d....ecdsa-sha2-nistp256...I...!..>.......M{6...;.... .C!.....J.O... H..J. hU. ..0..y,.../....@....] ..............
	...........z....0..(.56.=D.....o..Ah9.q......Q...j{J%R.."..^.`8mB....A.....L...W.Y
		[...]
	{....Op...~3{0...............&..d.Q..f..UASg..c._........{s..../..}j.A..CI..DT...y+.......L..........Y.?.!.......3.&.$...3.B&.p.+....D5cbOD.......:t. .|...E.kB....K.M.)..:.)U{..P...w.
	..u...c#......yr...h..b+..U...[...._!.1+.<._...I......'.....g9.P .(..-k1)+...J..I.......%.....<...y...n!o>
	..w........2\...:..B....],.'..85./..........85G.o..AR..|..G.....\.......Y..nt0.#c......~..q..k.J,........f..x.R
	[P..z.Ou....)...*...K.w..y.......

Mi razonmiento ante el por qué del problema no es más que el siguiente:

1. `SSH` intenta realizar la conexión de manera segura.
2. Si las negociaciones fallan, o el servicio no tiene el cifrado correspondiente, éste aceptará conectarse sin cifrado alguno.

Es posible que no funcione de esta manera y que el error haya sido otro, pero me ha parecido entretenido pararme a estudiar el problema, aunque no le dedicaré más tiempo dado que ya lo he solucionado.


