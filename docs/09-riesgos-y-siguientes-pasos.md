# 9. Riesgos y siguientes pasos

## Riesgos

### Riesgo: SDK local no validado

Esta máquina no tiene SDK .NET 10 instalado. El código queda preparado para `net10.0`, pero la compilación no pudo validarse aquí.

### Riesgo: Credential Manager es temporal

Es funcional para PoC, pero:

- no centraliza rotación,
- no da auditoría central,
- depende de carga manual o automatizada por nodo.

### Riesgo: historial PoC opcional

El historial básico del front usa una tabla PoC separada. No es parte del modelo operativo real y no debe confundirse con una solución final de auditoría enterprise.

### Riesgo: operación sin balanceador ni HA web formal

La PoC se enfoca en el clúster Quartz del Worker. La disponibilidad del front/API a nivel balanceador/reverse proxy queda fuera del alcance.

### Riesgo: failover depende del estado transaccional y del recovery del job

No todo job legacy será automáticamente seguro para recovery. Cuando entren jobs reales habrá que validar:

- idempotencia,
- reintentos,
- compensaciones,
- side effects.

## Siguientes pasos recomendados

1. Instalar SDK/runtime .NET 10 en pipeline y servidores de prueba.
2. Pedir a Infra/DBA la creación formal de `QRTZ_*`.
3. Aplicar script opcional de historial PoC solo en ambiente de prueba.
4. Ejecutar smoke test entre `Nodo 1` y `Nodo 2`.
5. Integrar el primer daemon real usando la misma base `ObservedJobBase<TJob>`.
6. Diseñar `KeyVaultSecretProvider`.
7. Diseñar telemetría enterprise con OpenTelemetry y destino corporativo.
8. Definir política de despliegue y rollback por nodo.
