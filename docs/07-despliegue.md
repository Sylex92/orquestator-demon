# 7. Documento de despliegue

## Prerrequisitos

- SDK/runtime .NET 10 en ambiente de build y runtime.
- IIS instalado para Web/API.
- Windows Service permitido para el Worker.
- SQL Quartz ya creado por Infra/DBA.
- Secretos cargados en Credential Manager.
- Conectividad desde nodos hacia SQL.

## Publicación para IIS

Script incluido:

- [publish-iis-assets.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/publish-iis-assets.ps1)

Publica:

- `DaemonAdmin.Api`
- `DaemonAdmin.Web`

Además puede copiar un archivo nodo-específico a `appsettings.Local.json`.

## Publicación del Worker como Windows Service

Script incluido:

- [install-worker-service.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/install-worker-service.ps1)

El script:

- valida el ejecutable publicado,
- copia `appsettings.NodeX.json` a `appsettings.Local.json`,
- registra el servicio Windows,
- deja configurado inicio automático,
- sugiere recuperación básica del servicio.

## Variables/configuración requeridas

### Configuración base

- `src/DaemonHost.Worker/appsettings.json`
- `src/DaemonAdmin.Api/appsettings.json`
- `src/DaemonAdmin.Web/appsettings.json`

### Configuración por nodo

- `appsettings.Node1.json`
- `appsettings.Node2.json`

### Convención de carga

La aplicación carga:

1. `appsettings.json`
2. `appsettings.Local.json` si existe
3. archivo indicado por `DAEMON_NODE_SETTINGS_FILE`, si se define

## Alta de secretos en Credential Manager

Script helper:

- [set-credential-manager-secret.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/set-credential-manager-secret.ps1)

Se deben cargar al menos:

- `orquestator/quartz/sql/runtime/password`

## Validación paso a paso

1. Confirmar que SQL Quartz responde desde ambos nodos.
2. Confirmar que las tablas `QRTZ_*` ya existen.
3. Confirmar que el historial PoC opcional existe si se habilitó.
4. Cargar secretos en Credential Manager.
5. Publicar API y Web en IIS.
6. Publicar Worker y registrar Windows Service.
7. Iniciar Worker en Nodo 1.
8. Iniciar Worker en Nodo 2.
9. Validar que ambos aparecen en `QRTZ_SCHEDULER_STATE`.
10. Abrir el front y verificar dashboard.
11. Ejecutar `Run now` sobre `JobDemoRapido`.
12. Confirmar en UI/logs qué nodo lo ejecutó.

## Troubleshooting inicial

### El Worker no arranca

- revisar Event Viewer,
- revisar `logs/worker/*.jsonl`,
- validar secreto en Credential Manager,
- validar que `appsettings.Local.json` corresponda al nodo correcto.

### La API no lista jobs

- validar acceso a SQL Quartz,
- validar que el schema/prefijo coincidan con `[quartz].QRTZ_`,
- validar que el `SchedulerName` sea el mismo en ambos nodos.

### El clúster no muestra ambos nodos

- validar `instanceId`,
- validar conectividad a SQL desde ambos nodos,
- validar hora del sistema,
- validar que el servicio realmente esté corriendo en ambos nodos.
