import requests
import pandas as pd
import time
import os
import random

class ExtractorMEF:
    def __init__(self, resource_id, limite=32000): 
        self.url_base = "https://api.datosabiertos.mef.gob.pe/DatosAbiertos/v1/datastore_search"
        self.resource_id = resource_id 
        self.limite = limite

    def obtener_datos(self, offset):
        url_completa = f"{self.url_base}?resource_id={self.resource_id}&limit={self.limite}&offset={offset}"
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept": "application/json",
            "Connection": "keep-alive"
        }
        # Aumentamos el timeout a 120 segundos para bloques masivos
        respuesta = requests.get(url_completa, headers=headers, timeout=120)
        respuesta.raise_for_status() 
        return respuesta.json()
        
    def extraer_y_guardar_incremental(self, ruta_salida):
        offset = 0
        pagina_actual = 1
        es_primer_bloque = True
        total_registros_guardados = 0  # <---Contador global
        META_REGISTROS = 100000        # <---Tu límite objetivo

        while total_registros_guardados < META_REGISTROS:
            print(f"Consultando bloque {pagina_actual} (Offset: {offset})...")
            
            try:
                data_json = self.obtener_datos(offset)
                registros = data_json.get("records", [])
                if not registros:
                    registros = data_json.get("result", {}).get("records", [])

                if not registros:
                    print("-> No hay más registros disponibles en el servidor.")
                    break

                # --- LÓGICA DE CORTE PARA NO PASARSE DE 100K ---
                registros_restantes = META_REGISTROS - total_registros_guardados
                # Si el bloque actual trae más de lo que falta, recortamos la lista
                if len(registros) > registros_restantes:
                    registros = registros[:registros_restantes]
                # -----------------------------------------------

                # Convertir a DataFrame y guardar
                df = pd.DataFrame(registros)
                df.to_csv(ruta_salida, mode='a', index=False, header=es_primer_bloque, encoding="utf-8-sig")
                
                es_primer_bloque = False
                total_registros_guardados += len(registros) # Actualizamos el contador
                
                print(f"-> Guardados {len(registros)} registros. (Total acumulado: {total_registros_guardados})")

                if total_registros_guardados >= META_REGISTROS:
                    print("-> ¡Meta de 100,000 registros alcanzada!")
                    break

                if len(registros) < self.limite: # Si el servidor ya no tiene más
                    break

                offset += self.limite
                pagina_actual += 1
                
                time.sleep(random.uniform(2.0, 4.0)) 

            except Exception as e:
                print(f"Error en bloque {pagina_actual}: {e}")
                break

# =============================================================================
# EJECUCIÓN
# =============================================================================
if __name__ == "__main__":
    ID_RECURSO = "a50cf1dc-1655-446d-95a3-de6d5351dc8c"
    carpeta_script = os.path.dirname(os.path.abspath(__file__)) 
    ruta_archivo = os.path.join(carpeta_script, "gasto_publico_raw_2024.csv")
    
    # Borrar archivo anterior si existe para evitar duplicados
    if os.path.exists(ruta_archivo):
        os.remove(ruta_archivo)
        print("Archivo previo eliminado, iniciando nueva descarga.")

    extractor = ExtractorMEF(resource_id=ID_RECURSO, limite=32000)
    print("Iniciando extracción incremental...")
    extractor.extraer_y_guardar_incremental(ruta_archivo)
    print(f"\nProceso finalizado. El archivo se guardó en: {ruta_archivo}")
