# Volúmenes lógicos y RAID software en GNU/Linux

## Tabla de contenidos
---
- Instalación del entorno de prácticas
- Comprobación de recursos
- RAID5
  - Preparación de los dispositivos
  - Creación del RAID5
- [LVM](#lvm)
  - Formateo EXT3
  - Montaje del RAID5
  - Extensión de dispositivos
  - Extensión de almacenamiento
- Cuestiones
- Bibliografía


<a name="install"></a>
## Instalación del entorno de prácticas
---
Iniciamos el autoinstalador para Linux

```sh
curl -o- \
http://ccia.esei.uvigo.es/docencia/CDA/1819/practicas//ejercicio-iscsi.sh | \
bash -
```

Nos mandará poner un identificador único. Después de esto, se nos abrirá nuestro nuevo entorno de pruebas.

Para poder loguearnos en los sistema deberemos introducir el usuario `root` junto a la contraseña `purple`.

Si no se nos inicia el entorno gráfico, deberemos ejecutar el siguiente comando:

```sh
startx
```

Una vez tengamos nuestro entorno preparado, procederemos a ejecutar la aplicación `LXTerminal` en cada máquina.


<a name="recursos"></a>
## Comprobación de recursos
---
Comprobamos los discos disponibles con cualquiera de los siguientes comandos en la máquina **DISCOS** (usaremos esta máquina hasta que se indique lo contrario):

```sh
lsblk
fdisk -l
parted -l
```

Personalmente prefiero `lsblk`. Una vez ejecutado ésta es su salida:

```sh
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   16G  0 disk
└─sda1   8:1    0   16G  0 part /
sdb      8:16   0    1G  0 disk
└─sdb1   8:17   0 1022M  0 part [SWAP]
sdc      8:32   0  100M  0 disk
sdd      8:48   0  100M  0 disk
sde      8:64   0  100M  0 disk
sdf      8:80   0  100M  0 disk
```

Como podemos comprobar, el sistema está montado sobre el disco `sda` y la partición SWAP sobre el `sdb`, pero disponemos a mayores cuatro discos para poder trabajar a gusto.


<a name="raid5"></a>
## RAID5
---
Procederemos con la creación de un RAID5 utilizando los dispositivos `/dev/sdc1`, `/dev/sdd1`, `/dev/sde1` y `/dev/sdf1`.


<a name="raid5-pre"></a>
### Preparación de los dispositivos
---
Primeramente, crearemos una partición primaria en los dispositivos `/dev/sdc`, `/dev/sdd`, `/dev/sde` y `/dev/sdf` asignándole todo el espacio disponible usando el comando `parted`.

```sh
parted /dev/sdc
  (parted) mklabel msdos        
  (parted) mkpart primary 1M 100%
  (parted) set 1 raid on
  (parted) quit
# Repetir el proceso usando /dev/sdd, /dev/sde y /dev/sdf
```

Comprobamos el resultado ejecutando `lsblk` de nuevo.

```sh
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   16G  0 disk
└─sda1   8:1    0   16G  0 part /
sdb      8:16   0    1G  0 disk
└─sdb1   8:17   0 1022M  0 part [SWAP]
sdc      8:32   0  100M  0 disk
└─sdc1   8:33   0   99M  0 part
sdd      8:48   0  100M  0 disk
└─sdd1   8:49   0   99M  0 part
sde      8:64   0  100M  0 disk
└─sde1   8:65   0   99M  0 part
sdf      8:80   0  100M  0 disk
└─sdf1   8:81   0   99M  0 part
```


<a name="raid5-create"></a>
### Creación del RAID5
---
Una vez creados los dispositivos necesarios para nuestro RAID, usaremos `mdadm` para construir y gestionar nuestro RAID5. En concreto ejecutaremos este comando:

```sh
mdadm --create --verbose /dev/md/md_RAID5 --level=raid5 --raid-devices=4 \
/dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1
```

El cual es bastante intuitivo y no necesita demasiada explicación:

```sh
mdadm [--create: Crear RAID] \
[--verbose: Muestra logs por pantalla] \
[/dev/md/md_RAID5: Crear el RAID en dicha ruta] \
[-level=raid5: Tipo de RAID] \
[--raid-devices=3: Utilizar 4 dispositivos para montarlo] \
[/dev/sdc1 /dev/sdd1 /dev/sde1 /dev/sdf1: Dispositivos disponibles para ser usados]
```

Se nos notificará del éxito de la operación con el siguiente mensaje:

```sh
mdadm: layout defaults to left-symmetric
mdadm: layout defaults to left-symmetric
mdadm: chunk size defaults to 512K
mdadm: size set to 100352K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md/md_RAID5 started.
```

Si ejecutamos de nuevo `lsblk` comprobaremos la creación del RAID

```sh
NAME      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda         8:0    0   16G  0 disk  
└─sda1      8:1    0   16G  0 part  /
sdb         8:16   0    1G  0 disk  
└─sdb1      8:17   0 1022M  0 part  [SWAP]
sdc         8:32   0  100M  0 disk  
└─sdc1      8:33   0   99M  0 part  
  └─md127   9:127  0  294M  0 raid5
sdd         8:48   0  100M  0 disk  
└─sdd1      8:49   0   99M  0 part  
  └─md127   9:127  0  294M  0 raid5
sde         8:64   0  100M  0 disk  
└─sde1      8:65   0   99M  0 part  
  └─md127   9:127  0  294M  0 raid5
sdf         8:80   0  100M  0 disk  
└─sdf1      8:81   0   99M  0 part  
  └─md127   9:127  0  294M  0 raid5
```

Si necesitamos información extra, podremos obtenerla de la siguiente manera:

```sh
mdadm --detail /dev/md/md_RAID5
```

Salida:

```sh
/dev/md/md_RAID5:
        Version : 1.2
  Creation Time : Sat Oct 20 19:47:01 2018
     Raid Level : raid5
     Array Size : 301056 (294.00 MiB 308.28 MB)
  Used Dev Size : 100352 (98.00 MiB 102.76 MB)
   Raid Devices : 4
  Total Devices : 4
    Persistence : Superblock is persistent

    Update Time : Sat Oct 20 19:47:03 2018
          State : clean
 Active Devices : 4
Working Devices : 4
 Failed Devices : 0
  Spare Devices : 0

         Layout : left-symmetric
     Chunk Size : 512K

           Name : discos.cda.net:md_RAID5  (local to host discos.cda.net)
           UUID : 714941af:9ae82212:a280cbd9:473bb324
         Events : 18

    Number   Major   Minor   RaidDevice State
       0       8       33        0      active sync   /dev/sdc1
       1       8       49        1      active sync   /dev/sdd1
       2       8       65        2      active sync   /dev/sde1
       4       8       81        3      active sync   /dev/sdf1
```

<a name="lvm"></a>
## LVM
---
Procederemos con la creación de un grupo de volúmenes LVM utilizando el RAID5 que constará de tres volúmenes lógicos llamados `UNO`, `DOS`, `COMPARTIDO`.


<a name="lvm-pv"></a>
### Creación del volumen físico
---
Lo primero será definir nuestro volumen físico en el RAID5 para crear posteriormente los volúmenes lógicos:

```sh
pvcreate /dev/md/md_RAID5
```

Se nos mostrará el mensaje `Physical volume "/dev/md/md_RAID5" successfully created.` si tuvimos éxito.


<a name="lvm-vg"></a>
### Creación del grupo de volúmenes
---
Para construir un grupo de volúmenes ejecutamos el siguiente comando.

```sh
vgcreate homelab /dev/md/md_RAID5
```

La salida `Volume group "homelab" successfully created` nos insica que la operación se ha efectuado correctamente.


<a name="lvm-lv"></a>
### Creación de los volúmenes lógicos
---
Es hora de gestionar nuestro espacio. Usaremos el comando `lvcreate` para generar volúmenes lógicos en nuestro grupo de volúmenes lógicos `homelab`. Cada uno de ellos tendrá 50MB y su correspondiente nombre como parámetros.

```sh
lvcreate homelab -L 50MB -n UNO
lvcreate homelab -L 50MB -n DOS
lvcreate homelab -L 50MB -n COMPARTIDO
```

Sabremos que hemos tenido éxito al ver la siguiente salida:

```sh
Rounding up size to full physical extent 52,00 MiB
  Logical volume "UNO" created.
Rounding up size to full physical extent 52,00 MiB
  Logical volume "DOS" created.
Rounding up size to full physical extent 52,00 MiB
  Logical volume "COMPARTIDO" created.
```

Por si acaso podemos usar la ya más que conocida herramienta `lsblk` para realizar la comprobación:

```sh
NAME                     MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda                        8:0    0   16G  0 disk  
└─sda1                     8:1    0   16G  0 part  /
sdb                        8:16   0    1G  0 disk  
└─sdb1                     8:17   0 1022M  0 part  [SWAP]
sdc                        8:32   0  100M  0 disk  
└─sdc1                     8:33   0   99M  0 part  
  └─md127                  9:127  0  294M  0 raid5
    ├─homelab-UNO        253:0    0   52M  0 lvm   
    ├─homelab-DOS        253:1    0   52M  0 lvm   
    └─homelab-COMPARTIDO 253:2    0   52M  0 lvm   
sdd                        8:48   0  100M  0 disk  
└─sdd1                     8:49   0   99M  0 part  
  └─md127                  9:127  0  294M  0 raid5
    ├─homelab-UNO        253:0    0   52M  0 lvm   
    ├─homelab-DOS        253:1    0   52M  0 lvm   
    └─homelab-COMPARTIDO 253:2    0   52M  0 lvm   
sde                        8:64   0  100M  0 disk  
└─sde1                     8:65   0   99M  0 part  
  └─md127                  9:127  0  294M  0 raid5
    ├─homelab-UNO        253:0    0   52M  0 lvm   
    ├─homelab-DOS        253:1    0   52M  0 lvm   
    └─homelab-COMPARTIDO 253:2    0   52M  0 lvm   
sdf                        8:80   0  100M  0 disk  
└─sdf1                     8:81   0   99M  0 part  
  └─md127                  9:127  0  294M  0 raid5
    ├─homelab-UNO        253:0    0   52M  0 lvm   
    ├─homelab-DOS        253:1    0   52M  0 lvm   
    └─homelab-COMPARTIDO 253:2    0   52M  0 lvm
```


<a name="iscsi"></a>
## iSCSI
---
Es el momento de gestionar nuestros vlúmenes lógicos para crear un sistema de archivos iSCSI.


<a name="iscsi-targets"></a>
### Creación de targets
---

Crearemos un target usando un iqn y un tid para identificarlo:

```sh
tgtadm --lld iscsi --mode target --op new --tid=1 \
--targetname iqn.2018-09.net.cda.discos:homelab.UNO
```

El comando se compone de los siguientes argumentos:

```sh
tgtadm [--lld iscsi: Driver/Tipo de almacenamiento] \
[--mode target: Esfecificación de objetivo (logicalunit, target...)] \
[--op new: Operación deseada - Crear] \
[--tid=1: Identificador (0 reservado)] \
[--targetname iqn.2018-09.net.cda.discos:homelab.UNO: Nombre siguiendo el estándar]
```

De esta misma forma, crearemos otros dos nuevos targets con los tid 2 y 3:

```sh
tgtadm --lld iscsi --mode target --op new --tid=2 \
--targetname iqn.2018-09.net.cda.discos:homelab.DOS

tgtadm --lld iscsi --mode target --op new --tid=3 \
--targetname iqn.2018-09.net.cda.discos:homelab.COMPARTIDO
```

Podemos confirmar que todo ha salido bien ejecutando la operación `show` del comando `tgtadm`:

```sh
tgtadm --lld iscsi --mode target --op show
```

Nos dará una salida siilar a esta:

```sh
Target 1: iqn.2018-09.net.cda.discos:homelab.UNO
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
    Account information:
    ACL information:
Target 2: iqn.2018-09.net.cda.discos:homelab.DOS
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00020000
            SCSI SN: beaf20
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
    Account information:
    ACL information:
Target 3: iqn.2018-09.net.cda.discos:homelab.COMPARTIDO
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00030000
            SCSI SN: beaf30
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
    Account information:
    ACL information:
```


<a name="iscsi-lun"></a>
### Creación de LUNs
---
Para la exposición de dispositivos usando LUN, el comando es muy similar al anterior, con la diferencia de que deberemos *bindear* Unidades Lógicas a Targets de la siguiente manera:

```sh
tgtadm --lld iscsi --mode logicalunit --op new \
--tid 1 --lun 1 --backing-store /dev/homelab/UNO
```

Del mismo modo asignaremos dispositivos de almacenamiento al resto de targets:

```sh
tgtadm --lld iscsi --mode logicalunit --op new \
--tid 2 --lun 2 --backing-store /dev/homelab/DOS

tgtadm --lld iscsi --mode logicalunit --op new \
--tid 3 --lun 3 --backing-store /dev/homelab/COMPARTIDO
```

Para confirmar que todo ha salido bien, ejecutamos la operación `show` de nuevo y nos fijamos en el `Backing storage path`:

```sh
Target 1: iqn.2018-09.net.cda.discos:homelab.UNO
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
        LUN: 1
            Type: disk
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 55 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/homelab/UNO
            Backing store flags:
    Account information:
    ACL information:
Target 2: iqn.2018-09.net.cda.discos:homelab.DOS
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00020000
            SCSI SN: beaf20
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
        LUN: 2
            Type: disk
            SCSI ID: IET     00020002
            SCSI SN: beaf22
            Size: 55 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/homelab/DOS
            Backing store flags:
    Account information:
    ACL information:
Target 3: iqn.2018-09.net.cda.discos:homelab.COMPARTIDO
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00030000
            SCSI SN: beaf30
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
        LUN: 3
            Type: disk
            SCSI ID: IET     00030003
            SCSI SN: beaf33
            Size: 55 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/homelab/COMPARTIDO
            Backing store flags:
    Account information:
    ACL information:
```


<a name="iscsi-firewall"></a>
### Control de accesos
---
Como nos interesa que cada volúmen lógico sea accedido según la siguiente tabla, debemos restringir el acceso mediante IP:

| LV | Propietario(s) |  | IP | Máquina |
| --- | --- |            | --- | --- |
| UNO | Cliente1 |       | 192.168.100.22 | Cliente1 |
| DOS | CLiente2 |       | 192.168.100.33 | Cliente2 |
| COMPARTIDO | Ambos |

Para ello, ejecutaremos la operación `bind` del comando `tgtadm` para conceder acceso a las direcciones IP especificadas:

```sh
# UNO
tgtadm --lld iscsi --mode target --op bind --tid 1 \
--initiator-address 192.168.100.22
# DOS
tgtadm --lld iscsi --mode target --op bind --tid 2 \
--initiator-address 192.168.100.33
# COMPARTIDO
tgtadm --lld iscsi --mode target --op bind --tid 3 \
--initiator-address 192.168.100.22
tgtadm --lld iscsi --mode target --op bind --tid 3 \
--initiator-address 192.168.100.33
```

De nuevo, podemos comprobar que todo ha salido bien si ejecutamos la operación `show` del comando `tgtadm`. Esta vez deberemos fijarnos en el apartado `ACL Information`:

```sh
Target 1: iqn.2018-09.net.cda.discos:homelab.UNO
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00010000
            SCSI SN: beaf10
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
        LUN: 1
            Type: disk
            SCSI ID: IET     00010001
            SCSI SN: beaf11
            Size: 55 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/homelab/UNO
            Backing store flags:
    Account information:
    ACL information:
        192.168.100.22
Target 2: iqn.2018-09.net.cda.discos:homelab.DOS
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00020000
            SCSI SN: beaf20
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
        LUN: 2
            Type: disk
            SCSI ID: IET     00020002
            SCSI SN: beaf22
            Size: 55 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/homelab/DOS
            Backing store flags:
    Account information:
    ACL information:
        192.168.100.33
Target 3: iqn.2018-09.net.cda.discos:homelab.COMPARTIDO
    System information:
        Driver: iscsi
        State: ready
    I_T nexus information:
    LUN information:
        LUN: 0
            Type: controller
            SCSI ID: IET     00030000
            SCSI SN: beaf30
            Size: 0 MB, Block size: 1
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: null
            Backing store path: None
            Backing store flags:
        LUN: 3
            Type: disk
            SCSI ID: IET     00030003
            SCSI SN: beaf33
            Size: 55 MB, Block size: 512
            Online: Yes
            Removable media: No
            Prevent removal: No
            Readonly: No
            SWP: No
            Thin-provisioning: No
            Backing store type: rdwr
            Backing store path: /dev/homelab/COMPARTIDO
            Backing store flags:
    Account information:
    ACL information:
        192.168.100.22
        192.168.100.33
```

<a name="raid5-ext3"></a>
### Formateo EXT3
---
Para formatear nuestro RAID en formato `ext3` ejecutaremos

```sh
mkfs.ext3 /dev/md/md_RAID5
```

Si no tenemos ningún error nos mostrará la siguiente salida:

```sh
Se está creando un sistema de ficheros con 200704 bloques de 1k y 50200 nodos-i
UUID del sistema de ficheros: 4017da92-621e-46cc-8225-d786e3c4660b
Respaldo del superbloque guardado en los bloques:
	8193, 24577, 40961, 57345, 73729

Reservando las tablas de grupo: hecho                           
Escribiendo las tablas de nodos-i: hecho                           
Creando el fichero de transacciones (4096 bloques): hecho
Escribiendo superbloques y la información contable del sistema de ficheros:
0/2hecho
```

<a name="raid5-mnt"></a>
### Montaje del RAID5
---
Montaremos nuestro RAID5 de la siguiente manera

```sh
mkdir /mnt/raid
mount /dev/md/md_RAID5 /mnt/raid/
```

Comprobaremos que se ha montado correctamente usando `lsblk`:

```sh
NAME      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda         8:0    0   16G  0 disk  
└─sda1      8:1    0   16G  0 part  /
sdb         8:16   0    1G  0 disk  
└─sdb1      8:17   0 1022M  0 part  [SWAP]
sdc         8:32   0  100M  0 disk  
└─sdc1      8:33   0   99M  0 part  
  └─md127   9:127  0  196M  0 raid5 /mnt/raid
sdd         8:48   0  100M  0 disk  
└─sdd1      8:49   0   99M  0 part  
  └─md127   9:127  0  196M  0 raid5 /mnt/raid
sde         8:64   0  200M  0 disk  
└─sde1      8:65   0  199M  0 part  
  └─md127   9:127  0  196M  0 raid5 /mnt/raid
sdf         8:80   0  100M  0 disk  
```

Para ver el espacio disponible usaremos el siguiente comando:

```sh
df -Th /mnt/raid
```

De esta forma nos mostrará que tenemos disponibles 175M en nuestro nuevo dispositivo

```sh
S.ficheros     Tipo Tamaño Usados  Disp Uso% Montado en
/dev/md127     ext3   186M   1,6M  175M   1% /mnt/raid
```

Crearemos un archivo de prueba de 1MB en `/mnt/raid` para comprobar que funciona correctamente usando `dd`:

```sh
dd bs=1MB count=0 seek=1 of=/mnt/raid/allzeros
ls -l /mnt/raid/allzeros
```

Como vemos, el archivo se ha creado correctamente:

```sh
0+0 registros leídos
0+0 registros escritos
0 bytes copied, 0,000191775 s, 0,0 kB/s
-rw-r--r-- 1 root root 1000000 oct 20 13:52 /mnt/raid/allzeros
```

Curiosamente, si vemos el espacio disponible con el comando `df`, veremos que nada ha cambiado:

```sh
S.ficheros     Tipo Tamaño Usados  Disp Uso% Montado en
/dev/md127     ext3   186M   1,6M  175M   1% /mnt/raid
```

Esto se debe a que el archivo `allzeros` no ocupa espacio real en el disco, dado que está formado por bytes nulos.

Si copiásemos cualquier otro fichero, el espacio sí que variaría:

```sh
cp /boot/initrd.img-4.9.0-7-amd64 /mnt/raid/
df -Th /mnt/raid/
```

Dando como resultado lo siguiente:

```sh
S.ficheros     Tipo Tamaño Usados  Disp Uso% Montado en
/dev/md127     ext3   186M    22M  155M  13% /mnt/raid
```


<a name="raid5-extend"></a>
### Extensión de dispositivos
---
Lo primero será desmontar nuestro RAID

```sh
umount /mnt/raid
```

Particionaremos el dispositivo `sdf` tal y como hicimos con el resto:

```sh
parted /dev/sdf
  (parted) mklabel msdos        
  (parted) mkpart primary 1M 100%
  (parted) set 1 raid on
  (parted) quit
```

Comprobamos el resultado con `lsblk`:

```sh
NAME      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda         8:0    0   16G  0 disk  
└─sda1      8:1    0   16G  0 part  /
sdb         8:16   0    1G  0 disk  
└─sdb1      8:17   0 1022M  0 part  [SWAP]
sdc         8:32   0  100M  0 disk  
└─sdc1      8:33   0   99M  0 part  
  └─md127   9:127  0  196M  0 raid5
sdd         8:48   0  100M  0 disk  
└─sdd1      8:49   0   99M  0 part  
  └─md127   9:127  0  196M  0 raid5
sde         8:64   0  200M  0 disk  
└─sde1      8:65   0  199M  0 part  
  └─md127   9:127  0  196M  0 raid5
sdf         8:80   0  100M  0 disk  
└─sdf1      8:81   0   99M  0 part
```

Para agregar nuestro nuevo dispositivo al RAID5, usaremos:

```sh
mdadm --add /dev/md/md_RAID5 /dev/sdf1
```

Si comprobamos el resultado con `mdadm --detail /dev/md/md_RAID5` veremos que podemos usarlo, pero aún no está dentro de nuestro array.

```sh
/dev/md/md_RAID5:
        Version : 1.2
  Creation Time : Sat Oct 20 12:49:13 2018
     Raid Level : raid5
     Array Size : 200704 (196.00 MiB 205.52 MB)
  Used Dev Size : 100352 (98.00 MiB 102.76 MB)
   Raid Devices : 3
  Total Devices : 4
    Persistence : Superblock is persistent

    Update Time : Sat Oct 20 14:14:45 2018
          State : clean
 Active Devices : 3
Working Devices : 4
 Failed Devices : 0
  Spare Devices : 1

         Layout : left-symmetric
     Chunk Size : 512K

           Name : datos.cda.net:md_RAID5  (local to host datos.cda.net)
           UUID : 5f6d514c:209e86ab:54764a4a:b2f9824a
         Events : 19

    Number   Major   Minor   RaidDevice State
       0       8       33        0      active sync   /dev/sdc1
       1       8       49        1      active sync   /dev/sdd1
       3       8       65        2      active sync   /dev/sde1

       4       8       81        -      spare   /dev/sdf1
```

Para ello necesitaremos aumentar el número de dispositivos de nuestro RAID de la siguiente forma:

```sh
mdadm --grow --raid-devices=4 /dev/md/md_RAID5
```

Si comprobamos nuestro RAID5 con el comando `mdadm --detail /dev/md/md_RAID5`, veremos que ya está disponible dentro del array.

```sh
/dev/md/md_RAID5:
        Version : 1.2
  Creation Time : Sat Oct 20 12:49:13 2018
     Raid Level : raid5
     Array Size : 301056 (294.00 MiB 308.28 MB)
  Used Dev Size : 100352 (98.00 MiB 102.76 MB)
   Raid Devices : 4
  Total Devices : 4
    Persistence : Superblock is persistent

    Update Time : Sat Oct 20 15:50:00 2018
          State : clean
 Active Devices : 4
Working Devices : 4
 Failed Devices : 0
  Spare Devices : 0

         Layout : left-symmetric
     Chunk Size : 512K

           Name : datos.cda.net:md_RAID5  (local to host datos.cda.net)
           UUID : 5f6d514c:209e86ab:54764a4a:b2f9824a
         Events : 39

    Number   Major   Minor   RaidDevice State
       0       8       33        0      active sync   /dev/sdc1
       1       8       49        1      active sync   /dev/sdd1
       3       8       65        2      active sync   /dev/sde1
       4       8       81        3      active sync   /dev/sdf1
```


<a name="raid5-storage"></a>
### Extensión de almacenamiento
---
Aunque nuestro RAID cuenta con un nuevo dispositivo, debemos redimensionar el espacio disponible.

Para ello utilizaremos el siguiente comando:

```sh
resize2fs /dev/md/md_RAID5
```

En mi caso me saltó un error dado que el RAID debía ser comprobado
antes de poder redimensionar su espacio:

```sh
resize2fs 1.43.4 (31-Jan-2017)
Por favor ejecute antes 'e2fsck -f /dev/md/md_RAID5'.
```

Como bien indica, comprobamos el RAID con `e2fsck` antes de redimensionarlo:

```sh
e2fsck -f /dev/md/md_RAID5
resize2fs /dev/md/md_RAID5
```

Y si todo sale bien, veremos la siguiente salida:

```sh
Paso 1: Verificando nodos-i, bloques y tamaños
Paso 2: Verificando la estructura de directorios
Paso 3: Revisando la conectividad de directorios
Paso 4: Revisando las cuentas de referencia
Paso 5: Revisando el resumen de información de grupos
/dev/md/md_RAID5: 12/50200 ficheros (0.0% no contiguos),
12001/200704 bloques

resize2fs 1.43.4 (31-Jan-2017)
Cambiando el tamaño del sistema de ficheros en /dev/md/md_RAID5
a 301056 (1k) bloques.
El sistema de ficheros en /dev/md/md_RAID5 tiene ahora 301056
bloques (de 1k).
```

Comprobamos que no haya ocurrido nada raro durante el proceso usando `mdadm --detail /dev/md/md_RAID5`:

```sh
/dev/md/md_RAID5:
        Version : 1.2
  Creation Time : Sat Oct 20 12:49:13 2018
     Raid Level : raid5
     Array Size : 301056 (294.00 MiB 308.28 MB)
  Used Dev Size : 100352 (98.00 MiB 102.76 MB)
   Raid Devices : 4
  Total Devices : 4
    Persistence : Superblock is persistent

    Update Time : Sat Oct 20 16:35:09 2018
          State : clean
 Active Devices : 4
Working Devices : 4
 Failed Devices : 0
  Spare Devices : 0

         Layout : left-symmetric
     Chunk Size : 512K

           Name : datos.cda.net:md_RAID5  (local to host datos.cda.net)
           UUID : 5f6d514c:209e86ab:54764a4a:b2f9824a
         Events : 41

    Number   Major   Minor   RaidDevice State
       0       8       33        0      active sync   /dev/sdc1
       1       8       49        1      active sync   /dev/sdd1
       3       8       65        2      active sync   /dev/sde1
       4       8       81        3      active sync   /dev/sdf1
```

Como no ha ocurrido nada raro, procederemos a montarlo y a comprobar el nuevo espacio disponible.

```sh
mount -t ext3 /dev/md/md_RAID5 /mnt/raid
df -Th /mnt/raid
```

Podemos comprobar que ahora hay más almacenamiento disponible, casi 100M, que es el espacio que nos concede el nuevo dispositivo:

```sh
S.ficheros     Tipo Tamaño Usados  Disp Uso% Montado en
/dev/md127     ext3   281M   2,1M  265M   1% /mnt/raid
```

También podemos comprobar que sigue estando nuestro archivo de prueba llamado `allzeros` a pesar de todas la modificaciones realizadas:

```sh
-rw-r--r-- 1 root root 1000000 oct 20 13:56 /mnt/raid/allzeros
```

¡Todo perfecto!


<a name="cuestiones"></a>
## Cuestiones
---
| # | Pregunta | Respuesta |
| --- | --- | --- |
| 1 | ¿Por qué en este caso es conveniente que las dos particiones de /dev/sde esten asignadas a ”subarrays” RAID1 distintos? | Porque si falla el dispositivo `sde`, quedará el 'mirror' en los dispositivos `sdc` y `sdd` . Si no fuera así, uno de los RAID 1 dejaría de funcionar y fallaría el sistema de almacenamiento |
| 2 | ¿Por qué en este caso sí es conveniente que las dos particiones de /dev/sde estén asignadas al mismo ”subarray” RAID0? | En este caso, si falla el dispositivo `sde`, quedará el mirror en los dispositivos `sdc` y `sdd`, por lo que el siistema de almacenamiento seguiría funcionando de forma correcta |


<a name="biblio"></a>
## Bibliografía
---
- [x] https://github.com/Student-Puma/HomeLab
- [x] http://ccia.esei.uvigo.es/docencia/CDA/1819/practicas/ejercicio-lvm-raid/ejercicio-lvm-raid.html
- [x] https://zackreed.me/adding-an-extra-disk-to-an-mdadm-array/
- [x] https://unix.stackexchange.com/questions/102613/create-a-test-file-with-lots-of-zero-bytes
