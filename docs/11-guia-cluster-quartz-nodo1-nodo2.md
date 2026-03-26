# 11. Guia Paso a Paso: Script Oficial de Quartz y Cluster entre Nodo 1 y Nodo 2

## Respuesta corta

No hay un "cluster de Windows" que debas instalar para Quartz.

En esta PoC, el cluster se logra asi:

- instalas el Worker en Nodo 1;
- instalas el Worker en Nodo 2;
- ambos Workers usan el mismo SQL Server de Quartz;
- ambos Workers usan el mismo `SchedulerName`;
- ambos Workers tienen `clustered = true`;
- cada Worker tiene `InstanceId` distinto o `AUTO`.

Eso es todo lo que Quartz necesita para trabajar como cluster activo-activo.

## Donde se configura el cluster

### 1. En SQL Server

SQL Server no "activa" el cluster.

SQL Server solo provee:

- la base compartida;
- las tablas `QRTZ_*`;
- los locks y estados que Quartz usa para coordinarse.

En otras palabras:

- SQL es el almacenamiento compartido;
- Quartz en cada nodo es quien forma el cluster.

### 2. En Quartz dentro del Worker

El cluster se activa en la configuracion del Worker.

En esta PoC ya esta preparado en:

- [ServiceCollectionExtensions.cs](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/ServiceCollectionExtensions.cs)
- [appsettings.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.json)
- [appsettings.Node1.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node1.json)
- [appsettings.Node2.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node2.json)

La configuracion base relevante es:

- `SchedulerName = DaemonPlatformCluster`
- `Schema = quartz`
- `TablePrefix = QRTZ_`
- `DriverDelegateType = Quartz.Impl.AdoJobStore.SqlServerDelegate`
- `JobStore = JobStoreTX`
- `clustered = true`

Y por nodo cambia esto:

- Nodo 1: `InstanceId = NODO1`
- Nodo 2: `InstanceId = NODO2`

## Como obtener el script oficial de Quartz para SQL Server

No te conviene que yo deje una copia local "congelada" del script oficial dentro de la PoC, porque luego se desalinearia de la version real de Quartz.

La forma correcta es:

1. Tomar el script oficial desde el repositorio o distribucion oficial de Quartz.
2. Adaptarlo al schema `[quartz]`.
3. Ejecutarlo en la base `DaemonQuartz`.

Fuentes oficiales:

