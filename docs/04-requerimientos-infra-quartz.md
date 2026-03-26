# 4. Requerimientos de infraestructura Quartz

## Justificación de base o schema exclusivo

Quartz necesita persistencia propia porque administra metadata transaccional del scheduler:

- locks,
- check-ins,
- triggers,
- fired triggers,
- misfires,
- recovery.

Por eso se solicita:

- una base dedicada `DaemonQuartz`, o
- al menos un schema dedicado `[quartz]` dentro de una base controlada para infraestructura.

No debe mezclarse con tablas de operación del negocio.

## Requerimiento obligatorio de SQL Server compartido

Infra debe proveer un SQL Server accesible desde `Nodo 1` y `Nodo 2`.

Condiciones mínimas:

- ambos nodos deben resolver DNS y conectividad TCP al mismo servidor/instancia;
- ambos deben usar la misma cadena de conexión lógica de Quartz;
- ambos deben leer/escribir exactamente las mismas tablas `QRTZ_*`.

## Tablas QRTZ_*

Quartz requiere sus tablas persistentes propias. Ejemplos:

- `QRTZ_JOB_DETAILS`
- `QRTZ_TRIGGERS`
- `QRTZ_CRON_TRIGGERS`
- `QRTZ_FIRED_TRIGGERS`
- `QRTZ_LOCKS`
- `QRTZ_SCHEDULER_STATE`

## Punto crítico

Quartz **no** debe compartir estas tablas entre:

- un scheduler clusterizado,
- y otro scheduler no clusterizado.

Tampoco deben mezclarse distintos `instanceName` sobre las mismas tablas si representan clústeres lógicos distintos.

## Creación de esquema

Infra/DBA debe crear manualmente las tablas Quartz. La aplicación **no** crea ni migra automáticamente el esquema `QRTZ_*`.

Esto aplica tanto para:

- base nueva dedicada,
- como schema dedicado existente.

## Ejemplo esperado

- Base: `DaemonQuartz`
- Schema Quartz: `[quartz]`
- Prefijo de tablas: `QRTZ_`
- Resultado esperado: `[quartz].QRTZ_JOB_DETAILS`, `[quartz].QRTZ_TRIGGERS`, etc.

## Configuración esperada de Quartz

- `jobStore.type = Quartz.Impl.AdoJobStore.JobStoreTX`
- `driverDelegateType = Quartz.Impl.AdoJobStore.SqlServerDelegate`
- `clustered = true`
- `instanceName = DaemonPlatformCluster`
- `instanceId = NODO1` y `NODO2` o `AUTO`
- `tablePrefix = [quartz].QRTZ_`

## Permisos mínimos requeridos

El login/usuario de Quartz debe tener permisos para:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

sobre todas las tablas `QRTZ_*` del schema Quartz.

Si se habilita historial PoC opcional, el usuario correspondiente debe tener esos mismos permisos sobre:

- `[poc].[JobExecutionLog]`

## Validaciones de conectividad

Infra debe validar:

- resolución DNS desde ambos nodos hacia SQL,
- conectividad TCP/puerto,
- cifrado TLS según política,
- apertura de firewall,
- latencia aceptable,
- autenticación del usuario técnico de Quartz.

## Sincronización horaria

Requerimiento obligatorio:

- `Nodo 1`,
- `Nodo 2`,
- y SQL Server

deben estar sincronizados por NTP/servicio horario corporativo.

Quartz clusterizado depende de timestamps para:

- misfires,
- check-ins,
- detección de nodos caídos,
- recovery.

## Checklist de validación de ambiente

- SQL compartido accesible desde ambos nodos.
- Tablas `QRTZ_*` creadas manualmente.
- Usuario Quartz con permisos correctos.
- Schema `[quartz]` visible desde ambos nodos.
- No existe otro scheduler no clusterizado usando las mismas tablas.
- Tiempo del sistema sincronizado.
- Credential Manager cargado en cada nodo.
- Puertos HTTP/HTTPS/IIS y Windows Service habilitados según diseño.
