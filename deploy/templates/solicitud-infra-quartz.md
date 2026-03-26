# Plantilla de solicitud a Infra / DBA para Quartz en SQL Server Externo

## Objetivo

Solicitar la infraestructura necesaria para operar Quartz.NET clusterizado en dos nodos Windows Server 2019 usando un SQL Server externo con conectividad desde ambos nodos.

## Requerimiento

Favor de provisionar una base o schema exclusivo para Quartz con acceso compartido desde:

- Nodo 1
- Nodo 2

La base sera configurada en un servidor SQL externo al par de nodos, pero con comunicacion valida desde ambos servidores Windows.

## Alcance solicitado a Infra / DBA

1. Crear base dedicada `DaemonQuartz` o schema dedicado `[quartz]` en el servidor SQL externo.
2. Ejecutar [001-preparar-base-quartz-template.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/001-preparar-base-quartz-template.sql) ajustando valores locales.
3. Ejecutar manualmente el script oficial de Quartz para SQL Server adaptado al schema `[quartz]`.
4. Confirmar que existan las tablas `QRTZ_*` en `[quartz]`.
5. Crear usuarios tecnicos necesarios para:
   - runtime Quartz
   - historial PoC opcional
6. Otorgar permisos `SELECT`, `INSERT`, `UPDATE`, `DELETE`.
7. Validar conectividad desde ambos nodos hacia el SQL externo.
8. Confirmar sincronizacion horaria entre nodos y SQL.
9. Ejecutar [002-validar-instalacion-quartz.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/002-validar-instalacion-quartz.sql) y compartir evidencia.

## Configuracion esperada

- Scheduler logical name: `DaemonPlatformCluster`
- JobStore: `Quartz.Impl.AdoJobStore.JobStoreTX`
- Driver delegate: `Quartz.Impl.AdoJobStore.SqlServerDelegate`
- Table prefix: `[quartz].QRTZ_`
- Clustering: `true`

## Restricciones importantes

- No mezclar scheduler clusterizado y no clusterizado sobre las mismas tablas.
- No usar bases operativas del negocio para almacenar tablas Quartz.
- La aplicacion no creara automaticamente el esquema `QRTZ_*`.
- El schema y prefijo esperados por la aplicacion son `[quartz].QRTZ_`.

## Opcional PoC

Si se desea historial basico en UI, aplicar ademas el script:

- [optional-poc-history.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/optional-poc-history.sql)

## Evidencia esperada de cierre

- nombre del servidor/instancia SQL;
- nombre final de la base;
- confirmacion de schema `[quartz]`;
- confirmacion de tablas `QRTZ_*`;
- confirmacion del usuario tecnico de runtime;
- confirmacion de conectividad desde Nodo 1 y Nodo 2;
- salida del script de validacion post-instalacion.
