# =====================================================
# ROL 4: VISUALIZACIÓN DE RESULTADOS
# Proyecto: Análisis de gasto público en Perú
# Archivo: gasto_publico_limpio_inferencia.csv
# =====================================================

# ============================================================
#CONFIGURACIÓN INICIAL
# ============================================================

# Para limpiar el workspace, por si hubiera algún dataset 
# o información cargada
rm(list = ls())

# Limpiar la consola
cat("\014")

# Para limpiar el área de gráficos
graphics.off()

options(scipen = 999)

# Cambiar el directorio de trabajo
library(tidyverse)
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# Paquetes, Cargar librerías necesarias

library(pacman)
p_load(dplyr, ggplot2, datos, tidyverse, gganimate,forcats)

# Crear carpeta para guardar gráficos si no existe
dir.create("outputs/graficos", recursive = TRUE, showWarnings = FALSE)

# -----------------------------
# 1. Leer y preparar los datos
# -----------------------------
datos <- read.csv("gasto_publico_limpio_inferencia.csv", 
                  stringsAsFactors = FALSE, 
                  fileEncoding = "UTF-8")

# Limpieza básica: eliminar filas con valores NA en variables clave
datos_clean <- datos %>%
  filter(!is.na(monto_devengado) & !is.na(tasa_giro) & monto_devengado > 0)

# ----------------------------------------------------------------
# GRÁFICO 1: Top 10 funciones con mayor monto devengado (barras verticales)
# ----------------------------------------------------------------
top_funciones <- datos_clean %>%
  group_by(funcion_nombre) %>%
  summarise(total_monto = sum(monto_devengado, na.rm = TRUE)) %>%
  arrange(desc(total_monto)) %>%
  slice_head(n = 10)

p1 <- ggplot(top_funciones, aes(x = reorder(funcion_nombre, total_monto), 
                                y = total_monto)) +
  geom_bar(stat = "identity", fill = "#2c7bb6") +
  coord_flip() +   # Convertir a barras horizontales para mejor lectura
  labs(
    title = "Top 10 funciones con mayor gasto devengado",
    subtitle = "Datos del sector público (setiembre 2024)",
    x = "Función",
    y = "Monto devengado (S/.)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.y = element_text(size = 10),
    axis.text.x = element_text(angle = 0, hjust = 1)
  )
p1
# Guardar gráfico 1
ggsave("outputs/graficos/grafico1_top_funciones.png", p1, width = 10, height = 6, dpi = 300)

# ----------------------------------------------------------------
# GRÁFICO 2: Boxplot de tasa de giro por categoría de gasto
p2 <- ggplot(datos_clean, aes(x = categoria_gasto_nombre, 
                              y = monto_devengado, 
                              fill = categoria_gasto_nombre)) +
  geom_boxplot(outlier.shape = 21, outlier.size = 1.5, outlier.alpha = 0.5) +
  scale_y_log10() +  # Esta es la clave para que las cajas se formen perfecto
  scale_fill_manual(values = c("#f4a261", "#e76f51")) +
  labs(
    title = "Distribución del monto devengado según categoría",
    subtitle = "Comparación entre gasto corriente y gasto de capital",
    x = "Categoría de gasto",
    y = "Monto devengado (Escala Logarítmica)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    legend.position = "none",
    axis.text.x = element_text(angle = 0, hjust = 0.5)
  )
p2
# Guardar gráfico 2
ggsave("outputs/graficos/grafico2_boxplot_monto.png", p2, width = 8, height = 6, dpi = 300)
# ----------------------------------------------------------------
# GRÁFICO 3: Monto devengado por región (top 10) – barras horizontales
# ----------------------------------------------------------------
top_regiones <- datos_clean %>%
  group_by(departamento_ejecutora_nombre) %>%
  summarise(total_monto = sum(monto_devengado, na.rm = TRUE)) %>%
  arrange(desc(total_monto)) %>%
  slice_head(n = 10)

p3 <- ggplot(top_regiones, aes(x = reorder(departamento_ejecutora_nombre, total_monto), 
                               y = total_monto)) +
  geom_bar(stat = "identity", fill = "#2a9d8f")  +
  labs(
    title = "Top 10 regiones con mayor gasto devengado",
    subtitle = "Gobiernos regionales – setiembre 2024",
    x = "Departamento",
    y = "Monto devengado (S/.)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.y = element_text(size = 10)
  )
p3
# Guardar gráfico 3
ggsave("outputs/graficos/grafico3_top_regiones.png", p3, width = 10, height = 6, dpi = 300)

# Mensaje final
cat("Tres gráficos generados y guardados en la carpeta 'outputs/graficos/':\n")
cat("  1. grafico1_top_funciones.png\n")
cat("  2. grafico2_boxplot_tasa_giro.png\n")
cat("  3. grafico3_top_regiones.png\n")