- Documentacion oficial Quartz.NET Job Stores: [quartz-scheduler.net](https://www.quartz-scheduler.net/documentation/quartz-3.x/tutorial/job-stores.html)
- Referencia de configuracion Quartz.NET: [quartz-scheduler.net](https://www.quartz-scheduler.net/documentation/quartz-3.x/configuration/reference.html)
- Guia oficial de clustering: [quartz-scheduler.net](https://www.quartz-scheduler.net/documentation/quartz-3.x/tutorial/advanced-enterprise-features.html)
- Carpeta oficial de DDL en GitHub: [quartznet/quartznet/database/tables](https://github.com/quartznet/quartznet/tree/main/database/tables)

Adicionalmente, el paquete oficial que ya tienes restaurado en esta maquina tambien lo indica en:

- [quick-start.md](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/.dotnet-home/.nuget/packages/quartz/3.16.1/quick-start.md)

## Paso a paso para Infra/DBA

### Paso 1. Preparar la base

Infra debe ejecutar:

- [001-preparar-base-quartz-template.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/001-preparar-base-quartz-template.sql)

Ese script:

- crea base;
- crea schema `[quartz]`;
- crea roles;
- crea usuarios;
- da permisos.

### Paso 2. Obtener el script oficial correcto

Infra/DBA debe ir a:

- [database/tables](https://github.com/quartznet/quartznet/tree/main/database/tables)

Y seleccionar el script de SQL Server correspondiente.

### Paso 3. Adaptar el script al schema `[quartz]`

Si el script oficial viene para `dbo`, hay que ajustarlo.

La aplicacion espera:

- `[quartz].QRTZ_JOB_DETAILS`
- `[quartz].QRTZ_TRIGGERS`
- `[quartz].QRTZ_CRON_TRIGGERS`
- `[quartz].QRTZ_FIRED_TRIGGERS`
- `[quartz].QRTZ_SCHEDULER_STATE`
- `[quartz].QRTZ_LOCKS`

Punto importante:

- si el script crea `dbo.QRTZ_*`, no va a coincidir con la configuracion actual;
- la configuracion actual usa `[quartz].QRTZ_`.

### Paso 4. Ejecutar el script oficial adaptado

El script oficial debe ejecutarse en:

- base `DaemonQuartz`
- schema `[quartz]`

### Paso 5. Ejecutar historial PoC opcional

Si quieres ver historial en UI/API:

- ejecutar [optional-poc-history.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/optional-poc-history.sql)

### Paso 6. Validar instalacion

Infra debe ejecutar:

- [002-validar-instalacion-quartz.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/002-validar-instalacion-quartz.sql)

## Paso a paso para Nodo 1 y Nodo 2

### Paso 1. Mismo SQL compartido

Los dos nodos deben usar el mismo servidor SQL y la misma base Quartz.

Eso significa que ambos deben apuntar a algo como:

- `Server=SQL-QUARTZ-CLUSTER;Database=DaemonQuartz;...`

### Paso 2. Mismo scheduler logico

Los dos nodos deben usar el mismo `SchedulerName`.

En esta PoC:

- `DaemonPlatformCluster`

### Paso 3. InstanceId distinto por nodo

Cada nodo debe tener un `InstanceId` distinto.

En esta PoC:

- Nodo 1 usa [appsettings.Node1.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node1.json)
- Nodo 2 usa [appsettings.Node2.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node2.json)

Hoy quedaron asi:

- Nodo 1: `NODO1`
- Nodo 2: `NODO2`

Tambien podria usarse `AUTO`, pero para una PoC operativa es mas facil de leer cuando dejas un id fijo y reconocible por nodo.

### Paso 4. Mismo modo clusterizado

Ambos nodos deben tener:

- `quartz.jobStore.clustered = true`

Eso ya esta cableado en:

- [ServiceCollectionExtensions.cs](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/ServiceCollectionExtensions.cs)

### Paso 5. Instalar el Worker en ambos nodos

En Nodo 1:

- publicar el Worker;
- copiar configuracion de Nodo 1;
- registrar Windows Service;
- arrancarlo.

En Nodo 2:

- publicar el Worker;
- copiar configuracion de Nodo 2;
- registrar Windows Service;
- arrancarlo.

Script de apoyo:

- [install-worker-service.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/install-worker-service.ps1)

## Como piensa Quartz cuando ambos nodos estan vivos

1. Nodo 1 arranca su scheduler.
2. Nodo 2 arranca su scheduler.
3. Ambos se registran en `QRTZ_SCHEDULER_STATE`.
4. Ambos comparten triggers y locks usando las mismas tablas `QRTZ_*`.
5. Cuando toca ejecutar un job, Quartz asegura que un disparo lo tome solo un nodo.
6. Si un nodo cae, el otro puede continuar y recuperar ejecuciones segun configuracion del job.

## Como validar que el cluster funciona

### Validacion 1. Ambos nodos aparecen en Quartz

Revisar:

- `[quartz].[QRTZ_SCHEDULER_STATE]`

Debes ver dos filas, una por nodo.

### Validacion 2. Un job corre en un nodo

Lanza `Run now` desde el front/API.

Revisa:

- logs de Nodo 1;
- logs de Nodo 2;
- historial PoC si esta habilitado.

Debes ver que una ejecucion concreta la tomo un nodo.

### Validacion 3. Failover

1. Deja corriendo ambos nodos.
2. Deten Nodo 1.
3. Espera algunos segundos mas que el `clusterCheckinInterval`.
4. Verifica que Nodo 2 sigue ejecutando jobs.

## Errores que debes evitar

- usar bases operativas del negocio para Quartz;
- crear `QRTZ_*` en `dbo` si la configuracion apunta a `[quartz].QRTZ_`;
- poner `SchedulerName` distinto en Nodo 1 y Nodo 2;
- usar el mismo `InstanceId` en ambos nodos;
- iniciar una instancia no clusterizada contra las mismas tablas;
- no sincronizar hora entre nodos.

## Regla mental simple

Si quieres recordarlo facil:

- SQL compartido = donde Quartz se coordina.
- Nodo 1 y Nodo 2 = donde Quartz se ejecuta.
- Cluster = misma base + mismo scheduler name + clustered true + instanceId distinto.
