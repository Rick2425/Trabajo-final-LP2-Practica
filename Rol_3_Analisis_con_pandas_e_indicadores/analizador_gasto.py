import pandas as pd
import numpy as np
from pathlib import Path

class AnalizadorGasto:
    def __init__(self, ruta_csv):
        print(f"Cargando datos desde: {ruta_csv}...")
        self.df = pd.read_csv(ruta_csv)
        
        # Convertir a numérico y llenar nulos con 0
        self.df['monto_devengado'] = pd.to_numeric(self.df['monto_devengado'], errors='coerce').fillna(0)
        self.df['tasa_giro'] = pd.to_numeric(self.df['tasa_giro'], errors='coerce').fillna(0)
        
        print(f"Base cargada con {self.df.shape[0]} filas y {self.df.shape[1]} columnas.\n")

    def gasto_por_sector(self):
        """Agrupa el gasto devengado y promedia la tasa de giro por sector."""
        resumen = self.df.groupby('sector_nombre', as_index=False).agg(
            gasto_total_devengado=('monto_devengado', 'sum'),
            tasa_giro_promedio=('tasa_giro', 'mean')
        )
        resumen['tasa_giro_promedio'] = resumen['tasa_giro_promedio'].round(2)
        return resumen.sort_values(by='gasto_total_devengado', ascending=False)

    def gasto_por_region(self):
        """Agrupa el gasto devengado y promedia la tasa de giro por región."""
        resumen = self.df.groupby('departamento_ejecutora_nombre', as_index=False).agg(
            gasto_total_devengado=('monto_devengado', 'sum'),
            tasa_giro_promedio=('tasa_giro', 'mean')
        )
        resumen['tasa_giro_promedio'] = resumen['tasa_giro_promedio'].round(2)
        return resumen.sort_values(by='gasto_total_devengado', ascending=False)

    def gasto_por_nivel_gobierno(self):
        """Analiza la distribución del gasto según el nivel de gobierno."""
        resumen = self.df.groupby('nivel_gobierno_nombre', as_index=False).agg(
            gasto_total_devengado=('monto_devengado', 'sum'),
            tasa_giro_promedio=('tasa_giro', 'mean'),
            cantidad_proyectos=('monto_devengado', 'count')
        )
        resumen['tasa_giro_promedio'] = resumen['tasa_giro_promedio'].round(2)
        return resumen.sort_values(by='gasto_total_devengado', ascending=False)

    def ranking_top(self, df_agrupado, columna_orden='gasto_total_devengado', top=10):
        """Extrae los primeros registros según la columna de orden especificada."""
        return df_agrupado.nlargest(top, columna_orden)

    def guardar_tabla(self, df_tabla, ruta_salida):
        """Guarda el DataFrame en un archivo CSV."""
        ruta = Path(ruta_salida)
        ruta.parent.mkdir(parents=True, exist_ok=True)
        df_tabla.to_csv(ruta, index=False, encoding='utf-8-sig')
        print(f"Archivo generado: {ruta}")

# ==========================================
# EJECUCIÓN DEL SCRIPT
# ==========================================
if __name__ == '__main__':
    # 1. Instanciar la clase con el archivo de datos limpio
    analizador = AnalizadorGasto(r'C:\Users\tuppi\Documents\LP2 PRACTICA\gasto_publico_limpio_inferencia.csv')

    # 2. Generar los DataFrames con los indicadores
    df_sector = analizador.gasto_por_sector()
    df_region = analizador.gasto_por_region()
    df_nivel = analizador.gasto_por_nivel_gobierno()

    # 3. Generar Rankings
    top_sectores = analizador.ranking_top(df_sector)

    # 4. Guardar los resultados en la carpeta processed
    print("Guardando archivos...")
    analizador.guardar_tabla(df_sector, 'data/processed/resumen_sector.csv')
    analizador.guardar_tabla(df_region, 'data/processed/resumen_region.csv')
    analizador.guardar_tabla(df_nivel, 'data/processed/resumen_nivel_gobierno.csv')
    analizador.guardar_tabla(top_sectores, 'data/processed/ranking_sectores.csv')

    print("\nFase 3 completada")