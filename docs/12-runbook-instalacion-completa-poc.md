# 12. Runbook Completo de Instalacion y Configuracion de la PoC

## Objetivo

Este documento concentra el orden completo de instalacion y configuracion de la PoC:

- SQL Server externo para Quartz;
- Nodo 1;
- Nodo 2;
- Web administrativo;
- API administrativa;
- Worker con Quartz clusterizado.

## Idea clave

La PoC tiene dos capas distintas:

### Capa 1. Infraestructura compartida

- SQL Server externo;
- base `DaemonQuartz`;
- schema `[quartz]`;
- tablas `QRTZ_*`;
- secretos en Credential Manager por nodo.

### Capa 2. Procesos de aplicacion

- `DaemonAdmin.Web` en IIS;
- `DaemonAdmin.Api` en IIS;
- `DaemonHost.Worker` como Windows Service;
- Quartz clusterizado entre Nodo 1 y Nodo 2.

## Regla mental simple

- SQL compartido = donde Quartz coordina el cluster.
- Worker Nodo 1 + Worker Nodo 2 = donde Quartz ejecuta los jobs.
- Web/API = administracion y visibilidad.

## Alcance recomendado para la PoC

### Minimo funcional

- SQL externo listo;
- Worker en Nodo 1;
- Worker en Nodo 2;
- API y Web al menos en un nodo.

### Recomendado para quedar alineado al objetivo

- SQL externo listo;
- Worker en Nodo 1 y Nodo 2;
- API en Nodo 1 y Nodo 2;
- Web en Nodo 1 y Nodo 2;
- acceso por DNS o balanceador si existe.

Importante:

- el cluster Quartz aplica a los Workers;
- Web y API no forman cluster Quartz por si mismos;
- Web y API se pueden duplicar por disponibilidad, pero eso es hospedaje IIS, no clustering Quartz.

## Prerrequisitos por componente

### SQL externo

- SQL Server accesible desde ambos nodos.
- Base `DaemonQuartz`.
- Schema `[quartz]`.
- Tablas `QRTZ_*`.
- Opcional schema `[poc]` y tabla `[poc].[JobExecutionLog]`.
- Usuario tecnico runtime para Quartz.
- Usuario tecnico opcional para historial PoC.

### Nodo 1 y Nodo 2

- Windows Server 2019.
- .NET 10 runtime.
- ASP.NET Core Hosting Bundle .NET 10 para IIS si vas a hospedar Web/API.
- IIS instalado si vas a hospedar Web/API.
- Permiso para registrar Windows Service.
- Conectividad al SQL externo.
- Credential Manager disponible.
- Hora sincronizada.

## Documentos relacionados

- [10-configuracion-bd-quartz-servidor-externo.md](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/docs/10-configuracion-bd-quartz-servidor-externo.md)
- [11-guia-cluster-quartz-nodo1-nodo2.md](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/docs/11-guia-cluster-quartz-nodo1-nodo2.md)
- [07-despliegue.md](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/docs/07-despliegue.md)

## Fase 1. Preparar SQL Server externo

### Paso 1. Crear base, schemas, roles y permisos

Ejecutar:

- [001-preparar-base-quartz-template.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/001-preparar-base-quartz-template.sql)

### Paso 2. Ejecutar script oficial de Quartz para SQL Server

Tomar el script oficial desde:

