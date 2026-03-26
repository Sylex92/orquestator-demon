# 10. Configuracion de Base de Datos Quartz en Servidor SQL Externo

## Objetivo

Definir exactamente que debe realizar Infra/DBA para dejar lista la persistencia de Quartz.NET en un SQL Server externo al par de nodos Windows, pero con conectividad desde:

- Nodo 1
- Nodo 2

Esta guia aplica a la PoC actual y respeta estas restricciones:

- Quartz usa persistencia propia separada de las bases operativas del negocio.
- Las tablas `QRTZ_*` deben vivir en una base o schema de infraestructura.
- La creacion del esquema Quartz es responsabilidad de Infra/DBA.
- La aplicacion no crea ni migra automaticamente las tablas `QRTZ_*`.

## Resultado esperado

Al finalizar, debe existir un SQL Server externo con:

- una base dedicada `DaemonQuartz` o equivalente;
- un schema `[quartz]` para Quartz;
- opcionalmente un schema `[poc]` para historial de la PoC;
- las tablas `QRTZ_*` instaladas en `[quartz]`;
- un usuario tecnico con permisos de lectura y escritura sobre `[quartz]`;
- conectividad validada desde Nodo 1 y Nodo 2;
- validacion de que ambos nodos podran usar el mismo almacenamiento compartido.

## Decision de diseno

Para esta PoC se recomienda:

- servidor SQL externo compartido;
- base dedicada `DaemonQuartz`;
- schema Quartz `[quartz]`;
- prefijo `QRTZ_`;
- nombre logico de scheduler `DaemonPlatformCluster`.

Motivo:

- aisla la infraestructura Quartz del modelo operativo real;
- simplifica operacion, respaldo y troubleshooting;
- evita mezclar metadata tecnica con datos del negocio.

## Entradas que Infra/DBA debe definir antes de ejecutar

- nombre del servidor o instancia SQL;
- puerto SQL;
- nombre final de la base;
- tipo de autenticacion del usuario tecnico;
- nombre del login para runtime Quartz;
- nombre del login opcional para historial PoC;
- politica de TLS/certificado;
- reglas de firewall desde Nodo 1 y Nodo 2.

## Orden de ejecucion recomendado

1. Validar conectividad de red desde ambos nodos al SQL externo.
2. Crear la base y los schemas.
3. Crear usuarios y permisos.
4. Ejecutar el script oficial de Quartz para SQL Server adaptado al schema `[quartz]`.
5. Ejecutar el script opcional de historial PoC si se desea visibilidad en UI/API.
6. Ejecutar el script de validacion post-instalacion.
7. Entregar a aplicacion los datos finales de conexion y nombres de login.

## Scripts incluidos en este repositorio

- [001-preparar-base-quartz-template.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/001-preparar-base-quartz-template.sql)
- [002-validar-instalacion-quartz.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/002-validar-instalacion-quartz.sql)
- [optional-poc-history.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/optional-poc-history.sql)

## Que hace cada script

### 1. Preparacion de base y seguridad

Script:

- [001-preparar-base-quartz-template.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/001-preparar-base-quartz-template.sql)

Este script:

- crea la base si no existe;
- crea schema `[quartz]`;
- crea schema `[poc]` si se habilita;
- crea roles de base para runtime y PoC;
- vincula usuarios existentes a esos roles;
- otorga permisos minimos sobre schemas.

Este script **no** crea las tablas `QRTZ_*`.

### 2. Instalacion del esquema oficial de Quartz

Infra/DBA debe ejecutar el script oficial de Quartz.NET para SQL Server correspondiente a la version aprobada del producto.

Puntos obligatorios:

- ejecutarlo en la base Quartz;
- adaptarlo para que las tablas queden en `[quartz]`;
- conservar el prefijo `QRTZ_`;
- no instalar las tablas en `dbo` si la aplicacion usara `[quartz].QRTZ_`.

Resultado esperado:

- `[quartz].[QRTZ_JOB_DETAILS]`
- `[quartz].[QRTZ_TRIGGERS]`
- `[quartz].[QRTZ_CRON_TRIGGERS]`
- `[quartz].[QRTZ_FIRED_TRIGGERS]`
- `[quartz].[QRTZ_SCHEDULER_STATE]`
- `[quartz].[QRTZ_LOCKS]`
- y el resto de tablas estandar de Quartz SQL Server.

### 3. Historial PoC opcional

Script:

- [optional-poc-history.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/optional-poc-history.sql)

Solo si quieres que el front/API muestren historial basico de ejecuciones.

Importante:

- esta tabla es PoC;
- no pertenece a ninguna base operativa del negocio.

### 4. Validacion post-instalacion

Script:

- [002-validar-instalacion-quartz.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/002-validar-instalacion-quartz.sql)

Este script valida:

- existencia de base;
- existencia de schemas;
- existencia de tablas Quartz obligatorias;
- existencia de usuarios;
- permisos minimos del usuario runtime;
- estado final esperado para entregar la base a la aplicacion.

## Configuracion que debe coincidir con la aplicacion

La configuracion de la aplicacion espera lo siguiente:

- schema Quartz: `quartz`
- prefijo de tablas: `QRTZ_`
- table prefix efectivo: `[quartz].QRTZ_`
- scheduler name: `DaemonPlatformCluster`
- clustering habilitado

Referencias:

- [appsettings.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.json)
- [appsettings.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Api/appsettings.json)

## Requisitos de red para SQL externo

Infra debe confirmar:

- resolucion DNS o alias estable del SQL externo;
- conectividad desde Nodo 1 y Nodo 2 al puerto SQL;
- reglas de firewall de salida desde nodos y entrada al SQL;
- politica de cifrado compatible con la cadena de conexion;
- latencia razonable para un scheduler persistente.

No se requiere comunicacion iniciada desde SQL hacia los nodos para esta PoC.

## Permisos minimos esperados

El usuario runtime Quartz debe tener:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

sobre el schema `[quartz]`.

Si se habilita historial PoC:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

sobre el schema `[poc]`.

## Que debe entregarte Infra al finalizar

- nombre final del servidor/instancia SQL;
- nombre final de la base;
- puerto;
- nombre del login runtime;
- confirmacion de schema `[quartz]`;
- confirmacion de tablas `QRTZ_*`;
- confirmacion de pruebas de conectividad desde Nodo 1 y Nodo 2;
- si aplica, confirmacion de tabla `[poc].[JobExecutionLog]`.

## Criterio de aceptacion

La base queda lista para la PoC cuando:

- ambos nodos ven el mismo SQL externo;
- existe `[quartz].QRTZ_*`;
- el usuario runtime puede leer y escribir en Quartz;
- no existe otro scheduler incompatible usando esas tablas;
- el script [002-validar-instalacion-quartz.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/002-validar-instalacion-quartz.sql) termina sin errores;
- la aplicacion puede apuntar a ese SQL con secretos cargados en Credential Manager.
