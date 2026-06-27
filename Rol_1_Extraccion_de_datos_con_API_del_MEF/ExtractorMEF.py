import requests
import pandas as pd
import time
import os
import sys
from pathlib import Path
from dataclasses import dataclass

# ============================================================
# CONFIGURACIÓN GENERAL DE EXTRACCIÓN
# ============================================================

@dataclass
class MEFConfig:
    resource_id: str
    nombre_archivo: str = "gasto_publico_raw_2024.csv"
    limite_por_bloque: int = 32000
    meta_registros: int = 100000
    timeout: int = 120
    max_reintentos: int = 3
    duracion_carga: int = 6

    url_base: str = "https://api.datosabiertos.mef.gob.pe/DatosAbiertos/v1/datastore_search"


# ============================================================
# INTERFAZ DE CARGA EN CONSOLA
# ============================================================

class ConsoleLoader:
    def __init__(self, duracion: int = 6, ancho_barra: int = 30):
        self.duracion = duracion
        self.ancho_barra = ancho_barra

    def mostrar(self, mensaje: str = "Preparando extracción"):
        print(mensaje)

        for porcentaje in range(101):
            progreso = int((porcentaje / 100) * self.ancho_barra)
            barra = "█" * progreso + "░" * (self.ancho_barra - progreso)

            sys.stdout.write(f"\r[{barra}] {porcentaje:3d}%")
            sys.stdout.flush()

            time.sleep(self.duracion / 100)

        print("\nCarga completada.\n")


# ============================================================
# CLIENTE API MEF
# ============================================================

class MEFAPIClient:
    def __init__(self, config: MEFConfig):
        self.config = config
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            "Accept": "application/json",
            "Connection": "keep-alive"
        })

    def solicitar_bloque(self, offset: int) -> dict:
        params = {
            "resource_id": self.config.resource_id,
            "limit": self.config.limite_por_bloque,
            "offset": offset
        }

        for intento in range(1, self.config.max_reintentos + 1):
            try:
                respuesta = self.session.get(
                    self.config.url_base,
                    params=params,
                    timeout=self.config.timeout
                )

                respuesta.raise_for_status()
                return respuesta.json()

            except requests.exceptions.RequestException as error:
                print(f"\nError HTTP en intento {intento}: {error}")

                if intento == self.config.max_reintentos:
                    raise

                espera = intento * 3
                print(f"Reintentando en {espera} segundos...")
                time.sleep(espera)

    @staticmethod
    def extraer_registros(data_json: dict) -> list:
        registros = data_json.get("records", [])

        if not registros:
            registros = data_json.get("result", {}).get("records", [])

        return registros


# ============================================================
# ESCRITOR CSV
# ============================================================

class CSVRawWriter:
    def __init__(self, ruta_salida: str):
        self.ruta_salida = ruta_salida
        self.es_primer_bloque = True

    def reiniciar_archivo(self):
        if os.path.exists(self.ruta_salida):
            os.remove(self.ruta_salida)
            print("Archivo previo eliminado. Iniciando nueva descarga.")

    def guardar_bloque(self, registros: list):
        if not registros:
            return

        df = pd.DataFrame(registros)

        df.to_csv(
            self.ruta_salida,
            mode="a",
            index=False,
            header=self.es_primer_bloque,
            encoding="utf-8-sig"
        )

        self.es_primer_bloque = False


# ============================================================
# EXTRACTOR PRINCIPAL
# ============================================================

class MEFExtractor:
    def __init__(self, config: MEFConfig, cliente_api: MEFAPIClient, escritor_csv: CSVRawWriter):
        self.config = config
        self.cliente_api = cliente_api
        self.escritor_csv = escritor_csv
        self.total_guardado = 0

    def calcular_registros_a_guardar(self, registros: list) -> list:
        registros_restantes = self.config.meta_registros - self.total_guardado

        if len(registros) > registros_restantes:
            return registros[:registros_restantes]

        return registros

    def mostrar_progreso_real(self):
        porcentaje = int((self.total_guardado / self.config.meta_registros) * 100)
        porcentaje = min(porcentaje, 100)

        ancho_barra = 30
        progreso = int((porcentaje / 100) * ancho_barra)
        barra = "█" * progreso + "░" * (ancho_barra - progreso)

        print(f"Progreso real: [{barra}] {porcentaje}%")

    def ejecutar(self):
        offset = 0
        pagina_actual = 1

        self.escritor_csv.reiniciar_archivo()

        loader = ConsoleLoader(duracion=self.config.duracion_carga)
        loader.mostrar("Cargando extractor MEF")

        print("Iniciando extracción incremental desde la API del MEF...")

        while self.total_guardado < self.config.meta_registros:
            print(f"\nConsultando bloque {pagina_actual} | Offset: {offset}")

            try:
                data_json = self.cliente_api.solicitar_bloque(offset)
                registros = self.cliente_api.extraer_registros(data_json)

                if not registros:
                    print("No hay más registros disponibles en el servidor.")
                    break

                registros = self.calcular_registros_a_guardar(registros)

                self.escritor_csv.guardar_bloque(registros)

                self.total_guardado += len(registros)

                print(f"Guardados en este bloque: {len(registros)}")
                print(f"Total acumulado: {self.total_guardado}")

                self.mostrar_progreso_real()

                if self.total_guardado >= self.config.meta_registros:
                    print("Meta de 100,000 registros alcanzada.")
                    break

                if len(registros) < self.config.limite_por_bloque:
                    print("Último bloque recibido. No hay más datos.")
                    break

                offset += self.config.limite_por_bloque
                pagina_actual += 1

            except Exception as error:
                print(f"Error crítico en el bloque {pagina_actual}: {error}")
                break

        print("\nProceso finalizado.")
        print(f"Archivo generado: {self.escritor_csv.ruta_salida}")


# ============================================================
# EJECUCIÓN
# ============================================================

if __name__ == "__main__":

    ID_RECURSO = "a50cf1dc-1655-446d-95a3-de6d5351dc8c"

    try:
        carpeta_script = Path(__file__).resolve().parent
    except NameError:
        carpeta_script = Path.cwd()

    ruta_archivo = carpeta_script / "gasto_publico_raw_2024.csv"

    config = MEFConfig(
        resource_id=ID_RECURSO,
        nombre_archivo="gasto_publico_raw_2024.csv",
        limite_por_bloque=32000,
        meta_registros=100000,
        duracion_carga=6
    )

    cliente_api = MEFAPIClient(config)
    escritor_csv = CSVRawWriter(str(ruta_archivo))
    extractor = MEFExtractor(config, cliente_api, escritor_csv)

    extractor.ejecutar()
