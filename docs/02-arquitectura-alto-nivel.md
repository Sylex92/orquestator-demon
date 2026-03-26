# 2. Arquitectura de alto nivel

## Problema

Hoy no existe una plataforma moderna, centralizada y trazable para ejecutar demonios/workers con failover y control operativo entre dos nodos equivalentes en Windows Server 2019.

## Objetivos

- Ejecutar Quartz.NET en clúster activo-activo entre dos nodos.
- Persistir Quartz en SQL Server compartido.
- Administrar jobs desde un front y una API.
- Separar completamente Quartz de las bases operativas del negocio.
- Resolver secretos temporalmente con Credential Manager sin hardcodeo.

## Alcance

- front administrativo,
- API administrativa/control,
- worker host,
- persistencia Quartz,
- jobs demo,
- historial PoC opcional,
- despliegue base en IIS + Windows Service.

## Restricciones

- Windows Server 2019.
- `.NET 10`.
- secretos temporales en Windows Credential Manager.
- sin Key Vault en esta fase.
- sin tocar bases operativas reales del negocio.
- Quartz con SQL Server y clúster habilitado.

## Diagrama de alto nivel

```mermaid
flowchart LR
    User["Operador / Administrador"] --> Web["DaemonAdmin.Web<br/>ASP.NET Core MVC"]
    Web --> Api["DaemonAdmin.Api<br/>API administrativa"]

    subgraph Cluster["Clúster Quartz activo-activo"]
        Worker1["Nodo 1<br/>DaemonHost.Worker<br/>Windows Service"]
        Worker2["Nodo 2<br/>DaemonHost.Worker<br/>Windows Service"]
    end

    Api --> QuartzSql["SQL Server compartido<br/>[quartz].QRTZ_*"]
    Worker1 --> QuartzSql
    Worker2 --> QuartzSql

    Worker1 --> PocSql["SQL PoC opcional<br/>[poc].JobExecutionLog"]
    Worker2 --> PocSql
    Api --> PocSql

    Worker1 -. futuro .-> BizDb["Bases operativas existentes<br/>fuera de esta PoC"]
    Worker2 -. futuro .-> BizDb

    Cred1["Credential Manager Nodo 1"] --> Worker1
    Cred2["Credential Manager Nodo 2"] --> Worker2
    CredApi["Credential Manager nodo API"] --> Api
```

## Explicación por componente

### Front

`DaemonAdmin.Web` presenta una consola administrativa sencilla para:

- ver el estado general,
- revisar jobs,
- disparar `run-now`,
- pausar,
- reanudar,
- consultar historial.

### API

`DaemonAdmin.Api` expone endpoints administrativos. Su responsabilidad es:

- consultar jobs y triggers,
- consultar estado de clúster,
- pedir acciones administrativas,
- exponer health/status.

### Worker Host

`DaemonHost.Worker` aloja Quartz como Windows Service y ejecuta jobs reales. En esta PoC:

- registra `JobDemoRapido`,
- registra `JobDemoLento`,
- se une al clúster Quartz,
- y deja evidencia del nodo ejecutor.

### SQL compartido de Quartz

Es el corazón del clúster. Allí Quartz persiste:

- jobs,
- triggers,
- locks,
- fired triggers,
- scheduler state,
- calendarios y metadata interna.

Sin este SQL compartido no existe clustering real de Quartz.

## Flujo de administración y ejecución

```mermaid
sequenceDiagram
    participant O as Operador
    participant W as Front Web
    participant A as API Admin
    participant Q as SQL Quartz
    participant N1 as Worker Nodo 1
    participant N2 as Worker Nodo 2

    O->>W: Solicita ver jobs
    W->>A: GET /api/jobs
    A->>Q: Lee jobs, triggers y estado
    A-->>W: Respuesta consolidada

    O->>W: Run now
    W->>A: POST /api/jobs/{job}/run-now
    A->>Q: Inserta señal de disparo Quartz
    Q-->>N1: Nodo disponible adquiere trigger
    N1->>Q: Ejecuta y actualiza estado
```

## Por qué Quartz necesita persistencia propia

Quartz no es solo un cron embebido. Para clustering y durabilidad necesita persistir:

- scheduler state por nodo,
- locks distribuidos,
- triggers disparados,
- definiciones de job/trigger,
- reintentos, recovery y misfires.

Por eso:

- no debe usar tablas de negocio,
- no debe mezclarse con esquemas operativos ajenos,
- y ambos nodos deben apuntar exactamente al mismo almacenamiento Quartz.
