# ============================================================
# ROL 2 - LIMPIEZA Y NORMALIZACIÓN DE DATOS MEF
# Entrada : data/raw/gasto_publico_raw_2024.csv
# Salida  : data/processed/gasto_publico_limpio.csv
# ============================================================

# ============================================================
# 0. LIMPIEZA DEL ENTORNO Y CONFIGURACIÓN INICIAL
# ============================================================

rm(list = ls())
graphics.off()
cat("\014")
if (rstudioapi::isAvailable()) {
  ruta_script <- tryCatch(
    dirname(rstudioapi::getActiveDocumentContext()$path),
    error = function(e) NA
  )
  
  if (!is.na(ruta_script) && ruta_script != "." && ruta_script != "") {
    setwd(ruta_script)
  }
}
cat("\014")
getwd()

options(scipen = 999)
options(digits = 3)

library(pacman)

p_load(data.table)

cat("\014")

# ============================================================
# 1. CONFIGURACIÓN
# ============================================================

carpeta_proyecto <- getwd()

archivo_entrada <- "gasto_publico_raw_2024.csv"
archivo_salida <- "gasto_publico_limpio_inferencia.csv"
archivo_resumen <- "resumen_limpieza.csv"

ruta_entrada <- file.path(carpeta_proyecto, archivo_entrada)
ruta_salida <- file.path(carpeta_proyecto, archivo_salida)
ruta_resumen <- file.path(carpeta_proyecto, archivo_resumen)

anio_estudio <- 2024
mes_estudio <- 9

cat("Carpeta actual:\n")
print(carpeta_proyecto)

if (!file.exists(ruta_entrada)) {
  cat("\nArchivos CSV encontrados:\n")
  print(list.files(carpeta_proyecto, pattern = "\\.csv$", ignore.case = TRUE))
  stop("No se encontró gasto_publico_raw_2024.csv en la carpeta actual.")
}

# ============================================================
# 2. FUNCIONES AUXILIARES
# ============================================================

normalizar_nombre_columna <- function(x) {
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_|_$", "", x)
  return(x)
}

limpiar_texto <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x <- gsub("\\s+", " ", x)
  x <- toupper(x)
  x[x %in% c("", "NA", "N/A", "NULL", "NONE", "-", "--", "S/I", "SIN INFORMACION")] <- NA
  return(x)
}

convertir_numero_seguro <- function(x) {
  if (is.numeric(x) || is.integer(x)) {
    return(as.numeric(x))
  }
  
  x <- as.character(x)
  x <- trimws(x)
  x[x %in% c("", "NA", "N/A", "NULL", "null", "-", "--")] <- NA
  
  x <- gsub("S/\\.?|SOLES|%|\\s", "", x, ignore.case = TRUE)
  x <- gsub("[^0-9eE,\\.\\+\\-]", "", x)
  
  resultado <- sapply(x, function(valor) {
    if (is.na(valor) || valor == "") {
      return(NA_real_)
    }
    
    if (grepl("^[+-]?[0-9]+(\\.[0-9]+)?[eE][+-]?[0-9]+$", valor)) {
      return(suppressWarnings(as.numeric(valor)))
    }
    
    tiene_coma <- grepl(",", valor)
    tiene_punto <- grepl("\\.", valor)
    
    if (tiene_coma && tiene_punto) {
      pos_coma <- max(gregexpr(",", valor)[[1]])
      pos_punto <- max(gregexpr("\\.", valor)[[1]])
      
      if (pos_coma > pos_punto) {
        valor <- gsub("\\.", "", valor)
        valor <- gsub(",", ".", valor)
      } else {
        valor <- gsub(",", "", valor)
      }
      
    } else if (tiene_coma && !tiene_punto) {
      if (grepl(",[0-9]{1,2}$", valor)) {
        valor <- gsub(",", ".", valor)
      } else {
        valor <- gsub(",", "", valor)
      }
    }
    
    return(suppressWarnings(as.numeric(valor)))
  })
  
  return(as.numeric(resultado))
}

# ============================================================
# 3. LECTURA DEL CSV
# ============================================================

cat("\nLeyendo archivo con fread...\n")

datos <- fread(
  input = ruta_entrada,
  encoding = "UTF-8",
  na.strings = c("", "NA", "N/A", "NULL", "null", "-", "--"),
  showProgress = TRUE,
  tmpdir = carpeta_proyecto,
  nThread = 1
)

filas_iniciales <- nrow(datos)
columnas_iniciales <- ncol(datos)

cat("\nFilas iniciales:", filas_iniciales, "\n")
cat("Columnas iniciales:", columnas_iniciales, "\n")

names(datos) <- normalizar_nombre_columna(names(datos))

# ============================================================
# 4. SELECCIÓN DE COLUMNAS NECESARIAS
# Se selecciona monto_girado solo para calcular tasa_giro.
# Luego se elimina para que la base final tenga 10 variables.
# ============================================================

columnas_necesarias <- c(
  "ano_eje",
  "mes_eje",
  "nivel_gobierno_nombre",
  "sector_nombre",
  "departamento_ejecutora_nombre",
  "funcion_nombre",
  "fuente_financiamiento_nombre",
  "categoria_gasto_nombre",
  "monto_devengado",
  "monto_girado"
)

