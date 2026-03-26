# SQL de la PoC

## Importante

Las tablas `QRTZ_*` de Quartz **no** se incluyen en este repositorio porque deben ser creadas por Infra/DBA usando el script oficial de Quartz para SQL Server.

## Obligatorio

- crear manualmente `QRTZ_*`
- usar schema/prefijo acordado
- no permitir mezcla de schedulers incompatibles sobre las mismas tablas

## Incluido en este directorio

- `001-preparar-base-quartz-template.sql`: prepara base, schemas, roles, usuarios y permisos minimos.
- `002-validar-instalacion-quartz.sql`: valida que Quartz haya quedado correctamente instalado en el SQL externo.
- `optional-poc-history.sql`: script opcional para la tabla de historial PoC usada por la UI/API.

## Secuencia recomendada para Infra/DBA

1. Ejecutar `001-preparar-base-quartz-template.sql`.
2. Ejecutar el script oficial de Quartz SQL Server adaptado al schema `[quartz]`.
3. Ejecutar `optional-poc-history.sql` si se requiere historial PoC.
4. Ejecutar `002-validar-instalacion-quartz.sql`.

## Documento de apoyo

- [10-configuracion-bd-quartz-servidor-externo.md](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/docs/10-configuracion-bd-quartz-servidor-externo.md)
- [11-guia-cluster-quartz-nodo1-nodo2.md](/C:/Users/mario.sabaleta/Documents/GitHub/orquestator-demon/docs/11-guia-cluster-quartz-nodo1-nodo2.md)
