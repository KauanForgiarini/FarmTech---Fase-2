"""
============================================================
 FarmTech Solutions - Integração Meteorológica
 Fase 2 - FIAP Inteligência Artificial
 Aluno: Kauan Maciel Forgiarini | RM: 574005 
 Aluno: Wagner Adriano De Souza Silva Junio | RM: RM569431 
 Aluno: Thiago Lucas da Costa Bessa | RM: RM570367 
 Aluna: Beatriz de Oliveira Ossola Ribeiro | RM: RM570190
 Aluno: Willian Kauê Tobias do Carmo | RM: 570038
============================================================
 API usada: Open-Meteo (https://open-meteo.com)
   - 100% gratuita, sem cadastro, sem chave de API
============================================================
"""

import requests
import csv
import os
import time
from datetime import datetime

# ============================================================
# CONFIGURAÇÃO
# ============================================================
CIDADE        = "Santa Maria - RS"
PORTA_SERIAL  = "COM3"          # Altere para /dev/ttyUSB0 no Linux/Mac
BAUD_RATE     = 115200
CSV_OUTPUT    = "farmtech_historico.csv"

# Coordenadas de Santa Maria - RS
LAT = -29.6842
LON = -53.8069

# Limiares agrônomicos para SOJA
UMIDADE_MINIMA   = 60.0
UMIDADE_MAXIMA   = 80.0
PH_MINIMO        = 5.0
PH_MAXIMO        = 7.5
CHUVA_LIMIAR_MM  = 1.0   # mm/h para considerar chuva relevante

# Dicionário de condições climáticas (códigos WMO)
WMO_DESCRICAO = {
    0:  "Ceu limpo",
    1:  "Principalmente limpo",
    2:  "Parcialmente nublado",
    3:  "Nublado",
    45: "Nevoa",
    48: "Nevoa com geada",
    51: "Chuvisco leve",
    53: "Chuvisco moderado",
    55: "Chuvisco intenso",
    61: "Chuva leve",
    63: "Chuva moderada",
    65: "Chuva intensa",
    80: "Pancadas leves",
    81: "Pancadas moderadas",
    82: "Pancadas intensas",
    95: "Tempestade",
    96: "Tempestade com granizo",
    99: "Tempestade intensa",
}


# ============================================================
# MÓDULO 1: API Open-Meteo (gratuita, sem chave)
# ============================================================
def obter_previsao_chuva():
    """
    Consulta a API Open-Meteo para obter precipitação e condição
    climática da próxima hora. Retorna dict com resultado.
    """
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={LAT}&longitude={LON}"
        "&hourly=precipitation,weathercode"
        "&forecast_days=1&timezone=America%2FSao_Paulo"
    )
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        dados = response.json()

        precipitacoes = dados["hourly"]["precipitation"]
        wcodes        = dados["hourly"]["weathercode"]

        volume_mm = float(precipitacoes[0]) if precipitacoes else 0.0
        wcode     = int(wcodes[0])          if wcodes        else 0
        descricao = WMO_DESCRICAO.get(wcode, f"Codigo WMO {wcode}")

        return {
            "chuva_prevista": volume_mm >= CHUVA_LIMIAR_MM,
            "volume_mm":      volume_mm,
            "descricao":      descricao,
            "cidade":         CIDADE,
            "sucesso":        True,
        }
    except requests.exceptions.ConnectionError:
        print("[AVISO] Sem conexao com a internet. Assumindo: sem chuva.")
        return {
            "chuva_prevista": False, "volume_mm": 0.0,
            "descricao": "Offline", "cidade": CIDADE, "sucesso": False,
        }
    except requests.exceptions.Timeout:
        print("[AVISO] Timeout na API. Assumindo: sem chuva.")
        return {
            "chuva_prevista": False, "volume_mm": 0.0,
            "descricao": "Timeout", "cidade": CIDADE, "sucesso": False,
        }
    except Exception as e:
        print(f"[ERRO API] {e}")
        return {
            "chuva_prevista": False, "volume_mm": 0.0,
            "descricao": "Erro", "cidade": CIDADE, "sucesso": False,
        }


