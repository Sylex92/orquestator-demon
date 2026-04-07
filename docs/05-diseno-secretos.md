# 5. Diseño de secretos

## Principio base

Hay que separar dos conceptos:

- identidad del servicio,
- secreto de aplicación.

### Identidad del servicio

Es la cuenta con la que corre:

- el App Pool de IIS,
- o el Windows Service.

Ejemplo futuro:

- gMSA,
- cuenta de dominio,
- servicio administrado.

### Secreto de aplicación

Es un valor sensible que la aplicación necesita leer:

- password de SQL Quartz,
- password de base PoC,
- credenciales futuras hacia sistemas externos.

## Decisión para esta fase

Se usa Windows Credential Manager como solución temporal por nodo.

Esto implica:

- cada servidor guarda localmente los secretos,
- `appsettings` solo almacena nombres lógicos,
- la app resuelve el secreto real en runtime.

## Abstracción implementada

Interfaz:

- [`ISecretProvider`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Core/Secrets/ISecretProvider.cs)

Implementación temporal:

- [`CredentialManagerSecretProvider`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Secrets/CredentialManagerSecretProvider.cs)

## Patrón de uso

### En configuración

```json
{
  "Secrets": {
    "LogicalToCredentialTarget": {
      "QuartzRuntimeDbPassword": "orquestator/quartz/sql/runtime/password"
    }
  },
  "Quartz": {
    "ConnectionStringTemplate": "Server=SQL-QUARTZ-CLUSTER;Database=DaemonQuartz;User ID=svc_daemon_quartz_runtime;Password={secret:QuartzRuntimeDbPassword};Encrypt=True;TrustServerCertificate=False;"
  }
}
```

### En ejecución

1. La app lee `ConnectionStringTemplate`.
2. Detecta el token `{secret:QuartzRuntimeDbPassword}`.
3. Llama a `ISecretProvider`.
4. `CredentialManagerSecretProvider` lee el target configurado.
5. La conexión final se construye en memoria.

En la PoC actual, el mismo login SQL y el mismo secreto real pueden reutilizarse tanto para la persistencia de Quartz como para la tabla opcional de historial PoC.

## Qué no se hace

- no se guardan passwords reales en `appsettings.json`,
- no se hardcodean credenciales en código,
- no se implementa Key Vault aún,
- no se resuelve identidad gMSA en esta PoC.

## Alta de secretos en Credential Manager

Cada nodo debe registrar los mismos secretos lógicos con sus targets correspondientes. Se incluye script helper:

- [set-credential-manager-secret.ps1](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/deploy/scripts/set-credential-manager-secret.ps1)

Ejemplo:

```powershell
.\deploy\scripts\set-credential-manager-secret.ps1 `
  -TargetName "orquestator/quartz/sql/runtime/password" `
  -UserName "svc_daemon_quartz_runtime" `
  -Secret "Cambiar-este-valor"
```

## Preparado para futuro Key Vault

La migración futura queda simple:

1. crear `KeyVaultSecretProvider`,
2. registrar esa implementación en DI,
3. conservar los mismos nombres lógicos,
4. retirar Credential Manager.

No sería necesario reescribir:

- jobs,
- API,
- Web,
- ni configuración funcional del clúster.
