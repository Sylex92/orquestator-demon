# 6. Estructura de solución

## Árbol principal

```text
orquestator-demon/
|-- src/
|   |-- DaemonAdmin.Web/
|   |-- DaemonAdmin.Api/
|   |-- DaemonHost.Worker/
|   |-- DaemonPlatform.Core/
|   |-- DaemonPlatform.Quartz/
|   |-- DaemonPlatform.Secrets/
|   |-- DaemonPlatform.Contracts/
|-- docs/
|-- deploy/
|   |-- scripts/
|   |-- templates/
|   |-- checklists/
|   |-- sql/
|-- Orquestator.DaemonPlatform.sln
```

## Proyectos y responsabilidades

### `src/DaemonAdmin.Web`

- Front MVC para operadores.
- Consume la API administrativa.
- Pantallas incluidas:
  - dashboard,
  - detalle de job,
  - acciones `run-now`, `pause`, `resume`.

Archivos relevantes:

- [`Program.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Web/Program.cs)
- [`Controllers/HomeController.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Web/Controllers/HomeController.cs)
- [`Services/AdminApiClient.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Web/Services/AdminApiClient.cs)

### `src/DaemonAdmin.Api`

- Endpoints administrativos de jobs y sistema.
- Health checks.
- Conexión administrativa al scheduler y SQL Quartz.

Archivos relevantes:

- [`Program.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Api/Program.cs)
- [`Controllers/JobsController.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Api/Controllers/JobsController.cs)
- [`Controllers/SystemController.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Api/Controllers/SystemController.cs)

### `src/DaemonHost.Worker`

- Host Quartz como Windows Service.
- Bootstrap de jobs demo.
- Participación en el clúster activo-activo.

Archivo relevante:

- [`Program.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/Program.cs)

### `src/DaemonPlatform.Contracts`

- Opciones de configuración.
- DTOs de administración.
- Contratos serializables compartidos entre API y Web.

### `src/DaemonPlatform.Core`

- `ISecretProvider`
- `ConnectionStringTemplateResolver`
- `NodeIdentityAccessor`
- logging JSON a archivo
- middleware de correlación

### `src/DaemonPlatform.Quartz`

- propiedades Quartz,
- `JobStoreTX`,
- repositorio de clúster,
- store de historial PoC,
- `ScopedJobFactory`,
- jobs demo,
- servicio administrativo,
- health check de SQL Quartz.

### `src/DaemonPlatform.Secrets`

- implementación `CredentialManagerSecretProvider`,
- bootstrap del proveedor temporal de secretos.

## Configuración por nodo

Archivos incluidos:

- [`src/DaemonHost.Worker/appsettings.Node1.json`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node1.json)
- [`src/DaemonHost.Worker/appsettings.Node2.json`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonHost.Worker/appsettings.Node2.json)
- [`src/DaemonAdmin.Api/appsettings.Node1.json`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Api/appsettings.Node1.json)
- [`src/DaemonAdmin.Api/appsettings.Node2.json`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Api/appsettings.Node2.json)
- [`src/DaemonAdmin.Web/appsettings.Node1.json`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Web/appsettings.Node1.json)
- [`src/DaemonAdmin.Web/appsettings.Node2.json`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonAdmin.Web/appsettings.Node2.json)

## Código base principal

Archivos clave de la PoC:

- [`src/DaemonPlatform.Quartz/ServiceCollectionExtensions.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/ServiceCollectionExtensions.cs)
- [`src/DaemonPlatform.Quartz/QuartzAdministrationService.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/QuartzAdministrationService.cs)
- [`src/DaemonPlatform.Quartz/Jobs/JobDemoRapido.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/Jobs/JobDemoRapido.cs)
- [`src/DaemonPlatform.Quartz/Jobs/JobDemoLento.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/Jobs/JobDemoLento.cs)
- [`src/DaemonPlatform.Secrets/CredentialManagerSecretProvider.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Secrets/CredentialManagerSecretProvider.cs)

## Separación explícita Quartz vs negocio

### Infraestructura Quartz

- tablas `QRTZ_*`,
- scheduler state,
- triggers,
- locks,
- fired triggers.

### Operación de negocio futura

- stored procedures,
- conexiones a bases legadas,
- usuarios ya definidos,
- reglas de negocio reales.

La PoC no crea tablas en bases operativas reales.