columnas_existentes <- columnas_necesarias[columnas_necesarias %in% names(datos)]

datos <- datos[, ..columnas_existentes]

cat("\nColumnas seleccionadas inicialmente:\n")
print(names(datos))

# ============================================================
# 5. LIMPIEZA DE TEXTOS Y CONVERSIÓN NUMÉRICA
# ============================================================

columnas_texto <- names(datos)[sapply(datos, is.character)]

for (col in columnas_texto) {
  datos[, (col) := limpiar_texto(get(col))]
}

datos[, ano_eje := as.integer(convertir_numero_seguro(ano_eje))]
datos[, mes_eje := as.integer(convertir_numero_seguro(mes_eje))]
datos[, monto_devengado := convertir_numero_seguro(monto_devengado)]
datos[, monto_girado := convertir_numero_seguro(monto_girado)]

# ============================================================
# 6. FILTRO TEMPORAL
# Filas = registros correspondientes al mes de estudio
# ============================================================

filas_antes_filtro_mes <- nrow(datos)

datos <- datos[
  ano_eje == anio_estudio &
    mes_eje == mes_estudio
]

filas_despues_filtro_mes <- nrow(datos)

cat("\nFiltro temporal aplicado:\n")
cat("Año:", anio_estudio, "\n")
cat("Mes:", mes_estudio, "\n")
cat("Filas antes del filtro:", filas_antes_filtro_mes, "\n")
cat("Filas después del filtro:", filas_despues_filtro_mes, "\n")

# ============================================================
# 7. LIMPIEZA DE FILAS
# ============================================================

filas_antes_limpieza <- nrow(datos)

# Eliminar filas sin monto devengado, porque es la variable central.
datos <- datos[!is.na(monto_devengado)]

# Eliminar montos negativos.
datos <- datos[monto_devengado >= 0]

# Si monto_girado está vacío, se reemplaza por 0 para poder calcular.
datos[is.na(monto_girado), monto_girado := 0]

# Eliminar girados negativos.
datos <- datos[monto_girado >= 0]

# Eliminar filas sin categorías clave.
variables_categoricas <- c(
  "nivel_gobierno_nombre",
  "sector_nombre",
  "departamento_ejecutora_nombre",
  "funcion_nombre",
  "fuente_financiamiento_nombre",
  "categoria_gasto_nombre"
)

datos <- datos[rowSums(is.na(datos[, ..variables_categoricas])) < length(variables_categoricas)]

filas_despues_limpieza <- nrow(datos)

cat("\nFilas eliminadas en limpieza:", filas_antes_limpieza - filas_despues_limpieza, "\n")

# ============================================================
# 8. VARIABLE DERIVADA PARA INFERENCIA
# ============================================================

datos[, tasa_giro := fifelse(
  monto_devengado > 0,
  (monto_girado / monto_devengado) * 100,
  NA_real_
)]

# Evitar tasas absurdas por registros administrativos raros.
datos[tasa_giro < 0 | tasa_giro > 150, tasa_giro := NA_real_]

# ============================================================
# 9. BASE FINAL CON MÁXIMO 10 VARIABLES
# ============================================================

columnas_finales <- c(
  "ano_eje",
  "mes_eje",
  "nivel_gobierno_nombre",
  "sector_nombre",
  "departamento_ejecutora_nombre",
  "funcion_nombre",
  "fuente_financiamiento_nombre",
  "categoria_gasto_nombre",
  "monto_devengado",
  "tasa_giro"
)

datos_final <- datos[, ..columnas_finales]

# Eliminar duplicados exactos en la base final.
filas_antes_duplicados <- nrow(datos_final)

datos_final <- unique(datos_final)

filas_despues_duplicados <- nrow(datos_final)

cat("Duplicados eliminados:", filas_antes_duplicados - filas_despues_duplicados, "\n")

# ============================================================
# 10. GUARDADO DE RESULTADOS
# ============================================================

fwrite(datos_final, ruta_salida, bom = TRUE)

resumen <- data.table(
  criterio = c(
    "Filas iniciales",
    "Columnas iniciales",
    "Año de estudio",
    "Mes de estudio",
    "Filas después del filtro mensual",
    "Filas finales",
    "Columnas finales"
  ),
  valor = c(
    filas_iniciales,
    columnas_iniciales,
    anio_estudio,
    mes_estudio,
    filas_despues_filtro_mes,
    nrow(datos_final),
    ncol(datos_final)
  )
)

fwrite(resumen, ruta_resumen, bom = TRUE)

cat("\n============================================\n")
cat("LIMPIEZA FINALIZADA\n")
cat("============================================\n")

cat("\nArchivo limpio generado:\n")
print(ruta_salida)

cat("\nResumen de limpieza:\n")
print(ruta_resumen)

cat("\nDimensión final de la base:\n")
cat("Filas:", nrow(datos_final), "\n")
cat("Columnas:", ncol(datos_final), "\n")

cat("\nColumnas finales:\n")
print(names(datos_final))

cat("\nResumen numérico:\n")
print(summary(datos_final[, .(monto_devengado, tasa_giro)]))