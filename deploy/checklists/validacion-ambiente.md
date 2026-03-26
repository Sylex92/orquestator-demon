# Checklist de validacion de ambiente

- SQL compartido accesible desde Nodo 1.
- SQL compartido accesible desde Nodo 2.
- Tablas `QRTZ_*` creadas por Infra/DBA.
- Schema `[quartz]` correcto y visible.
- Usuario Quartz con permisos correctos.
- Tabla PoC `[poc].[JobExecutionLog]` creada si se habilito historial.
- Credential Manager cargado con targets requeridos en cada nodo.
- Hora del sistema sincronizada entre nodos y SQL.
- Publicacion API/Web completada.
- Worker registrado como Windows Service.
- `appsettings.Local.json` corresponde al nodo correcto.
- `SchedulerName` igual en ambos nodos.
- `InstanceId` distinto entre nodos.