- [quartznet/quartznet/database/tables](https://github.com/quartznet/quartznet/tree/main/database/tables)

Y adaptarlo para:

- base `DaemonQuartz`;
- schema `[quartz]`;
- prefijo `QRTZ_`.

### Paso 3. Ejecutar historial PoC opcional

Si quieres historial en UI/API:

- [optional-poc-history.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/optional-poc-history.sql)

### Paso 4. Validar instalacion SQL

Ejecutar:

- [002-validar-instalacion-quartz.sql](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/sql/002-validar-instalacion-quartz.sql)

## Fase 2. Preparar artefactos de despliegue

### Publicar Web y API

Script:

- [publish-iis-assets.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/publish-iis-assets.ps1)

Ejemplo:

```powershell
.\deploy\scripts\publish-iis-assets.ps1 `
  -Configuration Release `
  -OutputRoot .\deploy\published `
  -ApiNodeConfigFile .\src\DaemonAdmin.Api\appsettings.Node1.json `
  -WebNodeConfigFile .\src\DaemonAdmin.Web\appsettings.json
```

### Publicar Worker

Script:

- [publish-worker-assets.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/publish-worker-assets.ps1)

Ejemplo Nodo 1:

```powershell
.\deploy\scripts\publish-worker-assets.ps1 `
  -Configuration Release `
  -OutputRoot .\deploy\published `
  -WorkerNodeConfigFile .\src\DaemonHost.Worker\appsettings.Node1.json
```

Ejemplo Nodo 2:

```powershell
.\deploy\scripts\publish-worker-assets.ps1 `
  -Configuration Release `
  -OutputRoot .\deploy\published `
  -WorkerNodeConfigFile .\src\DaemonHost.Worker\appsettings.Node2.json
```

## Fase 3. Preparar secretos por nodo

Script:

- [set-credential-manager-secret.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/set-credential-manager-secret.ps1)

Secretos minimos:

- `orquestator/quartz/sql/quartz_app/password`
- `orquestator/quartz/sql/quartz_poc/password`

Ejemplo:

```powershell
.\deploy\scripts\set-credential-manager-secret.ps1 `
  -TargetName "orquestator/quartz/sql/quartz_app/password" `
  -UserName "quartz_app" `
  -Secret "<PASSWORD_REAL>"
```

```powershell
.\deploy\scripts\set-credential-manager-secret.ps1 `
  -TargetName "orquestator/quartz/sql/quartz_poc/password" `
  -UserName "quartz_poc" `
  -Secret "<PASSWORD_REAL>"
```

Importante:

- esto se hace en cada nodo donde corra el proceso;
- no guardar secretos reales en `appsettings`.

## Fase 4. Validar prerrequisitos de cada nodo

Script:

- [test-node-prereqs.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/test-node-prereqs.ps1)

Ejemplo para Nodo 1 con Web/API/Worker:

```powershell
.\deploy\scripts\test-node-prereqs.ps1 `
  -SqlServer "SQL-QUARTZ-CLUSTER" `
  -SqlPort 1433 `
  -CredentialTargets `
    "orquestator/quartz/sql/quartz_app/password", `
    "orquestator/quartz/sql/quartz_poc/password" `
  -CheckIis
```

## Fase 5. Instalar Web y API en IIS

### Lo que debes tener listo

- carpeta publicada de `DaemonAdmin.Web`;
- carpeta publicada de `DaemonAdmin.Api`;
- Hosting Bundle .NET 10 instalado;
- IIS habilitado.

### Lo que hace Infra/Windows Admin

1. Crear App Pool para API.
2. Crear App Pool para Web.
3. Configurar identidad segun politica corporativa.
4. Crear sitio o aplicaciones IIS.
5. Apuntar cada aplicacion a su carpeta publicada.
6. Confirmar que IIS puede leer la carpeta.

### Configuracion minima

- API publica en una URL conocida, por ejemplo `https://nodo1-api.dominio.local/`
- Web publica en una URL conocida y apunta a la API

Importante:

- el archivo [appsettings.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Web/appsettings.json) usa `AdminApi:BaseUrl`;
- si la API cambia de URL real, ajustar esa configuracion en el sitio publicado.

## Fase 6. Instalar Worker en Nodo 1 y Nodo 2

### Nodo 1

1. Copiar carpeta publicada del Worker al servidor.
2. Confirmar que contiene `DaemonHost.Worker.exe`.
3. Usar la configuracion de Nodo 1.
4. Registrar el Windows Service.

Script:

- [install-worker-service.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/install-worker-service.ps1)

Ejemplo:

```powershell
.\deploy\scripts\install-worker-service.ps1 `
  -PublishDir .\deploy\published\DaemonHost.Worker `
  -ServiceName "DaemonPlatform.Worker" `
  -NodeConfigFile .\src\DaemonHost.Worker\appsettings.Node1.json
```

### Nodo 2

Usar el mismo procedimiento, cambiando el archivo de nodo:

```powershell
.\deploy\scripts\install-worker-service.ps1 `
  -PublishDir .\deploy\published\DaemonHost.Worker `
  -ServiceName "DaemonPlatform.Worker" `
  -NodeConfigFile .\src\DaemonHost.Worker\appsettings.Node2.json
```

## Configuracion real del cluster

El cluster se forma por esta combinacion:

- mismo SQL Server;
- misma base `DaemonQuartz`;
- mismo `SchedulerName = DaemonPlatformCluster`;
- `quartz.jobStore.clustered = true`;
- `InstanceId` distinto por nodo.

Eso ya esta reflejado en:

- [appsettings.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.json)
- [appsettings.Node1.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node1.json)
- [appsettings.Node2.json](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node2.json)
- [ServiceCollectionExtensions.cs](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/ServiceCollectionExtensions.cs)

## Fase 7. Validacion funcional

### Validacion 1. El servicio levanta

Revisar:

- estado del Windows Service;
- logs del Worker;
- Event Viewer si falla.

### Validacion 2. Ambos nodos entran al cluster

Revisar:

- tabla `[quartz].[QRTZ_SCHEDULER_STATE]`

Debes ver dos instancias:

- `NODO1`
- `NODO2`

### Validacion 3. El front lista jobs

Verificar:

- dashboard carga;
- API responde;
- se ven `JobDemoRapido` y `JobDemoLento`.

### Validacion 4. Run now

1. Lanzar `Run now` en `JobDemoRapido`.
2. Confirmar en logs o UI que se ejecuto.
3. Confirmar el nodo ejecutor.

### Validacion 5. Failover

1. Dejar corriendo Nodo 1 y Nodo 2.
2. Detener el servicio del Nodo 1.
3. Esperar algunos segundos.
4. Confirmar que Nodo 2 sigue ejecutando.

## Checklist final de cierre

- SQL externo listo y validado.
- `[quartz].QRTZ_*` existe.
- `[poc].[JobExecutionLog]` existe si se habilito historial.
- Secretos cargados en Credential Manager.
- Web publicada.
- API publicada.
- Worker instalado en Nodo 1.
- Worker instalado en Nodo 2.
- Ambos nodos visibles en `QRTZ_SCHEDULER_STATE`.
- `Run now` exitoso.
- Failover validado.

## Riesgos operativos frecuentes

- script oficial Quartz ejecutado en `dbo` en lugar de `[quartz]`;
- mismo `InstanceId` en ambos nodos;
- `SchedulerName` distinto entre nodos;
- secretos faltantes en Credential Manager;
- falta de Hosting Bundle en IIS;
- reloj desincronizado;
- firewall bloqueando SQL.
