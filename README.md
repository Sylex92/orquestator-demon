# orquestator-demon

PoC y documentación base para una plataforma de ejecución de demonios/workers en .NET 10 con Quartz.NET clusterizado en 2 nodos Windows Server 2019.

## Entregables principales

- [Resumen ejecutivo](./docs/01-resumen-ejecutivo.md)
- [Arquitectura de alto nivel](./docs/02-arquitectura-alto-nivel.md)
- [Arquitectura detallada](./docs/03-arquitectura-detallada.md)
- [Requerimientos de infraestructura Quartz](./docs/04-requerimientos-infra-quartz.md)
- [Diseño de secretos](./docs/05-diseno-secretos.md)
- [Estructura de solución](./docs/06-estructura-solucion.md)
- [Despliegue](./docs/07-despliegue.md)
- [Operación](./docs/08-operacion.md)
- [Riesgos y siguientes pasos](./docs/09-riesgos-y-siguientes-pasos.md)

## Estructura

- `src/DaemonAdmin.Web`: front administrativo ASP.NET Core MVC
- `src/DaemonAdmin.Api`: API administrativa/control
- `src/DaemonHost.Worker`: host Quartz ejecutado como Windows Service
- `src/DaemonPlatform.Contracts`: contratos y modelos compartidos
- `src/DaemonPlatform.Core`: utilitarios transversales, logging, correlación, resolución de cadenas
- `src/DaemonPlatform.Quartz`: configuración Quartz, jobs demo, administración y health
- `src/DaemonPlatform.Secrets`: `CredentialManagerSecretProvider`
- `deploy/`: scripts, plantillas y SQL PoC
- `docs/`: documentación técnica y operativa

## Nota importante del entorno local

El código queda apuntando a `net10.0`, pero esta máquina no tiene instalado el SDK .NET 10; por eso la compilación no pudo validarse aquí. Para compilar y publicar la PoC se requiere instalar el SDK/runtime .NET 10 en el ambiente de build y en los servidores correspondientes.
