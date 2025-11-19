# Opciones de Escalado del Cluster EKS

## Configuración Actual

- **Tipo de instancia:** `t3.small`
- **Número de nodos:** 1 (desired), máximo 2
- **Región:** eu-central-1 (Frankfurt)
- **Problema actual:** Límite de pods/IPs alcanzado (máximo ~11 pods por t3.small)

## Opciones de Escalado

### Opción 1: Actualizar a t3.medium (Más recursos en mismo nodo)

**Especificaciones:**
- **vCPUs:** 2 (vs 2 en t3.small)
- **RAM:** 4 GB (vs 2 GB en t3.small)
- **Rendimiento de red:** Hasta 5 Gbps
- **Pods soportados:** ~17 pods (vs ~11 en t3.small)

**Costo estimado (eu-central-1):**
- **Por hora:** ~$0.0416 USD
- **Por día (24h):** ~$1.00 USD
- **Por mes:** ~$30 USD

**Ventajas:**
- ✅ Más memoria RAM (duplica la capacidad)
- ✅ Más pods por nodo
- ✅ Mismo número de nodos (1)
- ✅ Incremento de costo mínimo

**Desventajas:**
- ⚠️ Sigue siendo un solo nodo (sin alta disponibilidad)
- ⚠️ Limitado a ~17 pods

---

### Opción 2: Actualizar a t3.large (Más recursos significativos)

**Especificaciones:**
- **vCPUs:** 2
- **RAM:** 8 GB (4x más que t3.small)
- **Rendimiento de red:** Hasta 5 Gbps
- **Pods soportados:** ~29 pods

**Costo estimado (eu-central-1):**
- **Por hora:** ~$0.0832 USD
- **Por día (24h):** ~$2.00 USD
- **Por mes:** ~$60 USD

**Ventajas:**
- ✅ 4x más memoria RAM
- ✅ Muchos más pods soportados
- ✅ Buen balance costo/rendimiento
- ✅ Un solo nodo suficiente para más aplicaciones

**Desventajas:**
- ⚠️ Costo 2x mayor que t3.medium
- ⚠️ Sigue siendo un solo nodo

---

### Opción 3: Agregar un segundo nodo t3.small (Alta disponibilidad)

**Especificaciones:**
- **Nodos:** 2x t3.small
- **Total vCPUs:** 4
- **Total RAM:** 4 GB
- **Pods soportados:** ~22 pods totales

**Costo estimado (eu-central-1):**
- **Por hora:** ~$0.0416 USD × 2 = ~$0.0832 USD
- **Por día (24h):** ~$2.00 USD
- **Por mes:** ~$60 USD

**Ventajas:**
- ✅ Alta disponibilidad (si un nodo falla, el otro sigue)
- ✅ Distribución de carga entre nodos
- ✅ Más pods totales
- ✅ Mejor para producción

**Desventajas:**
- ⚠️ Costo 2x mayor que un solo nodo
- ⚠️ Más complejidad de gestión

---

### Opción 4: Agregar un segundo nodo t3.medium (Mejor balance)

**Especificaciones:**
- **Nodos:** 2x t3.medium
- **Total vCPUs:** 4
- **Total RAM:** 8 GB
- **Pods soportados:** ~34 pods totales

**Costo estimado (eu-central-1):**
- **Por hora:** ~$0.0416 USD × 2 = ~$0.0832 USD
- **Por día (24h):** ~$2.00 USD
- **Por mes:** ~$60 USD

**Ventajas:**
- ✅ Alta disponibilidad
- ✅ Mucha más capacidad (34 pods)
- ✅ Buen balance costo/rendimiento
- ✅ Suficiente para todas las aplicaciones actuales y futuras

**Desventajas:**
- ⚠️ Costo 2x mayor que un solo nodo t3.medium

---

### Opción 5: Actualizar a t3.xlarge (Máxima capacidad en un nodo)

**Especificaciones:**
- **vCPUs:** 4
- **RAM:** 16 GB (8x más que t3.small)
- **Rendimiento de red:** Hasta 5 Gbps
- **Pods soportados:** ~58 pods

**Costo estimado (eu-central-1):**
- **Por hora:** ~$0.1664 USD
- **Por día (24h):** ~$4.00 USD
- **Por mes:** ~$120 USD

**Ventajas:**
- ✅ Máxima capacidad en un solo nodo
- ✅ Mucha memoria RAM
- ✅ Muchos pods soportados

**Desventajas:**
- ⚠️ Costo 4x mayor que t3.small
- ⚠️ Sin alta disponibilidad (un solo nodo)
- ⚠️ Puede ser excesivo para un lab

---

## Comparación de Opciones

| Opción | Tipo | Nodos | RAM Total | Pods Max | Costo/Día | Costo/Mes | HA |
|--------|------|-------|-----------|----------|-----------|-----------|-----|
| **Actual** | t3.small | 1 | 2 GB | ~11 | $1.00 | $30 | ❌ |
| **Opción 1** | t3.medium | 1 | 4 GB | ~17 | $1.00 | $30 | ❌ |
| **Opción 2** | t3.large | 1 | 8 GB | ~29 | $2.00 | $60 | ❌ |
| **Opción 3** | t3.small | 2 | 4 GB | ~22 | $2.00 | $60 | ✅ |
| **Opción 4** | t3.medium | 2 | 8 GB | ~34 | $2.00 | $60 | ✅ |
| **Opción 5** | t3.xlarge | 1 | 16 GB | ~58 | $4.00 | $120 | ❌ |

## Recomendación

Para un entorno de laboratorio con las aplicaciones actuales (7 aplicaciones + pods del sistema):

**Recomendación principal: Opción 1 (t3.medium, 1 nodo)**
- ✅ Suficiente para las aplicaciones actuales
- ✅ Incremento mínimo de costo ($0/día adicional)
- ✅ Más memoria RAM disponible
- ✅ Más pods soportados

**Recomendación secundaria: Opción 4 (2x t3.medium)**
- ✅ Si necesitas alta disponibilidad
- ✅ Si planeas agregar más aplicaciones
- ✅ Buen balance costo/rendimiento
- ✅ Distribución de carga

## Cómo Implementar

### Para Opción 1 (Actualizar a t3.medium):

```bash
# Editar terraform/main.tf
# Cambiar línea 260:
instance_types = ["t3.medium"]

# Aplicar cambios
cd terraform
terraform plan
terraform apply
```

### Para Opción 4 (Agregar segundo nodo t3.medium):

```bash
# Editar terraform/main.tf
# Cambiar líneas 254-258:
scaling_config {
  desired_size = 2
  max_size     = 3
  min_size     = 2
}

instance_types = ["t3.medium"]

# Aplicar cambios
cd terraform
terraform plan
terraform apply
```

## Notas Adicionales

- Los precios son aproximados y pueden variar según la región y el momento
- Los costos de EKS ($0.10/hora por cluster) y EBS volumes se facturan por separado
- Considera usar Spot Instances para reducir costos en entornos de desarrollo (hasta 90% de descuento)
- Los límites de pods por nodo dependen de la configuración de CNI y recursos disponibles

## Costos Adicionales a Considerar

- **EKS Cluster:** $0.10/hora = $2.40/día = $72/mes
- **EBS Volumes:** ~$0.10/GB-mes (depende del tamaño)
- **NAT Gateway:** ~$0.045/hora = $1.08/día = $32.40/mes
- **Data Transfer:** Generalmente mínimo en labs

**Costo total estimado (Opción 1):**
- Instancia: $1.00/día
- EKS: $2.40/día
- NAT Gateway: $1.08/día
- **Total: ~$4.50/día = ~$135/mes**

