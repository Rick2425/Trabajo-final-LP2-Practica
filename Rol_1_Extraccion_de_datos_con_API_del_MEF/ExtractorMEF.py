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