# ============================================================
# MÓDULO 2: Lógica de Decisão de Irrigação para SOJA
# ============================================================
def decidir_irrigacao(n, p, k, ph, umidade, temperatura, chuva_prevista):
    """
    Replica exatamente a lógica do código C/C++ (deveIrrigar).
    Retorna (bool irrigar, str motivo).
    """
    if chuva_prevista:
        return False, "Chuva prevista - irrigacao suspensa"
    if umidade >= UMIDADE_MAXIMA:
        return False, f"Solo saturado ({umidade:.1f}% >= {UMIDADE_MAXIMA}%)"
    if ph < PH_MINIMO or ph > PH_MAXIMO:
        return False, f"pH {ph:.2f} fora do ideal para soja ({PH_MINIMO}–{PH_MAXIMO})"
    if umidade >= UMIDADE_MINIMA:
        return False, f"Umidade adequada ({umidade:.1f}%) - sem necessidade"
    # umidade < 60%
    if p or k:
        return True, f"Umidade baixa ({umidade:.1f}%) com nutrientes - IRRIGAR"
    return False, "Nutrientes insuficientes (P e K ausentes)"


# ============================================================
# MÓDULO 3: Persistência em CSV
# ============================================================
def inicializar_csv():
    """Cria o arquivo CSV com cabeçalho se ainda não existir."""
    if not os.path.exists(CSV_OUTPUT):
        with open(CSV_OUTPUT, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow([
                "timestamp", "N", "P", "K", "pH", "umidade_%",
                "temperatura_C", "chuva_prevista", "volume_chuva_mm",
                "condicao_clima", "bomba_ativa", "motivo",
            ])
        print(f"[CSV] Arquivo '{CSV_OUTPUT}' criado.")


def salvar_leitura(r):
    """Appenda uma linha de leitura no CSV."""
    with open(CSV_OUTPUT, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            r["timestamp"],
            int(r["N"]), int(r["P"]), int(r["K"]),
            round(r["ph"], 2),
            round(r["umidade"], 1),
            round(r["temperatura"], 1),
            int(r["chuva_prevista"]),
            round(r["volume_mm"], 2),
            r["condicao"],
            int(r["bomba_ativa"]),
            r["motivo"],
        ])


# ============================================================
# MÓDULO 4: Dashboard no Terminal
# ============================================================
def exibir_dashboard(r, previsao):
    os.system("cls" if os.name == "nt" else "clear")
    sep = "=" * 62
    print(sep)
    print("   FarmTech Solutions - Irrigacao Inteligente - SOJA")
    print("   Kauan Maciel Forgiarini | RM 574005")
    print(sep)
    print(f"  {r['timestamp']}")
    print()
    print("  CLIMA (Open-Meteo - Dados Reais, sem chave de API)")
    print(f"     Cidade   : {previsao['cidade']}")
    print(f"     Condicao : {previsao['descricao']}")
    print(f"     Chuva 1h : {previsao['volume_mm']:.1f} mm")
    alerta_chuva = "*** CHUVA PREVISTA ***" if previsao["chuva_prevista"] else "Sem chuva prevista"
    print(f"     Alerta   : {alerta_chuva}")
    print()
    print("  SOLO (ESP32 / Sensores)")
    print(f"     Nitrogenio : {'Presente' if r['N'] else 'Ausente'}")
    print(f"     Fosforo    : {'Presente' if r['P'] else 'Ausente'}")
    print(f"     Potassio   : {'Presente' if r['K'] else 'Ausente'}")
    ph_status = "Ideal" if PH_MINIMO <= r["ph"] <= PH_MAXIMO else "FORA DO IDEAL"
    print(f"     pH         : {r['ph']:.2f}  [{ph_status}]")
    if r["umidade"] < UMIDADE_MINIMA:
        umi_s = "Baixa"
    elif r["umidade"] < UMIDADE_MAXIMA:
        umi_s = "Adequada"
    else:
        umi_s = "Alta/Saturada"
    print(f"     Umidade    : {r['umidade']:.1f}%  [{umi_s}]")
    print(f"     Temperatura: {r['temperatura']:.1f}C")
    print()
    print("  DECISAO DE IRRIGACAO")
    status_bomba = "BOMBA LIGADA - IRRIGANDO" if r["bomba_ativa"] else "BOMBA DESLIGADA"
    print(f"     Status : {status_bomba}")
    print(f"     Motivo : {r['motivo']}")
    print(sep)
    print("  Pressione Ctrl+C para encerrar.")
    print(sep)


