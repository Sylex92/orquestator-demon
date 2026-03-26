# Smoke test post despliegue

## Paso 1

Abrir el front y validar que el dashboard responde.

## Paso 2

Consultar `GET /api/system/status` y confirmar:

- `SchedulerName = DaemonPlatformCluster`
- `ActiveNodes >= 1`

## Paso 3

Arrancar ambos Workers y confirmar que el dashboard muestra dos nodos activos.

## Paso 4

Ejecutar `Run now` sobre `JobDemoRapido`.

## Paso 5

Confirmar en UI o logs:

- `RunId` registrado
- nodo ejecutor visible
- estado `Succeeded`

## Paso 6

Esperar el próximo disparo automático de `JobDemoRapido` y validar ejecución.

## Paso 7

Lanzar `JobDemoLento`, detener el Worker del nodo que lo tomó y validar recovery en el otro nodo.

## Paso 8

Pausar y reanudar un job desde la UI.

## Paso 9

Consultar `/health/live` y `/health/ready`.
