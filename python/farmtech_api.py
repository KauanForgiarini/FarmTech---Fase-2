"""
============================================================
 FarmTech Solutions - Integração Meteorológica
 Fase 2 - FIAP Inteligência Artificial
 Aluno: Kauan Maciel Forgiarini | RM 574005
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
CIDADE       = "Santa Maria - RS"
PORTA_SERIAL = "COM3"
BAUD_RATE    = 115200
CSV_OUTPUT   = "farmtech_historico.csv"

LAT = -29.6842
LON = -53.8069

UMIDADE_MINIMA  = 60.0
UMIDADE_MAXIMA  = 80.0
PH_MINIMO       = 5.0
PH_MAXIMO       = 7.5
CHUVA_LIMIAR_MM = 1.0

WMO_DESCRICAO = {
    0: "Ceu limpo", 1: "Principalmente limpo", 2: "Parcialmente nublado",
    3: "Nublado", 45: "Nevoa", 48: "Nevoa com geada",
    51: "Chuvisco leve", 53: "Chuvisco moderado", 55: "Chuvisco intenso",
    61: "Chuva leve", 63: "Chuva moderada", 65: "Chuva intensa",
    80: "Pancadas leves", 81: "Pancadas moderadas", 82: "Pancadas intensas",
    95: "Tempestade", 96: "Tempestade com granizo", 99: "Tempestade intensa"
}


# ============================================================
# MÓDULO 1: API Open-Meteo (gratuita, sem chave)
# ============================================================
def obter_previsao_chuva():
    url = (
        f"https://api.open-meteo.com/v1/forecast"
        f"?latitude={LAT}&longitude={LON}"
        f"&hourly=precipitation,weathercode"
        f"&forecast_days=1&timezone=America%2FSao_Paulo"
    )
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        dados = response.json()

        precipitacoes = dados["hourly"]["precipitation"]
        wcodes        = dados["hourly"]["weathercode"]

        volume_mm = float(precipitacoes[0]) if precipitacoes else 0.0
        wcode     = int(wcodes[0])          if wcodes        else 0
        descricao = WMO_DESCRICAO.get(wcode, f"Codigo {wcode}")

        return {
            "chuva_prevista": volume_mm >= CHUVA_LIMIAR_MM,
            "volume_mm":      volume_mm,
            "descricao":      descricao,
            "cidade":         CIDADE,
            "sucesso":        True
        }
    except requests.exceptions.ConnectionError:
        print("[AVISO] Sem conexao. Assumindo: sem chuva.")
        return {"chuva_prevista": False, "volume_mm": 0.0, "descricao": "Offline", "cidade": CIDADE, "sucesso": False}
    except Exception as e:
        print(f"[ERRO API] {e}")
        return {"chuva_prevista": False, "volume_mm": 0.0, "descricao": "Erro", "cidade": CIDADE, "sucesso": False}


# ============================================================
# MÓDULO 2: Decisão de Irrigação para SOJA
# ============================================================
def decidir_irrigacao(n, p, k, ph, umidade, temperatura, chuva_prevista):
    if chuva_prevista:
        return False, "Chuva prevista - irrigacao suspensa"
    if umidade >= UMIDADE_MAXIMA:
        return False, f"Solo saturado ({umidade:.1f}% >= {UMIDADE_MAXIMA}%)"
    if ph < PH_MINIMO or ph > PH_MAXIMO:
        return False, f"pH {ph:.2f} fora do ideal para soja ({PH_MINIMO}-{PH_MAXIMO})"
    if umidade < UMIDADE_MINIMA and (p or k):
        return True, f"Umidade baixa ({umidade:.1f}%) com nutrientes - IRRIGAR"
    if umidade >= UMIDADE_MINIMA:
        return False, f"Umidade adequada ({umidade:.1f}%) - sem necessidade"
    return False, "Nutrientes insuficientes (P e K ausentes)"


# ============================================================
# MÓDULO 3: CSV
# ============================================================
def inicializar_csv():
    if not os.path.exists(CSV_OUTPUT):
        with open(CSV_OUTPUT, "w", newline="", encoding="utf-8") as f:
            csv.writer(f).writerow([
                "timestamp","N","P","K","pH","umidade_%","temperatura_C",
                "chuva_prevista","volume_chuva_mm","condicao_clima","bomba_ativa","motivo"
            ])
        print(f"[CSV] Arquivo '{CSV_OUTPUT}' criado.")

def salvar_leitura(r):
    with open(CSV_OUTPUT, "a", newline="", encoding="utf-8") as f:
        csv.writer(f).writerow([
            r["timestamp"], int(r["N"]), int(r["P"]), int(r["K"]),
            round(r["ph"],2), round(r["umidade"],1), round(r["temperatura"],1),
            int(r["chuva_prevista"]), round(r["volume_mm"],2),
            r["condicao"], int(r["bomba_ativa"]), r["motivo"]
        ])


# ============================================================
# MÓDULO 4: Dashboard
# ============================================================
def exibir_dashboard(r, previsao):
    os.system("cls" if os.name == "nt" else "clear")
    sep = "=" * 60
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
    print(f"     Alerta   : {'*** CHUVA PREVISTA ***' if previsao['chuva_prevista'] else 'Sem chuva'}")
    print()
    print("  SOLO (ESP32 / Sensores)")
    print(f"     Nitrogenio : {'Presente' if r['N'] else 'Ausente'}")
    print(f"     Fosforo    : {'Presente' if r['P'] else 'Ausente'}")
    print(f"     Potassio   : {'Presente' if r['K'] else 'Ausente'}")
    print(f"     pH         : {r['ph']:.2f}  [{'Ideal' if PH_MINIMO <= r['ph'] <= PH_MAXIMO else 'FORA DO IDEAL'}]")
    umi_s = "Baixa" if r['umidade'] < UMIDADE_MINIMA else ("Adequada" if r['umidade'] < UMIDADE_MAXIMA else "Alta/Saturada")
    print(f"     Umidade    : {r['umidade']:.1f}%  [{umi_s}]")
    print(f"     Temperatura: {r['temperatura']:.1f}C")
    print()
    print("  DECISAO DE IRRIGACAO")
    print(f"     Status : {'BOMBA LIGADA - IRRIGANDO' if r['bomba_ativa'] else 'BOMBA DESLIGADA'}")
    print(f"     Motivo : {r['motivo']}")
    print(sep)
    print("  Pressione Ctrl+C para encerrar.")
    print(sep)


# ============================================================
# MÓDULO 5: Simulação ESP32
# ============================================================
def simular_leitura_esp32(iteracao):
    cenarios = [
        (True,  True,  True,  6.5, 45.0, 28.0),
        (True,  False, True,  6.2, 75.0, 26.0),
        (False, True,  False, 4.5, 40.0, 30.0),
        (True,  True,  True,  7.0, 55.0, 27.5),
        (False, False, False, 6.8, 85.0, 25.0),
    ]
    n, p, k, ph, umidade, temp = cenarios[iteracao % len(cenarios)]
    return {"N": n, "P": p, "K": k, "ph": ph, "umidade": umidade, "temperatura": temp}

def tentar_ler_serial():
    try:
        import serial
        ser = serial.Serial(PORTA_SERIAL, BAUD_RATE, timeout=2)
        print(f"[SERIAL] Conectado em {PORTA_SERIAL}")
        return ser
    except Exception as e:
        print(f"[AVISO] Serial indisponivel ({e}). Modo SIMULACAO ativado.")
        return None

def parsear_csv_serial(linha):
    try:
        if not linha.startswith("CSV,"):
            return None
        p = linha.strip().split(",")
        if len(p) < 9:
            return None
        return {"N": bool(int(p[1])), "P": bool(int(p[2])), "K": bool(int(p[3])),
                "ph": float(p[4]), "umidade": float(p[5]), "temperatura": float(p[6])}
    except Exception:
        return None


# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 60)
    print("  FarmTech Solutions - Sistema de Irrigacao - SOJA")
    print("  Kauan Maciel Forgiarini | RM 574005")
    print("=" * 60)

    inicializar_csv()
    serial_conn = tentar_ler_serial()
    iteracao    = 0
    ultima_api  = 0
    previsao    = {"chuva_prevista": False, "volume_mm": 0.0,
                   "descricao": "Aguardando consulta...", "cidade": CIDADE, "sucesso": False}

    try:
        while True:
            agora = time.time()

            if agora - ultima_api >= 300:
                print("[API] Consultando Open-Meteo...")
                previsao   = obter_previsao_chuva()
                ultima_api = agora
                if previsao["sucesso"]:
                    print(f"[API] OK - {previsao['descricao']} | Chuva: {previsao['volume_mm']} mm")

            dados_solo = None
            if serial_conn:
                try:
                    serial_conn.write(b"1" if previsao["chuva_prevista"] else b"0")
                    for _ in range(20):
                        linha = serial_conn.readline().decode("utf-8", errors="ignore")
                        dados_solo = parsear_csv_serial(linha)
                        if dados_solo:
                            break
                except Exception as e:
                    print(f"[SERIAL] Erro: {e}")

            if not dados_solo:
                dados_solo = simular_leitura_esp32(iteracao)

            irrigar, motivo = decidir_irrigacao(
                dados_solo["N"], dados_solo["P"], dados_solo["K"],
                dados_solo["ph"], dados_solo["umidade"],
                dados_solo["temperatura"], previsao["chuva_prevista"]
            )

            registro = {
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                **dados_solo,
                "chuva_prevista": previsao["chuva_prevista"],
                "volume_mm":      previsao["volume_mm"],
                "condicao":       previsao["descricao"],
                "bomba_ativa":    irrigar,
                "motivo":         motivo
            }

            salvar_leitura(registro)
            exibir_dashboard(registro, previsao)

            iteracao += 1
            time.sleep(10)

    except KeyboardInterrupt:
        print("\n[SISTEMA] Encerrado.")
        if serial_conn:
            serial_conn.close()

if __name__ == "__main__":
    main()