# ============================================================
# MÓDULO 5: Simulação do ESP32 (modo sem Serial)
# ============================================================
# Cenários rotativos que cobrem os diferentes casos de irrigação
_CENARIOS = [
    (True,  True,  True,  6.5, 45.0, 28.0),   # irrigar
    (True,  False, True,  6.2, 75.0, 26.0),   # umidade ok
    (False, True,  False, 4.5, 40.0, 30.0),   # pH fora
    (True,  True,  True,  7.0, 55.0, 27.5),   # irrigar
    (False, False, False, 6.8, 85.0, 25.0),   # saturado
]

def simular_leitura_esp32(iteracao):
    n, p, k, ph, umidade, temp = _CENARIOS[iteracao % len(_CENARIOS)]
    return {"N": n, "P": p, "K": k, "ph": ph, "umidade": umidade, "temperatura": temp}


def tentar_ler_serial():
    """Tenta abrir porta Serial; retorna objeto serial ou None."""
    try:
        import serial
        ser = serial.Serial(PORTA_SERIAL, BAUD_RATE, timeout=2)
        print(f"[SERIAL] Conectado em {PORTA_SERIAL} @ {BAUD_RATE} baud")
        return ser
    except ImportError:
        print("[AVISO] pyserial nao instalado. Modo SIMULACAO ativado.")
        return None
    except Exception as e:
        print(f"[AVISO] Serial indisponivel ({e}). Modo SIMULACAO ativado.")
        return None


def parsear_csv_serial(linha):
    """
    Parseia linha CSV enviada pelo ESP32.
    Formato: CSV,N,P,K,pH,Umidade,Temp,Chuva,Bomba
    """
    try:
        if not linha.startswith("CSV,"):
            return None
        partes = linha.strip().split(",")
        if len(partes) < 9:
            return None
        return {
            "N":           bool(int(partes[1])),
            "P":           bool(int(partes[2])),
            "K":           bool(int(partes[3])),
            "ph":          float(partes[4]),
            "umidade":     float(partes[5]),
            "temperatura": float(partes[6]),
        }
    except Exception:
        return None


# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 62)
    print("  FarmTech Solutions - Sistema de Irrigacao - SOJA")
    print("  Kauan Maciel Forgiarini | RM 574005")
    print("=" * 62)

    inicializar_csv()
    serial_conn = tentar_ler_serial()
    iteracao    = 0
    ultima_api  = 0  # timestamp da última consulta à API

    previsao = {
        "chuva_prevista": False,
        "volume_mm":      0.0,
        "descricao":      "Aguardando consulta...",
        "cidade":         CIDADE,
        "sucesso":        False,
    }

    try:
        while True:
            agora = time.time()

            # Consulta API a cada 5 minutos (300 s)
            if agora - ultima_api >= 300:
                print("[API] Consultando Open-Meteo...")
                previsao   = obter_previsao_chuva()
                ultima_api = agora
                if previsao["sucesso"]:
                    print(f"[API] OK - {previsao['descricao']} | {previsao['volume_mm']} mm")

            # Tenta ler do ESP32 via Serial
            dados_solo = None
            if serial_conn:
                try:
                    # Envia previsão de chuva ao ESP32
                    serial_conn.write(b"1" if previsao["chuva_prevista"] else b"0")
                    # Tenta capturar linha CSV
                    for _ in range(20):
                        linha = serial_conn.readline().decode("utf-8", errors="ignore")
                        dados_solo = parsear_csv_serial(linha)
                        if dados_solo:
                            break
                except Exception as e:
                    print(f"[SERIAL] Erro de leitura: {e}")

            # Fallback: simulação local
            if not dados_solo:
                dados_solo = simular_leitura_esp32(iteracao)

            # Decisão de irrigação (mesma lógica do C/C++)
            irrigar, motivo = decidir_irrigacao(
                dados_solo["N"],    dados_solo["P"],    dados_solo["K"],
                dados_solo["ph"],   dados_solo["umidade"],
                dados_solo["temperatura"], previsao["chuva_prevista"],
            )

            registro = {
                "timestamp":      datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                **dados_solo,
                "chuva_prevista": previsao["chuva_prevista"],
                "volume_mm":      previsao["volume_mm"],
                "condicao":       previsao["descricao"],
                "bomba_ativa":    irrigar,
                "motivo":         motivo,
            }

            salvar_leitura(registro)
            exibir_dashboard(registro, previsao)

            iteracao += 1
            time.sleep(10)

    except KeyboardInterrupt:
        print("\n[SISTEMA] Encerrado pelo usuario.")
    finally:
        if serial_conn:
            serial_conn.close()
            print("[SERIAL] Conexao encerrada.")


if __name__ == "__main__":
    main()
