# 8. Documento operativo

## Cómo agregar un nuevo job

1. Crear la clase en `src/DaemonPlatform.Quartz/Jobs/`.
2. Heredar de `ObservedJobBase<TJob>` para conservar trazabilidad base.
3. Registrar el job en DI dentro de [`ServiceCollectionExtensions.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/ServiceCollectionExtensions.cs).
4. Agregar o actualizar su bootstrap en [`DemoJobCatalogBootstrapper.cs`](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/src/DaemonPlatform.Quartz/DemoJobCatalogBootstrapper.cs).
5. Publicar de nuevo ambos nodos.

## Cómo cambiar un cron

Opciones:

- editar `appsettings.json`,
- o editar `appsettings.Node1.json` / `appsettings.Node2.json` si se quiere diferenciar por nodo solo para PoC.

En esta PoC los cron demo viven en:

- `DemoJobs:FastCron`
- `DemoJobs:SlowCron`

Después se reinicia el Worker para que el bootstrap reschedule el trigger.

## Cómo pausar o reanudar

Desde UI:

- abrir dashboard,
- usar `Pausar` o `Reanudar`.

Desde API:

- `POST /api/jobs/{group}/{name}/pause`
- `POST /api/jobs/{group}/{name}/resume`

## Cómo ejecutar manualmente

Desde UI:

- botón `Run now`.

Desde API:

- `POST /api/jobs/{group}/{name}/run-now`

## Cómo revisar logs

### API

- `logs/api/.../daemon-admin-api.jsonl`

### Worker

- `logs/worker/.../daemon-worker.jsonl`

Cada corrida registra:

- `RunId`
- `NodeName`
- `JobGroup`
- `JobName`
- `FireInstanceId`

## Cómo verificar qué nodo ejecutó un job

Opciones:

- desde el dashboard, columna `Último nodo`,
- desde el detalle del job, historial básico,
- desde logs JSON por `NodeName`,
- desde la tabla PoC opcional `[poc].[JobExecutionLog]`.

## Cómo detectar si un nodo cayó

Indicadores:

- deja de aparecer como activo en el dashboard,
- no actualiza `QRTZ_SCHEDULER_STATE`,
- no hay nuevos check-ins,
- el Windows Service aparece detenido,
- logs del nodo dejan de avanzar.

## Cómo validar que el otro nodo sigue operativo

1. Confirmar que aún existe al menos un nodo `ConsideredAlive = true`.
2. Lanzar `Run now` en `JobDemoRapido`.
3. Confirmar que el historial registra ejecución en el nodo sobreviviente.
4. Para failover, detener a propósito el nodo que ejecuta `JobDemoLento` y observar recovery.

## Health/status general del sistema

Endpoints:

- `/health/live`
- `/health/ready`
- `/api/system/status`

## Notas operativas importantes

- No mezclar un scheduler no clusterizado con las mismas `QRTZ_*`.
- No cambiar `SchedulerName` por nodo.
- Mantener sincronización horaria.
- Si se rota un secreto en Credential Manager, reiniciar proceso correspondiente para evitar inconsistencias.
