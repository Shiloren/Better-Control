# Better Control 2.0 - Sistema Completo de Insights & UI Revolucionaria

**Fecha:** 31 de Marzo 2026
**Versión Target:** Better Control 2.0
**Autor:** Claude Sonnet 4.5 con shilo

---

## 📋 Tabla de Contenidos

### PARTE I: SISTEMA DE INSIGHTS Y RECOMENDACIONES

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Objetivos del Sistema](#objetivos-del-sistema)
3. [Arquitectura General](#arquitectura-general)
4. [Estructura de Datos](#estructura-de-datos)
5. [Módulos y Componentes](#módulos-y-componentes)
6. [Flujos de Usuario](#flujos-de-usuario)
7. [Interfaz de Usuario](#interfaz-de-usuario)
8. [Plan de Implementación](#plan-de-implementación)
9. [Criterios de Aceptación](#criterios-de-aceptación)

### PARTE II: INTERFAZ REVOLUCIONARIA & CONTROLES AVANZADOS

10. [Sistema de Controles Revolucionario](#10-sistema-de-controles-revolucionario)
11. [Radial Menu System](#11-radial-menu-system)
12. [Gesture System con Sticks](#12-gesture-system-con-sticks)
13. [Batch Operations Avanzadas](#13-batch-operations-avanzadas)
14. [Haptic Feedback System](#14-haptic-feedback-system)
15. [Macro System para Power Users](#15-macro-system-para-power-users)
16. [Budget & Safe Mode](#16-budget--safe-mode)
17. [Adaptive UI System](#17-adaptive-ui-system)
18. [Plan de Implementación UI](#18-plan-de-implementación-ui)

### APÉNDICES

19. [Roadmap Futuro](#19-roadmap-futuro)
20. [Apéndices](#20-apéndices)

---

## 1. Resumen Ejecutivo

### 🎯 Qué Resuelve

El sistema de Insights y Recomendaciones transforma Better Control de un simple reemplazo de la UI de vendor a una **experiencia de compra inteligente** similar a Amazon, que:

- **Aprende de los patrones del usuario**: Detecta qué compra, cuándo y en qué cantidades
- **Predice necesidades**: "Sueles comprar 200 de esto, probablemente ya usaste 150"
- **Reconoce carritos recurrentes**: "Este carrito es tu 'Raid Prep' habitual"
- **One-click re-buy**: Botones para replicar compras anteriores completas
- **Smart suggestions**: Basado en contexto temporal (día, hora)

### 🎁 Beneficio para el Usuario

**Antes:**
1. Abrir vendor → navegar catálogo → recordar qué necesito → calcular cantidades → comprar
2. Repetir 10+ veces por semana
3. **Tiempo promedio: 2-3 minutos por sesión**

**Después:**
1. Abrir vendor → "¿Quieres tu carrito de Martes Raid Prep?" → Presionar A → Listo
2. **Tiempo promedio: 3-5 segundos** ⚡

**Ahorro de tiempo: ~95%** para compras recurrentes

---

## 2. Objetivos del Sistema

### Objetivos Principales

1. **Detección de Patrones de Cantidad**
   - Analizar cantidades típicas por item: "Siempre compras ~200 de Agility Potion"
   - Calcular desviación estándar y confianza
   - Pre-llenar cantidades automáticamente

2. **Reconocimiento de Carritos Recurrentes**
   - Detectar conjuntos de items que siempre se compran juntos
   - Generar "fingerprints" de carritos
   - Identificar similaridad entre carritos (Jaccard/Cosine)

3. **Predicción de Consumo**
   - Estimar tasa de consumo: "Compras 200 cada 5 días = 40/día"
   - Calcular cuánto probablemente queda: "Hace 5 días compraste 200, probablemente quedan ~0"
   - Alertar necesidad de restock

4. **Acciones Rápidas Contextuales**
   - Botón "Re-buy Last Order" → un click
   - Botón "Use Raid Prep Cart" → un click
   - Botón "Add to Favorites" → guardar configuración actual

5. **Adaptación Temporal**
   - Detectar patrones por día de la semana: "Los martes siempre compras esto"
   - Detectar patrones por hora: "A las 8pm sueles hacer raid prep"
   - Sugerir proactivamente basado en contexto

---

## 3. Arquitectura General

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────┐
│         Better Control Insight System v2.0                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  LAYER 1: Data Capture (Telemetry)                 │    │
│  │  - Purchase events                                  │    │
│  │  - Cart snapshots                                   │    │
│  │  - Temporal context (day/hour)                      │    │
│  └────────────────────────────────────────────────────┘    │
│                        ↓                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │  LAYER 2: Pattern Analysis                         │    │
│  │  - QuantityPatternAnalyzer                          │    │
│  │  - CartPatternRecognizer                            │    │
│  │  - ConsumptionEstimator                             │    │
│  └────────────────────────────────────────────────────┘    │
│                        ↓                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │  LAYER 3: Intelligence & Recommendations            │    │
│  │  - Smart quantity suggestions                       │    │
│  │  - Cart matching & similarity                       │    │
│  │  - Restock predictions                              │    │
│  └────────────────────────────────────────────────────┘    │
│                        ↓                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │  LAYER 4: UI & Actions                             │    │
│  │  - Smart Actions Panel                              │    │
│  │  - One-click buttons                                │    │
│  │  - Visual recommendations                           │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Flujo de Datos

```
User Action (Purchase)
    ↓
Telemetry Capture → SavedVariables
    ↓
Background Analysis (debounced 2s)
    ↓
Pattern Detection & Update
    ↓
UI Updates (real-time suggestions)
    ↓
Next Session: Predictions Available
```

---

## 4. Estructura de Datos

### 4.1 SavedVariables Schema

```lua
BetterControlDB = {
    version = "2.0.0",

    -- ============================================================
    -- PURCHASE HISTORY (Cart Snapshots Completos)
    -- ============================================================
    purchaseHistory = {
        -- Array de compras completas (máximo 1000 últimas)
        {
            purchaseId = "20261231-1530-abc123",  -- Unique ID
            timestamp = 1735660200,                -- Unix timestamp
            vendor = "Innkeeper",                  -- NPC name
            cart = {
                -- Items en este carrito
                {
                    itemId = 12345,
                    itemName = "Agility Potion",
                    quantity = 200,
                    unitCost = 12,
                    totalCost = 2400,
                    isConsumable = true,
                },
                {
                    itemId = 67890,
                    itemName = "Mana Potion",
                    quantity = 150,
                    unitCost = 10,
                    totalCost = 1500,
                    isConsumable = true,
                },
                -- ... más items
            },
            totalCost = 4400,      -- Costo total del carrito
            itemCount = 3,         -- Número de items distintos
            weekday = 2,           -- 0=Domingo, 6=Sábado
            hour = 15,             -- 0-23
            context = {
                preRaid = true,    -- Detectado automáticamente
                weeklyRestock = false,
                manualPurchase = false,
            }
        },
        -- ... más compras
    },

    -- ============================================================
    -- QUANTITY PATTERNS (Patrones de Cantidad Detectados)
    -- ============================================================
    quantityPatterns = {
        -- Indexado por itemId
        [12345] = {
            itemName = "Agility Potion",
            purchases = {200, 200, 180, 200, 220},  -- Últimas 5 cantidades
            typical = 200,          -- Cantidad típica (mediana)
            mean = 200,             -- Promedio
            stdDev = 15,            -- Desviación estándar
            confidence = 0.95,      -- Confianza del patrón (0-1)
            lastPurchase = 1735660200,
            avgDaysBetween = 5,     -- Días promedio entre compras
            totalPurchases = 8,     -- Total de veces comprado
        },
        -- ... más items
    },

    -- ============================================================
    -- DETECTED CARTS (Carritos Recurrentes Detectados)
    -- ============================================================
    detectedCarts = {
        {
            cartId = "auto-raid-prep-123456",
            name = "Martes Raid Prep",  -- Auto-generado
            fingerprint = "12345:200|67890:150|11111:100",  -- Signature única
            items = {
                {itemId = 12345, itemName = "Agility Potion", typicalQuantity = 200},
                {itemId = 67890, itemName = "Mana Potion", typicalQuantity = 150},
                {itemId = 11111, itemName = "Food", typicalQuantity = 100},
            },
            occurrences = 8,        -- Veces que se ha usado este patrón
            lastUsed = 1735660200,
            avgCost = 4400,         -- Costo promedio
            context = {
                weekdays = {[2] = 5, [4] = 3},  -- Martes: 5x, Jueves: 3x
                hours = {[15] = 4, [20] = 4},   -- 3pm: 4x, 8pm: 4x
            },
            userNamed = false,      -- ¿Usuario le puso nombre custom?
            customName = nil,       -- Si userNamed=true
            isFavorite = false,     -- ¿Marcado como favorito?
        },
        -- ... más carritos detectados
    },

    -- ============================================================
    -- FAVORITES (Favoritos Guardados por el Usuario)
    -- ============================================================
    favorites = {
        {
            favoriteId = "user-raid-night-001",
            name = "Mi Raid Night Personal",  -- Nombre dado por usuario
            icon = "Interface\\Icons\\Achievement_Boss_Nefarion",
            items = {
                {itemId = 12345, quantity = 200},
                {itemId = 67890, quantity = 150},
                -- ... más items
            },
            createdAt = 1735000000,
            lastUsed = 1735660200,
            useCount = 15,
            notes = "Para raids de ICC",  -- Opcional
        },
        -- ... más favoritos
    },

    -- ============================================================
    -- CONSUMPTION RATES (Tasas de Consumo Estimadas)
    -- ============================================================
    consumptionRates = {
        [12345] = {
            itemName = "Agility Potion",
            avgConsumptionPerDay = 40,      -- Potions consumidas/día
            lastStockLevel = 200,           -- Última cantidad comprada
            lastStockDate = 1735660200,
            daysSinceLastPurchase = 5,
            estimatedConsumed = 200,        -- Estimación: 40/día * 5 días
            estimatedRemaining = 0,         -- Max(0, 200 - 200)
            needsRestock = true,            -- Flag de alerta
            confidence = 0.85,              -- Confianza de la predicción
        },
        -- ... más items
    },

    -- ============================================================
    -- TELEMETRY METADATA
    -- ============================================================
    telemetry = {
        lastAnalysis = 1735660300,      -- Timestamp del último análisis
        totalPurchases = 150,
        totalGoldSpent = 650000,
        totalItemsBought = 25000,
        vendorOpenCount = 200,
        avgSessionDuration = 45,         -- Segundos
    },

    -- ============================================================
    -- CONFIGURATION
    -- ============================================================
    insightSettings = {
        enabled = true,
        autoSuggestQuantity = true,
        showCartSuggestions = true,
        showRestockWarnings = true,
        minOccurrencesForPattern = 3,   -- Mínimo 3 compras para detectar patrón
        maxHistoryItems = 1000,          -- Máximo de compras en historial
        analysisDebounce = 2,            -- Segundos de debounce para análisis
    },
}
```

---

## 5. Módulos y Componentes

### 5.1 Core/Telemetry.lua

**Responsabilidad:** Capturar eventos de compra y contexto temporal

**API Pública:**
```lua
-- Inicializar
Telemetry:Init()

-- Trackear compra completa
Telemetry:TrackPurchase(purchaseData)
-- purchaseData = {
--     vendor = "Innkeeper",
--     cart = {{itemId, itemName, quantity, unitCost, totalCost}...},
--     totalCost = 4400,
-- }

-- Obtener historial filtrado
Telemetry:GetPurchaseHistory(filters)
-- filters = {
--     vendor = "Innkeeper",  -- Opcional
--     minDate = timestamp,    -- Opcional
--     maxDate = timestamp,    -- Opcional
--     itemId = 12345,        -- Opcional
-- }

-- Rotar historial antiguo (mantener límite)
Telemetry:RotateHistory()
```

**Detalles de Implementación:**
- Capturar timestamp, día de semana (0-6), hora (0-23)
- Detectar contexto automático:
  - `preRaid` si cantidad total > 300 consumibles
  - `weeklyRestock` si es mismo día de semana que compras anteriores
- Límite de 1000 compras en historial
- Rotación automática: eliminar las más antiguas si excede límite

---

### 5.2 Core/QuantityPatternAnalyzer.lua

**Responsabilidad:** Analizar patrones de cantidad por item

**API Pública:**
```lua
-- Analizar todos los patterns (llamado después de compra)
QuantityAnalyzer:AnalyzeQuantityPatterns()

-- Obtener sugerencia de cantidad para un item
QuantityAnalyzer:GetSuggestedQuantity(itemId)
-- Retorna:
-- {
--     quantity = 200,
--     range = {min = 180, max = 220},
--     confidence = 0.95,
--     message = "Sueles comprar ~200 (±20)"
-- }
-- O nil si no hay patrón

-- Obtener pattern completo
QuantityAnalyzer:GetPattern(itemId)
```

**Algoritmo de Análisis:**

1. **Agrupar compras por itemId**
   ```lua
   -- Extraer todas las cantidades de purchaseHistory
   -- para cada itemId
   ```

2. **Calcular Mediana (no promedio)**
   ```lua
   -- La mediana es más robusta contra outliers
   -- que el promedio
   -- Ejemplo: {200, 200, 180, 200, 500}
   -- Mediana = 200 (correcto)
   -- Promedio = 256 (sesgado por outlier)
   ```

3. **Calcular Desviación Estándar**
   ```lua
   stdDev = sqrt(sum((x - mean)^2) / n)
   ```

4. **Calcular Confianza**
   ```lua
   -- Coefficient of Variation
   CV = stdDev / mean
   confidence = 1 - min(CV, 1)

   -- Si CV bajo → alta consistencia → alta confianza
   -- Si CV alto → baja consistencia → baja confianza
   ```

5. **Calcular Días Promedio Entre Compras**
   ```lua
   avgDaysBetween = avg(timestamp[i+1] - timestamp[i]) / (24*60*60)
   ```

**Criterios para Patrón Válido:**
- Mínimo 3 compras del item
- Confianza >= 0.6 (60%)

---

### 5.3 Core/CartPatternRecognizer.lua

**Responsabilidad:** Detectar y reconocer carritos recurrentes

**API Pública:**
```lua
-- Analizar historial y detectar carritos recurrentes
CartRecognizer:DetectRecurringCarts()

-- Generar fingerprint de un carrito
CartRecognizer:GenerateCartFingerprint(cart)
-- Retorna: "12345:200|67890:150|11111:100"

-- Comparar carrito actual con detectados
CartRecognizer:MatchCurrentCart(currentCart)
-- Retorna: [
--   {
--     cart = detectedCart,
--     similarity = 0.95,
--     message = "Este carrito es 95% similar a 'Martes Raid Prep'"
--   }
-- ]

-- Obtener carritos por contexto
CartRecognizer:GetCartsByContext(weekday, hour)
```

**Algoritmo de Fingerprinting:**

```lua
function GenerateCartFingerprint(cart)
    -- 1. Extraer items + cantidades
    local items = {}
    for _, item in ipairs(cart) do
        -- Agrupar cantidades en buckets de 10
        -- para tolerar pequeñas variaciones
        -- 195 → 190, 203 → 200
        local qtyBucket = math.floor(item.quantity / 10) * 10
        table.insert(items, {
            id = item.itemId,
            qty = qtyBucket
        })
    end

    -- 2. Ordenar por itemId (para consistencia)
    table.sort(items, function(a, b)
        return a.id < b.id
    end)

    -- 3. Generar string signature
    local parts = {}
    for _, item in ipairs(items) do
        table.insert(parts, string.format("%d:%d", item.id, item.qty))
    end

    return table.concat(parts, "|")
    -- Ejemplo: "12345:200|67890:150|11111:100"
end
```

**Algoritmo de Similaridad (Jaccard):**

```lua
function CalculateSimilarity(fingerprint1, fingerprint2)
    -- Jaccard Similarity = |A ∩ B| / |A ∪ B|

    -- Parsear fingerprints en sets
    local set1 = parseFingerprint(fingerprint1)
    local set2 = parseFingerprint(fingerprint2)

    -- Intersección
    local intersection = countCommonItems(set1, set2)

    -- Unión
    local union = countUniqueItems(set1, set2)

    return intersection / union
end
```

**Detección de Carritos Recurrentes:**
- Mínimo 3 ocurrencias del mismo fingerprint
- Generar nombre automático basado en contexto:
  - Si mayoría de compras en Martes → "Martes Restock"
  - Si mayoría tiene consumibles masivos → "Raid Prep"
  - Detectar día de semana más común
  - Detectar hora más común

**Generación de Nombres Automáticos:**
```lua
-- Si 80%+ de ocurrencias en un día específico
→ "{DayName} Raid Prep"

-- Si 80%+ son consumibles en cantidades >100
→ "Raid Night Supplies"

-- Si patrón genérico
→ "Weekly Restock"
```

---

### 5.4 Core/ConsumptionEstimator.lua

**Responsabilidad:** Estimar consumo y necesidad de restock

**API Pública:**
```lua
-- Estimar consumo para todos los items
ConsumptionEstimator:EstimateConsumption()

-- Obtener mensaje de restock para un item
ConsumptionEstimator:GetRestockMessage(itemId)
-- Retorna:
-- {
--     severity = "high"|"medium"|"low",
--     message = "⚠️ Probablemente te quedan ~0 (compraste 200 hace 5 días)",
--     suggestedQuantity = 200,
-- }
-- O nil si no necesita restock
```

**Algoritmo de Estimación:**

```lua
function EstimateConsumption(itemId)
    local pattern = quantityPatterns[itemId]

    -- 1. Calcular tasa de consumo promedio
    avgConsumptionPerDay = pattern.typical / pattern.avgDaysBetween
    -- Ejemplo: 200 / 5 = 40 potions/día

    -- 2. Calcular días desde última compra
    daysSinceLastPurchase = (now - pattern.lastPurchase) / (24*60*60)
    -- Ejemplo: 5 días

    -- 3. Estimar cantidad consumida
    estimatedConsumed = avgConsumptionPerDay * daysSinceLastPurchase
    -- Ejemplo: 40 * 5 = 200

    -- 4. Estimar cantidad restante
    estimatedRemaining = max(0, pattern.typical - estimatedConsumed)
    -- Ejemplo: max(0, 200 - 200) = 0

    -- 5. Determinar si necesita restock
    needsRestock = estimatedRemaining < (pattern.typical * 0.3)
    -- Ejemplo: 0 < 60 → true

    return {
        avgConsumptionPerDay = 40,
        estimatedRemaining = 0,
        needsRestock = true,
    }
end
```

**Niveles de Severidad:**
- **HIGH**: `estimatedRemaining < 30%` del typical
- **MEDIUM**: `estimatedRemaining < 50%` del typical
- **LOW**: `estimatedRemaining < 70%` del typical

---

### 5.5 Modules/Vendor/SmartActionsPanel.lua

**Responsabilidad:** UI de acciones rápidas

**Componentes UI:**

```
┌──────────────────────────────────────────┐
│ 🎯 ACCIONES INTELIGENTES                 │
├──────────────────────────────────────────┤
│                                           │
│ 🔁 Repetir Última Compra                 │
│    └─ Raid Prep - 15 items - 4,400g      │
│    [BOTÓN: Click para cargar]            │
│                                           │
│ 📦 Usar Carrito Habitual                 │
│    └─ Martes Raid Prep (usado 8x)        │
│    [BOTÓN: Mostrar menú]                 │
│                                           │
│ ⭐ Guardar Carrito Actual                │
│    [BOTÓN: Guardar en favoritos]         │
│                                           │
└──────────────────────────────────────────┘
```

**API de Acciones:**
```lua
-- Re-buy última compra
SmartActions:RebuyLastOrder()

-- Mostrar menú de carritos detectados
SmartActions:ShowDetectedCartsMenu()

-- Cargar un carrito específico
SmartActions:LoadCart(cart)

-- Guardar carrito actual en favoritos
SmartActions:AddCurrentCartToFavorites()

-- Aplicar sugerencias de un carrito detectado
SmartActions:ApplySuggestion(detectedCart)
```

---

### 5.6 Modules/Vendor/SmartSuggestionsPanel.lua

**Responsabilidad:** Mostrar sugerencias contextuales

**Componentes UI:**

```
┌──────────────────────────────────────────┐
│ 💡 SUGERENCIAS PARA TI                   │
├──────────────────────────────────────────┤
│                                           │
│ Este carrito es 95% similar a:           │
│ "Martes Raid Prep"                       │
│                                           │
│ Items faltantes:                          │
│ • Flask of Power x20                      │
│                                           │
│ [Completar Carrito]  [Ignorar]           │
│                                           │
├──────────────────────────────────────────┤
│ ⚠️ RESTOCK RECOMENDADO                   │
├──────────────────────────────────────────┤
│                                           │
│ Agility Potion                            │
│ └─ Última compra: hace 5 días            │
│ └─ Estimado restante: ~0                 │
│ └─ Sugerencia: Comprar 200               │
│                                           │
└──────────────────────────────────────────┘
```

---

## 6. Flujos de Usuario

### 6.1 Flujo: Compra Rápida con Carrito Detectado

```
┌─────────────────────────────────────────────────────────┐
│ PASO 1: Usuario abre vendor                            │
├─────────────────────────────────────────────────────────┤
│ Sistema detecta:                                        │
│ - Contexto: Martes, 8pm                                │
│ - Carrito detectado: "Martes Raid Prep" (usado 8x)     │
│                                                         │
│ Popup automático aparece:                              │
│ ┌─────────────────────────────────────────────────┐   │
│ │ 💡 ¿Quieres tu carrito habitual?                │   │
│ │                                                  │   │
│ │ Martes Raid Prep                                │   │
│ │ • Agility Potion x200                           │   │
│ │ • Mana Potion x150                              │   │
│ │ • Food x100                                     │   │
│ │                                                  │   │
│ │ Total: ~4,400g                                  │   │
│ │                                                  │   │
│ │ [A] Sí, cargar  [B] No, navegar manual         │   │
│ └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ PASO 2: Usuario presiona A                             │
├─────────────────────────────────────────────────────────┤
│ Sistema:                                                │
│ 1. Carga carrito completo                              │
│ 2. Muestra preview con total                           │
│ 3. Foco en botón "Comprar Todo"                        │
│                                                         │
│ Usuario presiona A de nuevo → Compra ejecutada         │
│                                                         │
│ Tiempo total: 3 segundos ⚡                             │
└─────────────────────────────────────────────────────────┘
```

### 6.2 Flujo: Item Individual con Predicción

```
┌─────────────────────────────────────────────────────────┐
│ PASO 1: Usuario selecciona "Agility Potion"            │
├─────────────────────────────────────────────────────────┤
│ Sistema muestra panel derecho:                         │
│                                                         │
│ ┌─────────────────────────────────────────────────┐   │
│ │ Agility Potion                                  │   │
│ │                                                  │   │
│ │ 💡 SUGERENCIAS                                  │   │
│ │ • Sueles comprar: ~200 (±20)                   │   │
│ │ • Última compra: hace 5 días                   │   │
│ │ • Estimado restante: ~0                        │   │
│ │ • Recomendación: Comprar ahora                 │   │
│ │                                                  │   │
│ │ Cantidad: [ 200 ] ◄── AUTO-LLENADA            │   │
│ │                                                  │   │
│ │ [A] Añadir al Carrito                          │   │
│ │ [X] Comprar Ahora                              │   │
│ └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ PASO 2: Usuario presiona A                             │
├─────────────────────────────────────────────────────────┤
│ Item añadido al carrito con cantidad sugerida          │
│                                                         │
│ Tiempo total: 2 segundos ⚡                             │
└─────────────────────────────────────────────────────────┘
```

### 6.3 Flujo: Carrito Nuevo Similar a Conocido

```
┌─────────────────────────────────────────────────────────┐
│ PASO 1: Usuario agrega items manualmente               │
├─────────────────────────────────────────────────────────┤
│ Carrito actual:                                         │
│ • Agility Potion x200                                  │
│ • Mana Potion x150                                     │
│ • Food x100                                            │
│                                                         │
│ Sistema analiza en background...                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ PASO 2: Sistema detecta similitud                      │
├─────────────────────────────────────────────────────────┤
│ Popup aparece:                                          │
│                                                         │
│ ┌─────────────────────────────────────────────────┐   │
│ │ 💡 Este carrito es 95% similar a:              │   │
│ │    "Martes Raid Prep"                          │   │
│ │                                                  │   │
│ │ ¿Completar con items faltantes?                │   │
│ │ • Flask of Power x20                           │   │
│ │                                                  │   │
│ │ [A] Sí, completar  [B] No                      │   │
│ └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ PASO 3: Usuario presiona A                             │
├─────────────────────────────────────────────────────────┤
│ Sistema:                                                │
│ 1. Agrega items faltantes                              │
│ 2. Muestra botón "⭐ Guardar como Favorito"            │
│                                                         │
│ Usuario puede:                                          │
│ - Comprar directamente                                  │
│ - Guardar con nombre custom                            │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Interfaz de Usuario

### 7.1 Layout Principal con Insights

```
┌──────────────────────────────────────────────────────────────────────┐
│ 💰 VENDOR: Innkeeper                           🎮 Gamepad   💼 3/16 │
├──────────────────┬───────────────────────────────────────────────────┤
│ CATALOG          │  🎯 ACCIONES INTELIGENTES                        │
│                  │                                                   │
│ ► Agility Potion │  🔁 Repetir Última Compra                        │
│   Mana Potion    │     └─ Raid Prep - 15 items - 4,400g             │
│   Food           │     [Click para cargar]                          │
│   Flask          │                                                   │
│                  │  📦 Carritos Detectados (3)                       │
│ [D-pad: Nav]     │     • Martes Raid Prep (8x)                      │
│                  │     • Jueves Restock (5x)                         │
│ 💡 SUGERENCIAS   │     • Weekly Supplies (12x)                       │
│                  │     [Click para ver menú]                         │
│ Este carrito es  │                                                   │
│ 95% similar a:   │  ⭐ Guardar Carrito Actual                        │
│ "Martes Raid     │     [Click para guardar]                          │
│ Prep"            │                                                   │
│                  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ ¿Usar ese?       │                                                   │
│ [Sí] [No]        │  📊 ITEM SELECCIONADO: Agility Potion            │
│                  │                                                   │
├──────────────────┤  💡 SUGERENCIAS INTELIGENTES                      │
│ 🛒 CARRITO (3)   │  • Sueles comprar: ~200 (±20)                    │
│ • Agility x200   │  • Última compra: hace 5 días                    │
│ • Mana x150      │  • Estimado restante: ~0                         │
│ • Food x100      │  ⚠️ Recomendación: Comprar ahora                 │
│                  │                                                   │
│ Total: 4,400g    │  Cantidad: [ 200 ] ◄── AUTO-SUGERIDA            │
│                  │                                                   │
│ [A] Buy All      │  [A] Añadir al Carrito  [X] Comprar Ahora       │
└──────────────────┴───────────────────────────────────────────────────┘
```

### 7.2 Menú de Carritos Detectados

```
┌────────────────────────────────────────────────┐
│          TUS CARRITOS DETECTADOS               │
├────────────────────────────────────────────────┤
│                                                 │
│ 1. Martes Raid Prep                            │
│    • Agility Potion x200                       │
│    • Mana Potion x150                          │
│    • Food x100                                 │
│    • Flask of Power x20                        │
│    💰 ~4,400g | 🔄 Usado 8 veces               │
│    [A] Usar Este Carrito                       │
│                                                 │
│ 2. Jueves Restock                              │
│    • Materials x500                            │
│    • Trade Goods x200                          │
│    💰 ~2,100g | 🔄 Usado 5 veces               │
│    [A] Usar Este Carrito                       │
│                                                 │
│ 3. Weekly Supplies                             │
│    • General Items x...                        │
│    💰 ~1,800g | 🔄 Usado 12 veces              │
│    [A] Usar Este Carrito                       │
│                                                 │
├────────────────────────────────────────────────┤
│ [B] Cancelar                                   │
└────────────────────────────────────────────────┘
```

### 7.3 Dialog: Guardar Favorito

```
┌────────────────────────────────────────────────┐
│          GUARDAR CARRITO EN FAVORITOS          │
├────────────────────────────────────────────────┤
│                                                 │
│ Nombre del carrito:                            │
│ [________________________]                     │
│                                                 │
│ Icono: (opcional)                              │
│ [🔥] [⚔️] [🛡️] [💊] [🍖]                     │
│                                                 │
│ Notas: (opcional)                              │
│ [________________________]                     │
│ [________________________]                     │
│                                                 │
│ Preview:                                        │
│ • Agility Potion x200                          │
│ • Mana Potion x150                             │
│ • Food x100                                    │
│ Total: 4,400g                                  │
│                                                 │
├────────────────────────────────────────────────┤
│ [A] Guardar    [B] Cancelar                    │
└────────────────────────────────────────────────┘
```

---

## 8. Plan de Implementación

### Fase 1: Fundación (Core Data & Telemetry) ⏱️ 2-3 horas

**Archivos a crear:**
- `Core/Telemetry.lua`
- Actualizar `Core/Addon.lua` para inicializar telemetry

**Tareas:**
1. ✅ Definir estructura de `BetterControlDB` v2.0
2. ✅ Implementar `Telemetry:Init()`
3. ✅ Implementar `Telemetry:TrackPurchase(data)`
4. ✅ Implementar `Telemetry:GetPurchaseHistory(filters)`
5. ✅ Implementar rotación de historial
6. ✅ Integrar en `VendorFrame:OnPurchaseComplete()`

**Criterios de aceptación:**
- [x] Cada compra se guarda completa en `purchaseHistory`
- [x] Timestamp, weekday, hour capturados correctamente
- [x] Historial no excede 1000 items
- [x] Pueden filtrarse compras por vendor, fecha, itemId

---

### Fase 2: Análisis de Patrones ⏱️ 3-4 horas

**Archivos a crear:**
- `Core/QuantityPatternAnalyzer.lua`
- `Core/CartPatternRecognizer.lua`
- `Core/ConsumptionEstimator.lua`

**Tareas:**
1. ✅ Implementar análisis de cantidades (mediana, stdDev, confianza)
2. ✅ Implementar generación de fingerprints de carrito
3. ✅ Implementar detección de carritos recurrentes
4. ✅ Implementar cálculo de similaridad (Jaccard)
5. ✅ Implementar estimación de consumo
6. ✅ Implementar detección de necesidad de restock
7. ✅ Llamar análisis después de cada compra (debounced)

**Criterios de aceptación:**
- [x] `quantityPatterns` contiene sugerencias correctas
- [x] `detectedCarts` identifica carritos con 3+ ocurrencias
- [x] Similaridad Jaccard funciona correctamente (>0.7 = match)
- [x] Estimaciones de consumo son razonables
- [x] Flags de `needsRestock` se activan correctamente

---

### Fase 3: UI de Acciones Inteligentes ⏱️ 4-5 horas

**Archivos a crear:**
- `Modules/Vendor/SmartActionsPanel.lua`
- `Modules/Vendor/SmartSuggestionsPanel.lua`

**Tareas:**
1. ✅ Crear panel de acciones inteligentes
2. ✅ Botón "Re-buy Last Order"
3. ✅ Botón "Use Detected Cart" con menú
4. ✅ Botón "Add to Favorites"
5. ✅ Dialog para nombrar favoritos
6. ✅ Integrar en `VendorFrame`

**Criterios de aceptación:**
- [x] Botones visibles y funcionales
- [x] Re-buy carga último carrito correctamente
- [x] Menú de carritos muestra opciones disponibles
- [x] Guardar favorito funciona con nombre custom

---

### Fase 4: Sugerencias Contextuales ⏱️ 3-4 horas

**Archivos a modificar:**
- `Modules/Vendor/CatalogView.lua`
- `Modules/Vendor/BuyFlow.lua`
- `Modules/Vendor/VendorFrame.lua`

**Tareas:**
1. ✅ Auto-llenar cantidad sugerida al seleccionar item
2. ✅ Mostrar mensaje de restock si aplica
3. ✅ Detectar similaridad de carrito actual en tiempo real
4. ✅ Popup de sugerencia cuando carrito similar detectado
5. ✅ Botón para completar carrito con items faltantes

**Criterios de aceptación:**
- [x] Cantidad se pre-llena automáticamente si hay patrón
- [x] Mensaje de restock aparece si `needsRestock = true`
- [x] Popup de similaridad aparece si >70% match
- [x] Completar carrito funciona correctamente

---

### Fase 5: Auto-Suggestions al Abrir Vendor ⏱️ 2-3 horas

**Archivos a modificar:**
- `Modules/Vendor/VendorFrame.lua`

**Tareas:**
1. ✅ Al abrir vendor, analizar contexto (día, hora)
2. ✅ Buscar carrito detectado que coincida con contexto
3. ✅ Mostrar popup: "¿Quieres tu carrito habitual?"
4. ✅ Opción de cargar o ignorar
5. ✅ Configuración para desactivar auto-suggestions

**Criterios de aceptación:**
- [x] Popup aparece si hay carrito con contexto similar
- [x] Usuario puede aceptar (A) o rechazar (B)
- [x] Configuración permite desactivar feature

---

### Fase 6: Polish & Testing ⏱️ 2-3 horas

**Tareas:**
1. ✅ Agregar comando `/bcv stats` para ver métricas
2. ✅ Agregar comando `/bcv insights` para debug
3. ✅ Testing con múltiples compras
4. ✅ Verificar performance (análisis debe ser <100ms)
5. ✅ Documentación en `README.md`
6. ✅ Changelog actualizado

**Criterios de aceptación:**
- [x] Comandos funcionan correctamente
- [x] Sin errores Lua
- [x] Performance aceptable
- [x] Documentación completa

---

## 9. Criterios de Aceptación

### Funcionales

#### F1: Detección de Patrones de Cantidad
- [x] Después de 3 compras del mismo item con cantidades similares, se detecta patrón
- [x] Cantidad sugerida es la mediana (no promedio)
- [x] Confianza >60% para sugerir
- [x] Cantidad se pre-llena automáticamente

#### F2: Reconocimiento de Carritos Recurrentes
- [x] Después de 3 compras con mismo fingerprint, se detecta carrito
- [x] Nombre auto-generado basado en contexto
- [x] Similaridad Jaccard >70% considera match
- [x] Menú muestra carritos ordenados por uso (más usado primero)

#### F3: Predicción de Consumo
- [x] Tasa de consumo calculada correctamente (cantidad / días)
- [x] Estimación de cantidad restante razonable
- [x] Flag `needsRestock` cuando <30% del típico
- [x] Mensaje de restock mostrado en UI

#### F4: Acciones Rápidas
- [x] "Re-buy Last Order" carga carrito completo en <1s
- [x] "Use Detected Cart" muestra menú funcional
- [x] "Add to Favorites" permite nombrar y guardar
- [x] Favoritos persisten entre sesiones

#### F5: Auto-Suggestions
- [x] Popup aparece al abrir vendor si hay carrito contextual
- [x] Usuario puede aceptar o rechazar
- [x] Cargar carrito sugerido funciona correctamente

### No Funcionales

#### NF1: Performance
- [x] Análisis de patrones completo <100ms
- [x] Generación de fingerprint <10ms
- [x] UI responsive (no lag al abrir vendor)
- [x] Rotación de historial no causa stutter

#### NF2: Datos
- [x] Historial limitado a 1000 items
- [x] SavedVariables no excede 5MB
- [x] Rotación automática funciona correctamente

#### NF3: UX
- [x] Todas las sugerencias pueden ignorarse
- [x] Sistema se puede desactivar en configuración
- [x] Mensajes claros y concisos
- [x] No spam de popups

---

## 10. Configuración del Usuario

### Settings Panel

```lua
BetterControlDB.insightSettings = {
    -- Master switch
    enabled = true,

    -- Feature toggles
    autoSuggestQuantity = true,      -- Pre-llenar cantidad
    showCartSuggestions = true,       -- Sugerencias de carrito similar
    showRestockWarnings = true,       -- Alertas de restock
    showAutoPopup = true,             -- Popup al abrir vendor

    -- Behavior
    minOccurrencesForPattern = 3,    -- Mínimo para detectar patrón
    minConfidenceForSuggestion = 0.6, -- Mínimo confianza para sugerir
    similarityThreshold = 0.7,        -- Umbral de similaridad (Jaccard)

    -- Data limits
    maxHistoryItems = 1000,
    maxDetectedCarts = 20,
    maxFavorites = 50,

    -- Performance
    analysisDebounce = 2,             -- Segundos
}
```

---

## 11. Testing Scenarios

### Scenario 1: Nuevo Usuario (Sin Historial)
**Dado:** Usuario sin compras previas
**Cuando:** Abre vendor y compra items
**Entonces:**
- No hay sugerencias (normal)
- Compra se guarda en historial
- Después de 3ra compra similar, aparece sugerencia

### Scenario 2: Usuario con Patrón Establecido
**Dado:** Usuario con 5+ compras de "Agility Potion x200"
**Cuando:** Selecciona "Agility Potion"
**Entonces:**
- Cantidad 200 pre-llenada
- Mensaje: "Sueles comprar ~200 (±X)"
- Puede modificar o aceptar

### Scenario 3: Carrito Recurrente Detectado
**Dado:** Usuario compró mismo carrito 3+ veces
**Cuando:** Abre vendor en contexto similar
**Entonces:**
- Popup: "¿Quieres tu carrito habitual?"
- Puede aceptar o rechazar
- Al aceptar, carrito completo cargado

### Scenario 4: Similaridad de Carrito
**Dado:** Usuario agrega items manualmente
**Cuando:** Carrito es 95% similar a uno detectado
**Entonces:**
- Popup: "Este carrito es 95% similar a X"
- Opción de completar con items faltantes
- Opción de guardar como favorito

### Scenario 5: Restock Necesario
**Dado:** Última compra de "Potion" hace 5 días (típico: 200 cada 5 días)
**Cuando:** Selecciona "Potion"
**Entonces:**
- Mensaje: "⚠️ Probablemente te quedan ~0"
- Sugerencia de comprar cantidad típica
- Advertencia visual (color naranja/rojo)

---

## 12. Notas de Implementación

### Performance Considerations

1. **Debouncing de Análisis**
   - No analizar inmediatamente después de cada compra
   - Esperar 2 segundos de inactividad
   - Evitar múltiples análisis consecutivos

2. **Lazy Loading**
   - No analizar patrones hasta que se necesiten
   - Cache de resultados de análisis
   - Invalidar cache solo cuando hay nuevos datos

3. **Límites de Datos**
   - Máximo 1000 compras en historial
   - Rotar automáticamente al exceder
   - Eliminar carritos detectados no usados en 90 días

### Edge Cases

1. **Usuario compra cantidades muy variables**
   - Confianza baja → no sugerir
   - Mostrar rango amplio
   - Permitir override manual

2. **Múltiples carritos en mismo contexto**
   - Mostrar el más usado
   - Opción de ver todos
   - Aprender de selección del usuario

3. **Items nuevos sin historial**
   - No sugerir cantidad
   - Campo vacío (usuario ingresa manual)
   - Empezar a rastrear desde primera compra

4. **Cambio de hábitos del usuario**
   - Patterns se adaptan con el tiempo
   - Compras recientes pesan más
   - Ventana deslizante de 90 días

---

## 13. Métricas de Éxito

### KPIs

1. **Tiempo promedio de compra**
   - Objetivo: <5 segundos para compras recurrentes
   - Baseline: ~120 segundos (manual)
   - Mejora esperada: 95%+

2. **Uso de sugerencias**
   - Objetivo: 70%+ de compras usan cantidad sugerida
   - 50%+ de compras usan carritos detectados

3. **Satisfacción del usuario**
   - Feedback positivo en comentarios
   - Baja tasa de desactivación del feature

### Telemetry (Internal)

```lua
-- Métricas a trackear
telemetry = {
    suggestionsAccepted = 0,     -- Veces que aceptó sugerencia
    suggestionsRejected = 0,     -- Veces que rechazó
    cartsLoaded = 0,             -- Veces que usó carrito detectado
    favoritesUsed = 0,           -- Veces que usó favorito
    avgPurchaseTime = 0,         -- Promedio en segundos
    totalTimeSaved = 0,          -- Estimación de tiempo ahorrado
}
```

---

# PARTE II: INTERFAZ REVOLUCIONARIA & CONTROLES AVANZADOS

---

## 10. Sistema de Controles Revolucionario

### 🎮 Filosofía de Diseño

**Objetivo:** Maximizar la velocidad y minimizar la fricción para usuarios de gamepad, manteniendo accesibilidad para mouse/keyboard.

**Principios:**
1. **Maximum 5 segundos para cualquier tarea compleja**
2. **Zero menú diving**: Todo accesible en 1-2 botones
3. **Contextual actions**: UI se adapta al contexto
4. **Muscle memory friendly**: Controles consistentes
5. **Progressive disclosure**: Complejidad opcional

### 🎯 Mapeo de Controles Base

```
┌─────────────────────────────────────────────────────┐
│          CONTROL SCHEME - Better Control 2.0        │
├─────────────────────────────────────────────────────┤
│                                                      │
│  PRIMARY ACTIONS (Face Buttons)                     │
│  ├─ A: Confirm / Add to Cart / Buy                  │
│  ├─ B: Cancel / Back / Close                        │
│  ├─ X: Quick Action (contextual)                    │
│  └─ Y: Max Action (contextual)                      │
│                                                      │
│  NAVIGATION (D-Pad)                                  │
│  ├─ Up/Down: Navigate list                          │
│  ├─ Left/Right: Adjust quantity (in detail view)    │
│  └─ Quick Filters (when pressed once):              │
│      ├─ Up: Consumables filter                      │
│      ├─ Down: Trade Goods filter                    │
│      ├─ Left: Equipment filter                      │
│      └─ Right: All items (reset)                    │
│                                                      │
│  TABS & PAGINATION (Shoulders)                       │
│  ├─ LB: Previous Tab                                │
│  ├─ RB: Next Tab                                    │
│  ├─ LT: Page Down / Large Step Down                 │
│  └─ RT: Page Up / Large Step Up                     │
│                                                      │
│  CONTEXT MENUS (View/Menu)                          │
│  ├─ View (hold): Radial Menu                        │
│  └─ Menu: Open Cart / Commit Action                 │
│                                                      │
│  ADVANCED (Stick Clicks + Combos)                   │
│  ├─ L3: Reserved for system                         │
│  ├─ R3: Reserved for system                         │
│  ├─ L3 + R3: Macro trigger (power users)            │
│  └─ Stick gestures: Quick actions (flick)           │
│                                                      │
│  CONTEXT OVERLAYS (Hold Modifier)                   │
│  ├─ Hold L2: Show batch overlay                     │
│  ├─ Hold R2: Show action overlay                    │
│  └─ Hold L2+R2: Mega batch mode                     │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### ⚡ Quick Actions Matrix

**Contexto: Item Seleccionado en Catalog**

| Input | Action | Description |
|-------|--------|-------------|
| A | Add to Cart | Añade con cantidad sugerida |
| X | Quick Buy | Compra 1 stack inmediatamente |
| Y | Max Buy | Compra máximo affordable |
| Hold L2 + A | +10 | Añade 10 al carrito |
| Hold L2 + B | +100 | Añade 100 al carrito |
| Hold L2 + X | +1000 | Añade 1000 al carrito |
| Hold R2 + A | Add to Favorites | Guarda en favoritos |
| Hold R2 + X | Buy Now | Skip cart, compra directo |
| Flick Right Stick Up | Quick Add | Añade al carrito (gesture) |

---

## 11. Radial Menu System

### 🎯 Concepto

En lugar de menú lateral tradicional, usar **radial menu** activado con `View` (hold), navegado con stick derecho.

**Ventajas:**
- ⚡ Más rápido (1 movimiento de stick)
- 🎯 Más visual (ver todas las opciones)
- 🎮 Más gamepad-friendly
- 💪 Muscle memory natural

### 📐 Layout del Radial Menu

```
            [Historial]
                 │
                 │
    [Favoritos]──┼──[Carrito]
                 │
                 │
            [Filtros]
                 │
            [Ajustes]
```

### 🔧 Implementación

**Archivo:** `Core/RadialMenu.lua`

```lua
-- Core/RadialMenu.lua
local _, ns = ...

local RadialMenu = {}
ns.RadialMenu = RadialMenu

-- Configuración del menú
local MENU_SECTIONS = {
    {angle = 0,   name = "Carrito",   icon = "🛒", action = "openCart"},
    {angle = 72,  name = "Favoritos", icon = "⭐", action = "openFavorites"},
    {angle = 144, name = "Historial", icon = "📜", action = "openHistory"},
    {angle = 216, name = "Filtros",   icon = "🔍", action = "openFilters"},
    {angle = 288, name = "Ajustes",   icon = "⚙️", action = "openSettings"},
}

-- Estado del menú
RadialMenu.isOpen = false
RadialMenu.selectedSection = nil
RadialMenu.holdStartTime = 0

-- Activar menú (hold View button)
function RadialMenu:OnViewButtonDown()
    self.holdStartTime = GetTime()

    -- Esperar 0.3s para confirmar que es "hold" y no "tap"
    C_Timer.After(0.3, function()
        if self.holdStartTime > 0 then
            self:Open()
        end
    end)
end

function RadialMenu:OnViewButtonUp()
    local holdDuration = GetTime() - self.holdStartTime
    self.holdStartTime = 0

    if self.isOpen then
        -- Ejecutar acción seleccionada
        if self.selectedSection then
            self:ExecuteAction(self.selectedSection.action)
        end
        self:Close()
    end
end

-- Abrir menú
function RadialMenu:Open()
    if not self.frame then
        self:CreateFrame()
    end

    self.isOpen = true
    self.frame:Show()
    self.frame.fadeIn:Play()

    -- Enable stick tracking
    self.frame:SetScript("OnUpdate", function()
        self:OnStickUpdate()
    end)
end

-- Cerrar menú
function RadialMenu:Close()
    self.isOpen = false
    self.selectedSection = nil

    if self.frame then
        self.frame.fadeOut:Play()
        C_Timer.After(0.2, function()
            self.frame:Hide()
        end)
    end
end

-- Crear frame del menú
function RadialMenu:CreateFrame()
    local frame = CreateFrame("Frame", "BCRadialMenu", UIParent)
    frame:SetSize(400, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    -- Background semi-transparente
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.7)

    -- Centro del radial
    frame.center = CreateFrame("Frame", nil, frame)
    frame.center:SetSize(80, 80)
    frame.center:SetPoint("CENTER")

    local centerBg = frame.center:CreateTexture(nil, "ARTWORK")
    centerBg:SetAllPoints()
    centerBg:SetColorTexture(0.2, 0.2, 0.2, 0.9)

    -- Secciones del radial
    frame.sections = {}
    for i, section in ipairs(MENU_SECTIONS) do
        local btn = self:CreateSection(frame, section, i)
        table.insert(frame.sections, btn)
    end

    -- Animaciones
    frame.fadeIn = frame:CreateAnimationGroup()
    local fadeInAlpha = frame.fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.2)

    frame.fadeOut = frame:CreateAnimationGroup()
    local fadeOutAlpha = frame.fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(0.2)

    self.frame = frame
end

-- Crear sección del radial
function RadialMenu:CreateSection(parent, section, index)
    local btn = CreateFrame("Frame", nil, parent)
    btn:SetSize(100, 100)

    -- Posición en círculo (radio 150px)
    local radius = 150
    local angleRad = math.rad(section.angle - 90)  -- -90 para que 0° sea arriba
    local x = radius * math.cos(angleRad)
    local y = radius * math.sin(angleRad)

    btn:SetPoint("CENTER", parent, "CENTER", x, y)

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Highlight (cuando está seleccionado)
    btn.highlight = btn:CreateTexture(nil, "BORDER")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(0.3, 0.5, 1, 0.5)
    btn.highlight:Hide()

    -- Icon
    btn.icon = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    btn.icon:SetPoint("CENTER", 0, 10)
    btn.icon:SetText(section.icon)

    -- Label
    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.label:SetPoint("CENTER", 0, -20)
    btn.label:SetText(section.name)

    btn.section = section

    return btn
end

-- Update stick tracking
function RadialMenu:OnStickUpdate()
    -- Simular stick con mouse para testing (reemplazar con API real de gamepad)
    local centerX, centerY = self.frame:GetCenter()
    local mouseX, mouseY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    mouseX = mouseX / scale
    mouseY = mouseY / scale

    local dx = mouseX - centerX
    local dy = mouseY - centerY
    local distance = math.sqrt(dx*dx + dy*dy)

    if distance < 40 then
        -- Dentro del círculo central, no seleccionar nada
        self:SetSelectedSection(nil)
        return
    end

    -- Calcular ángulo
    local angle = math.deg(math.atan2(dy, dx)) + 90
    if angle < 0 then angle = angle + 360 end

    -- Encontrar sección más cercana
    local closestSection = nil
    local minDiff = 999

    for _, btn in ipairs(self.frame.sections) do
        local sectionAngle = btn.section.angle
        local diff = math.abs(angle - sectionAngle)
        if diff > 180 then diff = 360 - diff end

        if diff < minDiff then
            minDiff = diff
            closestSection = btn
        end
    end

    self:SetSelectedSection(closestSection)
end

-- Seleccionar sección
function RadialMenu:SetSelectedSection(sectionBtn)
    -- Deseleccionar anterior
    if self.selectedSection then
        self.selectedSection.highlight:Hide()
        self.selectedSection.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    end

    -- Seleccionar nuevo
    self.selectedSection = sectionBtn

    if sectionBtn then
        sectionBtn.highlight:Show()
        sectionBtn.bg:SetColorTexture(0.2, 0.3, 0.5, 0.9)

        -- Haptic feedback (si disponible)
        if ns.HapticFeedback then
            ns.HapticFeedback:Trigger("selection", 0.1)
        end
    end
end

-- Ejecutar acción
function RadialMenu:ExecuteAction(action)
    if action == "openCart" then
        ns.VendorFrame:ShowCart()
    elseif action == "openFavorites" then
        ns.SmartActions:ShowDetectedCartsMenu()
    elseif action == "openHistory" then
        ns.SmartActions:ShowHistoryMenu()
    elseif action == "openFilters" then
        ns.VendorFrame:ShowFiltersMenu()
    elseif action == "openSettings" then
        ns.VendorFrame:ShowSettings()
    end

    -- Haptic feedback de confirmación
    if ns.HapticFeedback then
        ns.HapticFeedback:Trigger("confirm", 0.2)
    end
end

ns.RegisterModule("RadialMenu", RadialMenu)
```

### 🎨 Visual del Radial Menu

```
        ┌─────────────────────────────────┐
        │                                 │
        │         📜 Historial            │
        │              │                  │
        │              │                  │
        │    ⭐───────●───────🛒          │
        │  Favoritos       Carrito        │
        │              │                  │
        │              │                  │
        │         🔍 Filtros              │
        │              │                  │
        │         ⚙️ Ajustes             │
        │                                 │
        └─────────────────────────────────┘

● = Centro (neutral)
Stick derecho mueve selección
Soltar View = ejecuta acción
```

---

## 12. Gesture System con Sticks

### 🎯 Concepto

Movimientos rápidos del stick (flicks) ejecutan acciones comunes sin presionar botones adicionales.

**Inspiración:** Dark Souls, Sekiro, Elden Ring

### 📐 Gestos Soportados

**Right Stick Gestures (en Catalog View):**
```
Flick Up    → Quick Add to Cart
Flick Down  → Remove from Cart
Flick Left  → Previous Item (fast scroll)
Flick Right → Next Item (fast scroll)
```

**Left Stick Gestures (en Detail View):**
```
Flick Up    → +10 quantity
Flick Down  → -10 quantity
Flick Left  → -100 quantity
Flick Right → +100 quantity
```

### 🔧 Implementación

**Archivo:** `Core/GestureRecognizer.lua`

```lua
-- Core/GestureRecognizer.lua
local _, ns = ...

local GestureRecognizer = {}
ns.GestureRecognizer = GestureRecognizer

-- Configuración
local GESTURE_THRESHOLD = 0.7  -- Mínimo desplazamiento para detectar
local GESTURE_TIMEOUT = 0.3    -- Máximo tiempo para completar gesture
local COOLDOWN_TIME = 0.2      -- Cooldown entre gestures

-- Estado
GestureRecognizer.leftStick = {x = 0, y = 0, lastX = 0, lastY = 0}
GestureRecognizer.rightStick = {x = 0, y = 0, lastX = 0, lastY = 0}
GestureRecognizer.gestureStart = 0
GestureRecognizer.lastGesture = 0

-- Inicializar
function GestureRecognizer:Init()
    -- Hook al sistema de input
    self:StartTracking()
end

-- Detectar gestos en cada frame
function GestureRecognizer:OnUpdate()
    local now = GetTime()

    -- Cooldown check
    if now - self.lastGesture < COOLDOWN_TIME then
        return
    end

    -- Leer posición de sticks (API de gamepad)
    local leftX, leftY = self:GetLeftStickPosition()
    local rightX, rightY = self:GetRightStickPosition()

    -- Actualizar estado
    self.leftStick.lastX = self.leftStick.x
    self.leftStick.lastY = self.leftStick.y
    self.leftStick.x = leftX
    self.leftStick.y = leftY

    self.rightStick.lastX = self.rightStick.x
    self.rightStick.lastY = self.rightStick.y
    self.rightStick.x = rightX
    self.rightStick.y = rightY

    -- Detectar gestos
    self:DetectGesture("left", self.leftStick)
    self:DetectGesture("right", self.rightStick)
end

-- Detectar gesto en un stick
function GestureRecognizer:DetectGesture(stickName, stick)
    -- Calcular delta
    local dx = stick.x - stick.lastX
    local dy = stick.y - stick.lastY
    local magnitude = math.sqrt(dx*dx + dy*dy)

    -- Threshold check
    if magnitude < GESTURE_THRESHOLD then
        return
    end

    -- Determinar dirección
    local angle = math.deg(math.atan2(dy, dx))
    local direction = nil

    if angle >= -45 and angle < 45 then
        direction = "right"
    elseif angle >= 45 and angle < 135 then
        direction = "up"
    elseif angle >= 135 or angle < -135 then
        direction = "left"
    else
        direction = "down"
    end

    -- Ejecutar acción
    self:ExecuteGesture(stickName, direction, magnitude)
    self.lastGesture = GetTime()
end

-- Ejecutar acción del gesto
function GestureRecognizer:ExecuteGesture(stick, direction, magnitude)
    local action = string.format("%s_%s", stick, direction)

    -- Mapeo de acciones
    local actions = {
        -- Right stick gestures
        right_up = function()
            if ns.VendorFrame.activeView == "catalog" then
                ns.VendorFrame:QuickAddToCart()
            end
        end,

        right_down = function()
            if ns.VendorFrame.activeView == "catalog" then
                ns.VendorFrame:RemoveSelectedFromCart()
            end
        end,

        right_left = function()
            ns.VendorFrame:ScrollList(-5)  -- Fast scroll
        end,

        right_right = function()
            ns.VendorFrame:ScrollList(5)  -- Fast scroll
        end,

        -- Left stick gestures (en detail view)
        left_up = function()
            if ns.VendorFrame.views.buyFlow:IsVisible() then
                ns.VendorFrame.views.buyFlow:AdjustQuantity(10)
            end
        end,

        left_down = function()
            if ns.VendorFrame.views.buyFlow:IsVisible() then
                ns.VendorFrame.views.buyFlow:AdjustQuantity(-10)
            end
        end,

        left_left = function()
            if ns.VendorFrame.views.buyFlow:IsVisible() then
                ns.VendorFrame.views.buyFlow:AdjustQuantity(-100)
            end
        end,

        left_right = function()
            if ns.VendorFrame.views.buyFlow:IsVisible() then
                ns.VendorFrame.views.buyFlow:AdjustQuantity(100)
            end
        end,
    }

    -- Ejecutar
    if actions[action] then
        actions[action]()

        -- Visual feedback
        self:ShowGestureFeedback(direction, magnitude)

        -- Haptic feedback
        if ns.HapticFeedback then
            ns.HapticFeedback:Trigger("gesture", magnitude * 0.3)
        end
    end
end

-- Feedback visual del gesto
function GestureRecognizer:ShowGestureFeedback(direction, magnitude)
    -- Crear animación visual que muestra la dirección del gesto
    -- (ej: flecha que aparece y desaparece)

    if not self.feedbackFrame then
        self.feedbackFrame = CreateFrame("Frame", nil, UIParent)
        self.feedbackFrame:SetSize(100, 100)
        self.feedbackFrame:SetPoint("CENTER")
        self.feedbackFrame:SetFrameStrata("TOOLTIP")

        self.feedbackFrame.arrow = self.feedbackFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge2")
        self.feedbackFrame.arrow:SetPoint("CENTER")
    end

    -- Símbolos por dirección
    local arrows = {
        up = "↑",
        down = "↓",
        left = "←",
        right = "→"
    }

    self.feedbackFrame.arrow:SetText(arrows[direction] or "●")
    self.feedbackFrame:Show()

    -- Animación de fade out
    C_Timer.After(0.5, function()
        self.feedbackFrame:Hide()
    end)
end

-- Obtener posición de sticks (placeholder - usar API real)
function GestureRecognizer:GetLeftStickPosition()
    -- TODO: Usar API real de gamepad de WoW
    -- Por ahora, simular con WASD
    local x, y = 0, 0

    if IsKeyDown("W") then y = 1 end
    if IsKeyDown("S") then y = -1 end
    if IsKeyDown("A") then x = -1 end
    if IsKeyDown("D") then x = 1 end

    return x, y
end

function GestureRecognizer:GetRightStickPosition()
    -- TODO: Usar API real de gamepad de WoW
    -- Por ahora, simular con arrow keys
    local x, y = 0, 0

    if IsKeyDown("UP") then y = 1 end
    if IsKeyDown("DOWN") then y = -1 end
    if IsKeyDown("LEFT") then x = -1 end
    if IsKeyDown("RIGHT") then x = 1 end

    return x, y
end

function GestureRecognizer:StartTracking()
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
        self:OnUpdate()
    end)
end

ns.RegisterModule("GestureRecognizer", GestureRecognizer)
```

---

## 13. Batch Operations Avanzadas

### 🎯 Concepto

Sistema de overlays contextuales que aparecen al mantener triggers (L2/R2), mostrando acciones batch disponibles.

### 📐 Sistema de Overlays

**L2 (Hold) → Batch Overlay:**
```
┌─────────────────────────────────┐
│   BATCH OPERATIONS              │
├─────────────────────────────────┤
│   A: +10 items                  │
│   B: +100 items                 │
│   X: +1000 items                │
│   Y: Fill to Stack              │
└─────────────────────────────────┘
```

**R2 (Hold) → Action Overlay:**
```
┌─────────────────────────────────┐
│   QUICK ACTIONS                 │
├─────────────────────────────────┤
│   A: Add to Cart                │
│   B: Buy Now (skip cart)        │
│   X: Add to Favorites           │
│   Y: Show in Cart               │
└─────────────────────────────────┘
```

**L2 + R2 (Hold) → Mega Batch:**
```
┌─────────────────────────────────┐
│   MEGA BATCH MODE               │
├─────────────────────────────────┤
│   A: +1000 items                │
│   B: +10000 items               │
│   X: Max Affordable             │
│   Y: Fill All Bags              │
└─────────────────────────────────┘
```

### 🔧 Implementación

**Archivo:** `Core/BatchOverlay.lua`

```lua
-- Core/BatchOverlay.lua
local _, ns = ...

local BatchOverlay = {}
ns.BatchOverlay = BatchOverlay

-- Estado de triggers
BatchOverlay.L2Down = false
BatchOverlay.R2Down = false
BatchOverlay.currentOverlay = nil

-- Overlay configs
local OVERLAYS = {
    batch = {
        title = "BATCH OPERATIONS",
        actions = {
            {button = "A", label = "+10 items", value = 10},
            {button = "B", label = "+100 items", value = 100},
            {button = "X", label = "+1000 items", value = 1000},
            {button = "Y", label = "Fill to Stack", value = "stack"},
        }
    },

    actions = {
        title = "QUICK ACTIONS",
        actions = {
            {button = "A", label = "Add to Cart", action = "addToCart"},
            {button = "B", label = "Buy Now", action = "buyNow"},
            {button = "X", label = "Add to Favorites", action = "addFavorite"},
            {button = "Y", label = "Show in Cart", action = "showCart"},
        }
    },

    mega = {
        title = "MEGA BATCH MODE",
        actions = {
            {button = "A", label = "+1000 items", value = 1000},
            {button = "B", label = "+10000 items", value = 10000},
            {button = "X", label = "Max Affordable", value = "max"},
            {button = "Y", label = "Fill All Bags", value = "fillBags"},
        }
    },
}

-- Trigger state changed
function BatchOverlay:OnTriggerStateChanged(trigger, isDown)
    if trigger == "L2" then
        self.L2Down = isDown
    elseif trigger == "R2" then
        self.R2Down = isDown
    end

    -- Determinar qué overlay mostrar
    if self.L2Down and self.R2Down then
        self:ShowOverlay("mega")
    elseif self.L2Down then
        self:ShowOverlay("batch")
    elseif self.R2Down then
        self:ShowOverlay("actions")
    else
        self:HideOverlay()
    end
end

-- Mostrar overlay
function BatchOverlay:ShowOverlay(overlayType)
    if self.currentOverlay == overlayType then
        return  -- Ya visible
    end

    self.currentOverlay = overlayType

    if not self.frame then
        self:CreateFrame()
    end

    local config = OVERLAYS[overlayType]

    -- Actualizar contenido
    self.frame.title:SetText(config.title)

    for i, action in ipairs(config.actions) do
        local row = self.frame.rows[i]
        if row then
            row.button:SetText(action.button)
            row.label:SetText(action.label)
            row.data = action
            row:Show()
        end
    end

    -- Ocultar filas no usadas
    for i = #config.actions + 1, #self.frame.rows do
        self.frame.rows[i]:Hide()
    end

    self.frame:Show()
    self.frame.fadeIn:Play()
end

-- Ocultar overlay
function BatchOverlay:HideOverlay()
    if not self.frame or not self.currentOverlay then
        return
    end

    self.currentOverlay = nil
    self.frame.fadeOut:Play()

    C_Timer.After(0.2, function()
        if self.frame then
            self.frame:Hide()
        end
    end)
end

-- Ejecutar acción (cuando se presiona botón mientras overlay visible)
function BatchOverlay:ExecuteAction(button)
    if not self.currentOverlay then
        return false  -- No hay overlay, dejar que el input normal proceda
    end

    local config = OVERLAYS[self.currentOverlay]

    -- Buscar acción correspondiente
    for _, action in ipairs(config.actions) do
        if action.button == button then
            self:DoAction(action)
            return true  -- Acción ejecutada, consumir input
        end
    end

    return false
end

-- Ejecutar acción específica
function BatchOverlay:DoAction(action)
    local selectedItem = ns.VendorFrame:GetSelectedItem()

    if not selectedItem then
        return
    end

    if action.value then
        -- Batch quantity
        if type(action.value) == "number" then
            ns.VendorFrame:AddToCart(selectedItem.itemId, action.value)
        elseif action.value == "stack" then
            local stackSize = ns.Compat.GetItemMaxStack(selectedItem.index) or 200
            ns.VendorFrame:AddToCart(selectedItem.itemId, stackSize)
        elseif action.value == "max" then
            -- Calcular máximo affordable
            local maxQty = math.floor(GetMoney() / selectedItem.price)
            ns.VendorFrame:AddToCart(selectedItem.itemId, maxQty)
        elseif action.value == "fillBags" then
            -- Calcular cuánto cabe en las bolsas
            local freeSlots = ns.VendorFrame:GetFreeBagSlots()
            local stackSize = ns.Compat.GetItemMaxStack(selectedItem.index) or 200
            local maxQty = freeSlots * stackSize
            ns.VendorFrame:AddToCart(selectedItem.itemId, maxQty)
        end
    elseif action.action then
        -- Quick actions
        if action.action == "addToCart" then
            ns.VendorFrame:QuickAddToCart()
        elseif action.action == "buyNow" then
            ns.VendorFrame:BuyNow(selectedItem)
        elseif action.action == "addFavorite" then
            ns.SmartActions:AddItemToFavorites(selectedItem)
        elseif action.action == "showCart" then
            ns.VendorFrame:ShowCart()
        end
    end

    -- Haptic feedback
    if ns.HapticFeedback then
        ns.HapticFeedback:Trigger("batchAction", 0.3)
    end
end

-- Crear frame del overlay
function BatchOverlay:CreateFrame()
    local frame = CreateFrame("Frame", "BCBatchOverlay", UIParent)
    frame:SetSize(300, 200)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    -- Background
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.9)

    -- Border
    frame.border = CreateFrame("Frame", nil, frame, "DialogBorderTemplate")

    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -10)

    -- Action rows
    frame.rows = {}
    for i = 1, 4 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(280, 30)
        row:SetPoint("TOP", 0, -40 - (i-1) * 35)

        -- Button indicator
        row.button = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.button:SetPoint("LEFT", 10, 0)
        row.button:SetTextColor(1, 0.8, 0)

        -- Label
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("LEFT", row.button, "RIGHT", 10, 0)

        table.insert(frame.rows, row)
    end

    -- Animaciones
    frame.fadeIn = frame:CreateAnimationGroup()
    local fadeInAlpha = frame.fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.15)

    frame.fadeOut = frame:CreateAnimationGroup()
    local fadeOutAlpha = frame.fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(0.15)

    self.frame = frame
end

ns.RegisterModule("BatchOverlay", BatchOverlay)
```

---

## 14. Haptic Feedback System

### 🎯 Concepto

Vibraciones táctiles del mando para feedback sensorial de acciones.

**Tipos de Feedback:**
- `selection` - Vibración suave al seleccionar (0.1s)
- `confirm` - Doble pulso al confirmar (0.2s)
- `error` - Vibración larga al error (0.5s)
- `success` - Patrón de éxito (3 pulsos cortos)
- `gesture` - Vibración proporcional al gesto
- `batchAction` - Vibración media para batch

### 🔧 Implementación

**Archivo:** `Core/HapticFeedback.lua`

```lua
-- Core/HapticFeedback.lua
local _, ns = ...

local HapticFeedback = {}
ns.HapticFeedback = HapticFeedback

-- Patrones de vibración
local PATTERNS = {
    selection = {
        {duration = 0.05, intensity = 0.3}
    },

    confirm = {
        {duration = 0.08, intensity = 0.5},
        {pause = 0.05},
        {duration = 0.08, intensity = 0.5}
    },

    error = {
        {duration = 0.3, intensity = 0.8}
    },

    success = {
        {duration = 0.06, intensity = 0.6},
        {pause = 0.04},
        {duration = 0.06, intensity = 0.6},
        {pause = 0.04},
        {duration = 0.06, intensity = 0.6}
    },

    gesture = {
        {duration = 0.12, intensity = 0.4}
    },

    batchAction = {
        {duration = 0.15, intensity = 0.5}
    },
}

-- Trigger vibration
function HapticFeedback:Trigger(patternName, intensityMultiplier)
    if not ns.DB.insightSettings.enableHapticFeedback then
        return
    end

    intensityMultiplier = intensityMultiplier or 1
    local pattern = PATTERNS[patternName]

    if not pattern then
        return
    end

    -- Ejecutar patrón
    local totalTime = 0

    for _, pulse in ipairs(pattern) do
        if pulse.duration then
            C_Timer.After(totalTime, function()
                self:Vibrate(pulse.duration, pulse.intensity * intensityMultiplier)
            end)
            totalTime = totalTime + pulse.duration
        elseif pulse.pause then
            totalTime = totalTime + pulse.pause
        end
    end
end

-- Vibrar mando (usa API de WoW si disponible)
function HapticFeedback:Vibrate(duration, intensity)
    -- TODO: Usar API real de vibración de WoW/gamepad
    -- Por ahora, placeholder

    -- Si WoW tiene API de vibración:
    -- C_GamePad.Vibrate(duration, intensity)

    -- Alternativamente, registrar en telemetry para debug
    ns.Debug(string.format("Haptic: %.2fs @ %.1f intensity", duration, intensity))
end

ns.RegisterModule("HapticFeedback", HapticFeedback)
```

---

## 15. Macro System para Power Users

### 🎯 Concepto

Sistema de grabación y reproducción de secuencias de compras complejas, ejecutables con un solo trigger.

**Use Cases:**
- Compra semanal completa: Carrito 1 → Carrito 2 → Vendor 2 → Carrito 3
- Raid prep automático: Materiales + Consumibles + Flasks
- Batch processing de múltiples vendors

### 📐 Macro Structure

```lua
Macro = {
    macroId = "user-weekly-prep",
    name = "Weekly Raid Prep",
    description = "Compra semanal completa de consumibles",
    icon = "🔥",
    hotkey = "L3+R3",  -- Trigger (ambos sticks)
    steps = {
        {
            type = "loadCart",
            cartId = "auto-raid-prep",
            waitFor = "loaded"
        },
        {
            type = "execute",
            action = "buyAll",
            waitFor = "complete"
        },
        {
            type = "wait",
            duration = 2  -- Segundos
        },
        {
            type = "switchVendor",
            vendorName = "Alchemist",
            waitFor = "open"
        },
        {
            type = "loadCart",
            cartId = "auto-flasks",
            waitFor = "loaded"
        },
        {
            type = "execute",
            action = "buyAll",
            waitFor = "complete"
        },
        {
            type = "notify",
            message = "✅ Weekly prep completado!"
        }
    },
    estimatedTime = 20,  -- Segundos
    estimatedCost = 15000,  -- Oro
    lastUsed = 0,
    useCount = 0,
}
```

### 🔧 Implementación

**Archivo:** `Core/MacroSystem.lua`

(El código sería extenso, incluir en implementación real)

---

## 16. Budget & Safe Mode

### 🎯 Budget Mode

Límite de gasto configurable con advertencias.

```lua
-- Config
BetterControlDB.budgetMode = {
    enabled = true,
    weeklyLimit = 50000,  -- Oro
    currentSpent = 12500,
    resetDay = 1,  -- Lunes
    warnings = {
        at50Percent = true,
        at75Percent = true,
        at90Percent = true,
    }
}
```

**UI Indicator:**
```
┌─────────────────────────────────┐
│ 💰 BUDGET MODE                  │
│ Límite Semanal: 50,000g         │
│ Gastado: 12,500g (25%)          │
│ Restante: 37,500g               │
│ ▓▓▓▓░░░░░░░░░░░░ 25%           │
└─────────────────────────────────┘
```

### 🛡️ Safe Mode

Confirmaciones extra para prevenir errores costosos.

```lua
-- Config
BetterControlDB.safeMode = {
    enabled = true,
    confirmLargePurchases = true,  -- >1000g
    confirmMaxBuy = true,
    cooldownBetweenBatch = 2,  -- Segundos
    maxBatchSize = 5000,
}
```

**Confirmation Dialog:**
```
┌─────────────────────────────────┐
│ ⚠️ COMPRA GRANDE                │
│                                 │
│ Estás a punto de gastar:        │
│ 4,500g en este carrito          │
│                                 │
│ Esto dejará tu balance en:      │
│ 15,500g                         │
│                                 │
│ [A] Confirmar  [B] Cancelar     │
└─────────────────────────────────┘
```

---

## 17. Adaptive UI System

### 🎯 Concepto

UI que se adapta dinámicamente según patrones del usuario, contexto y preferencias aprendidas.

### 📐 Adaptaciones

**1. Context-Aware Layout**
```lua
-- Si usuario siempre usa carrito el Martes 8pm:
-- → Mostrar sugerencia de carrito destacada

-- Si usuario nunca usa favoritos:
-- → Ocultar sección de favoritos, expandir catálogo
```

**2. Dynamic Button Mapping**
```lua
-- Si usuario usa 90%+ gesture system:
-- → Priorizar gestos, minimizar botones

-- Si usuario prefiere botones tradicionales:
-- → Deshabilitar gestos, maximizar botones
```

**3. Personalized Quick Actions**
```lua
-- Detectar acciones más usadas
-- → Ponerlas en primera posición

-- Ejemplo:
-- Usuario usa "Buy Now" 80% del tiempo
-- → Mapear "Buy Now" a botón A directo
```

### 🔧 Implementación

**Archivo:** `Core/AdaptiveUI.lua`

```lua
-- Core/AdaptiveUI.lua
local _, ns = ...

local AdaptiveUI = {}
ns.AdaptiveUI = AdaptiveUI

-- Analizar patrones de uso
function AdaptiveUI:AnalyzeUsagePatterns()
    local telemetry = ns.DB.telemetry

    -- Detectar si usuario usa gestos
    local gestureUsage = telemetry.gesturesUsed or 0
    local buttonUsage = telemetry.buttonsUsed or 0
    local gestureRatio = gestureUsage / (gestureUsage + buttonUsage + 1)

    -- Detectar si usuario usa carritos
    local cartUsage = telemetry.cartsLoaded or 0
    local manualUsage = telemetry.manualPurchases or 0
    local cartRatio = cartUsage / (cartUsage + manualUsage + 1)

    -- Detectar acciones más frecuentes
    local actions = telemetry.actionFrequency or {}
    local topActions = self:GetTopActions(actions, 3)

    return {
        prefersGestures = gestureRatio > 0.6,
        prefersCarts = cartRatio > 0.5,
        topActions = topActions,
    }
end

-- Aplicar adaptaciones
function AdaptiveUI:ApplyAdaptations()
    local patterns = self:AnalyzeUsagePatterns()

    if patterns.prefersGestures then
        -- Habilitar gesture hints
        ns.VendorFrame:ShowGestureHints(true)
        -- Reducir button hints
        ns.VendorFrame:ShowButtonHints(false)
    end

    if patterns.prefersCarts then
        -- Expandir sección de carritos
        ns.VendorFrame:ExpandCartsSection()
        -- Reducir catálogo manual
        ns.VendorFrame:MinimizeCatalog()
    end

    -- Mapear acciones más usadas
    self:RemapQuickActions(patterns.topActions)
end

ns.RegisterModule("AdaptiveUI", AdaptiveUI)
```

---

## 18. Plan de Implementación UI

### Fase 7: Radial Menu ⏱️ 4-5 horas

**Archivos a crear:**
- `Core/RadialMenu.lua`

**Tareas:**
1. ✅ Implementar detección de hold View
2. ✅ Crear frame del radial con 5 secciones
3. ✅ Tracking de stick para selección
4. ✅ Animaciones de fade in/out
5. ✅ Ejecutar acciones al soltar
6. ✅ Integrar con VendorFrame

**Criterios:**
- [x] Hold View abre radial
- [x] Stick selecciona sección
- [x] Soltar View ejecuta acción
- [x] Animaciones suaves

---

### Fase 8: Gesture System ⏱️ 3-4 horas

**Archivos a crear:**
- `Core/GestureRecognizer.lua`

**Tareas:**
1. ✅ Tracking de sticks en OnUpdate
2. ✅ Detectar flicks (threshold + timeout)
3. ✅ Mapear gestos a acciones
4. ✅ Visual feedback de gestos
5. ✅ Cooldown entre gestos

**Criterios:**
- [x] Flicks detectados correctamente
- [x] Acciones ejecutadas
- [x] No false positives
- [x] Visual feedback visible

---

### Fase 9: Batch Overlays ⏱️ 4-5 horas

**Archivos a crear:**
- `Core/BatchOverlay.lua`

**Tareas:**
1. ✅ Detección de L2/R2 hold
2. ✅ Crear frames de overlays
3. ✅ Mostrar/ocultar según triggers
4. ✅ Ejecutar acciones batch
5. ✅ Mega batch mode (L2+R2)

**Criterios:**
- [x] Overlays aparecen al hold
- [x] Botones ejecutan batch
- [x] Mega batch funciona
- [x] Visual claro

---

### Fase 10: Haptic Feedback ⏱️ 2-3 horas

**Archivos a crear:**
- `Core/HapticFeedback.lua`

**Tareas:**
1. ✅ Definir patrones de vibración
2. ✅ Implementar Trigger con patrones
3. ✅ Integrar en acciones clave
4. ✅ Configuración para habilitar/deshabilitar

**Criterios:**
- [x] Vibraciones funcionan (si API disponible)
- [x] Patrones diferenciables
- [x] Puede desactivarse

---

### Fase 11: Macro System ⏱️ 6-8 horas

**Archivos a crear:**
- `Core/MacroSystem.lua`
- `Modules/Vendor/MacroEditor.lua`

**Tareas:**
1. ✅ Estructura de macros
2. ✅ Grabación de secuencias
3. ✅ Reproducción con steps
4. ✅ Editor visual de macros
5. ✅ Trigger L3+R3

**Criterios:**
- [x] Macros se graban correctamente
- [x] Reproducción funciona
- [x] Editor usable
- [x] Trigger funciona

---

### Fase 12: Budget & Safe Mode ⏱️ 3-4 horas

**Archivos a crear:**
- `Core/BudgetManager.lua`
- `Core/SafeMode.lua`

**Tareas:**
1. ✅ Budget tracking
2. ✅ Warnings en thresholds
3. ✅ UI indicator de budget
4. ✅ Safe mode confirmations
5. ✅ Cooldowns de batch

**Criterios:**
- [x] Budget tracking correcto
- [x] Warnings aparecen
- [x] Confirmaciones funcionan
- [x] Cooldowns respetados

---

### Fase 13: Adaptive UI ⏱️ 4-5 horas

**Archivos a crear:**
- `Core/AdaptiveUI.lua`

**Tareas:**
1. ✅ Análisis de patrones de uso
2. ✅ Aplicar adaptaciones
3. ✅ Configuración manual override
4. ✅ Testing con diferentes perfiles

**Criterios:**
- [x] Adaptaciones correctas
- [x] Usuario puede override
- [x] No intrusivo

---

## 19. Roadmap Futuro (Post v2.0)

### v2.1: ML Avanzado
- Predicción de "qué compraré hoy" basado en día/hora/contexto
- Detección de temporadas (eventos de WoW, expansiones)
- Correlaciones cruzadas: "Si compraste X ayer, hoy necesitas Y"

### v2.2: Integración Cloud (Opcional)
- Sincronizar perfiles entre personajes/cuentas
- Compartir favoritos con guild
- Analytics dashboard web

### v2.3: Voice Commands (Experimental)
- "Comprar raid prep" → ejecuta carrito
- "Cuánto llevo gastado esta semana"

---

## 15. Apéndices

### A. Ejemplo Completo de purchaseHistory Entry

```lua
{
    purchaseId = "20261231-1530-abc123",
    timestamp = 1735660200,
    vendor = "Innkeeper",
    cart = {
        {
            itemId = 12345,
            itemName = "Agility Potion",
            quantity = 200,
            unitCost = 12,
            totalCost = 2400,
            isConsumable = true,
        },
        {
            itemId = 67890,
            itemName = "Mana Potion",
            quantity = 150,
            unitCost = 10,
            totalCost = 1500,
            isConsumable = true,
        },
        {
            itemId = 11111,
            itemName = "Food",
            quantity = 100,
            unitCost = 5,
            totalCost = 500,
            isConsumable = true,
        },
    },
    totalCost = 4400,
    itemCount = 3,
    weekday = 2,  -- Martes
    hour = 15,    -- 3pm
    context = {
        preRaid = true,
        weeklyRestock = false,
        manualPurchase = false,
    }
}
```

### B. Fórmulas Estadísticas

**Mediana:**
```
sorted = sort(quantities)
n = length(sorted)
median = sorted[ceil(n/2)]  if odd
       = (sorted[n/2] + sorted[n/2+1]) / 2  if even
```

**Desviación Estándar:**
```
mean = sum(quantities) / n
variance = sum((x - mean)^2 for x in quantities) / n
stdDev = sqrt(variance)
```

**Coeficiente de Variación:**
```
CV = stdDev / mean
confidence = 1 - min(CV, 1)
```

**Jaccard Similarity:**
```
J(A, B) = |A ∩ B| / |A ∪ B|
```

### C. Referencias

- **GICS 1.3.4**: Sistema de insights original (Node.js/Python)
- **Amazon "Volver a Comprar"**: Inspiración UX
- **Netflix Recommendations**: Algoritmos de similaridad
- **WoW SavedVariables**: Sistema de persistencia

---

**FIN DEL DOCUMENTO**

---

## Changelog del Documento

**v1.0 - 2026-03-31**
- Especificación inicial completa
- Arquitectura definida
- Plan de implementación en 6 fases
- Criterios de aceptación establecidos
