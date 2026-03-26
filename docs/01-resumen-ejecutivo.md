# 1. Resumen ejecutivo

## Contexto

Se requiere una plataforma para ejecutar demonios/workers en dos nodos Windows Server 2019, con administración centralizada, persistencia compartida de Quartz.NET y separación estricta entre:

- infraestructura de scheduling,
- lógica operativa futura de negocio,
- y secretos de aplicación.

## Decisión propuesta

La PoC propone una solución compuesta por:

- un front administrativo en ASP.NET Core MVC,
- una API administrativa/control en ASP.NET Core,
- un Worker Host en .NET 10 ejecutado como Windows Service,
- Quartz.NET con `AdoJobStore` / `JobStoreTX`,
- SQL Server compartido exclusivo para Quartz,
- clustering activo-activo entre `Nodo 1` y `Nodo 2`,
- resolución temporal de secretos con Windows Credential Manager por nodo.

## Qué resuelve

- Un mismo scheduler lógico distribuido entre dos nodos.
- Persistencia durable de jobs, triggers, locks y estado de clúster en SQL Server compartido.
- Administración de jobs desde API/front: listar, consultar estado, ver próximos disparos, `run-now`, pausar, reanudar y revisar historial básico.
- Evidencia clara del nodo ejecutor por cada corrida demo.
- Una abstracción `ISecretProvider` lista para migrar luego a Key Vault o vault centralizado.

## Decisiones clave

1. Quartz usa su propio almacenamiento persistente y no comparte tablas con bases operativas del negocio.
2. Los workers son quienes ejecutan jobs; la API administra, inspecciona y ordena, pero no participa como nodo ejecutor.
3. Los secretos no se guardan en `appsettings`; solo se almacenan referencias lógicas.
4. La PoC incluye dos jobs demo y un historial PoC opcional fuera del modelo operativo real.
5. Las tablas `QRTZ_*` no se crean automáticamente: deben ser creadas por Infra/DBA.

## Qué es PoC y qué no

### Incluido en la PoC

- arquitectura base,
- solución multi-proyecto,
- jobs demo,
- front/API de control,
- scripts de despliegue,
- historial PoC opcional,
- documentación para Infra/DBA y operación.

### Fuera de alcance en esta fase

- migración de secretos a Key Vault,
- implementación detallada de identidad gMSA,
- tablas o lógica operativa del negocio,
- alta disponibilidad del front/IIS a nivel balanceador,
- observabilidad enterprise completa.
