# 🌱 FarmTech Solutions — Sistema de Irrigação Inteligente (Fase 2)

**FIAP — Inteligência Artificial**  
**Aluno:** Kauan Maciel Forgiarini  
**RM:** 574005  

---

## 📋 Sumário

1. [Visão Geral do Projeto](#1-visão-geral-do-projeto)
2. [Cultura Agrícola Escolhida — Soja](#2-cultura-agrícola-escolhida--soja)
3. [Componentes e Mapeamento de Pinos](#3-componentes-e-mapeamento-de-pinos)
4. [Diagrama do Circuito (Wokwi)](#4-diagrama-do-circuito-wokwi)
5. [Lógica de Irrigação](#5-lógica-de-irrigação)
6. [Código ESP32 — C/C++](#6-código-esp32--cc)
7. [Integração Python + OpenWeather API (Ir Além 1)](#7-integração-python--openweather-api-ir-além-1)
8. [Análise Estatística em R (Ir Além 2)](#8-análise-estatística-em-r-ir-além-2)
9. [Como Executar o Projeto](#9-como-executar-o-projeto)
10. [Estrutura de Pastas](#10-estrutura-de-pastas)
11. [Referências](#11-referências)
12. [Vídeo Demonstrativo](#12-vídeo-demonstrativo)

---

## 1. Visão Geral do Projeto

Este projeto implementa um **sistema de irrigação automatizado e inteligente** para a startup **FarmTech Solutions**, desenvolvido como parte da Fase 2 do PBL da FIAP.

O sistema utiliza um microcontrolador **ESP32** simulado na plataforma [Wokwi.com](https://wokwi.com), monitorando em tempo real:

- Níveis dos nutrientes **N (Nitrogênio)**, **P (Fósforo)** e **K (Potássio)** — via botões verdes
- **pH do solo** — simulado via sensor LDR
- **Umidade do solo** — simulado via sensor DHT22
- **Previsão meteorológica** — integrada via Python com a API OpenWeatherMap

Com base nesses dados, o sistema decide automaticamente quando acionar a **bomba d'água** (relé azul), otimizando o uso de recursos hídricos na lavoura.

---

## 2. Cultura Agrícola Escolhida — Soja

A soja foi escolhida por ser a principal cultura do Rio Grande do Sul e uma das mais importantes do agronegócio brasileiro.

### Necessidades ideais da soja:

| Parâmetro      | Faixa Ideal       | Fonte de dados no circuito |
|----------------|-------------------|----------------------------|
| pH do solo     | 5.5 – 7.0         | Sensor LDR (analógico)     |
| Umidade do solo| 60% – 80%         | DHT22                      |
| Nitrogênio (N) | Fixação biológica | Botão verde (GPIO 12)      |
| Fósforo (P)    | Essencial          | Botão verde (GPIO 13)      |
| Potássio (K)   | Essencial          | Botão verde (GPIO 14)      |

> **Referência:** Embrapa Soja — *Tecnologias de Produção de Soja* (2023)

---

## 3. Componentes e Mapeamento de Pinos

| Componente              | Tipo              | GPIO (ESP32) | Descrição                                        |
|-------------------------|-------------------|:------------:|--------------------------------------------------|
| Botão N (Nitrogênio)    | Push button verde | GPIO 12      | Nível de N: HIGH=ausente / LOW=presente          |
| Botão P (Fósforo)       | Push button verde | GPIO 13      | Nível de P: HIGH=ausente / LOW=presente          |
| Botão K (Potássio)      | Push button verde | GPIO 14      | Nível de K: HIGH=ausente / LOW=presente          |
| Sensor LDR              | Fotoresistor      | GPIO 34      | pH simulado — leitura analógica 0–4095 → 0–14    |
| Sensor DHT22            | Temp. e umidade   | GPIO 15      | Umidade do solo simulada (leitura do ar)         |
| Relé azul               | Relay module      | GPIO 26      | Aciona bomba d'água (irrigação)                  |
| LED Verde               | LED               | GPIO 2       | Indica irrigação ATIVA                           |
| LED Vermelho            | LED               | GPIO 4       | Indica irrigação INATIVA                         |
| Resistor 220Ω (x2)      | Resistor          | —            | Proteção dos LEDs                                |

---

## 4. Diagrama do Circuito (Wokwi)

### Imagem do circuito completo:

> ⚠️ **Nota para o avaliador:** As imagens abaixo representam o esquema de conexões do circuito montado no Wokwi.com. O arquivo `diagram.json` na pasta `esp32/` pode ser importado diretamente no Wokwi para replicar o circuito.

```
                        ┌─────────────────────────────────────┐
                        │           ESP32 DevKit V1            │
                        │                                      │
  [DHT22] ─────── SDA ─┤ GPIO 15                              │
                        │                                      │
  [LDR]   ─────── AO ──┤ GPIO 34      GPIO 26 ──────── [RELÉ AZUL]
                        │                                      │
  [BTN N] ─────────────┤ GPIO 12      GPIO 2  ──[220Ω]── [LED VERDE]
  [BTN P] ─────────────┤ GPIO 13                              │
  [BTN K] ─────────────┤ GPIO 14      GPIO 4  ──[220Ω]── [LED VERMELHO]
                        │                                      │
  [GND] ───────────────┤ GND                                  │
  [3V3] ───────────────┤ 3V3                                  │
                        └─────────────────────────────────────┘
```

### Mapa de cores dos fios (Wokwi):
- 🔴 **Vermelho** → VCC / 3.3V
- ⚫ **Preto** → GND
- 🟢 **Verde** → Dados DHT22 e LED verde
- 🟠 **Laranja** → Saída analógica LDR
- 🟡 **Amarelo** → Botões NPK
- 🟣 **Roxo** → Sinal do relé
- 🔵 **Azul** → Referência do relé (bomba)

---

## 5. Lógica de Irrigação

### Fluxograma de decisão:

```
                        INÍCIO
                          │
                    ┌─────▼─────┐
                    │ Chuva      │
                    │ prevista?  │
                    └─────┬─────┘
               SIM ◄──────┴──────► NÃO
                │                    │
        NÃO IRRIGAR          ┌───────▼───────┐
                             │  Umidade ≥ 80%?│
                             └───────┬───────┘
                        SIM ◄────────┴────────► NÃO
                         │                       │
                 NÃO IRRIGAR             ┌────────▼────────┐
                 (Solo saturado)         │ pH entre 5.0     │
                                         │ e 7.5?           │
                                         └────────┬────────┘
                                    NÃO ◄─────────┴─────────► SIM
                                     │                          │
                             NÃO IRRIGAR                ┌───────▼───────┐
                             (ALERTAR pH)               │ Umidade < 60%  │
                                                        │ E (P ou K)?    │
                                                        └───────┬───────┘
                                                  NÃO ◄─────────┴──────► SIM
                                                   │                       │
                                           NÃO IRRIGAR               ✅ IRRIGAR
                                                                  (Liga relé/bomba)
```

### Tabela de decisão resumida:

| Chuva | Umidade | pH        | P ou K | Decisão          |
|:-----:|:-------:|:---------:|:------:|------------------|
| Sim   | qualquer| qualquer  | qualquer| ❌ Não irrigar   |
| Não   | ≥ 80%   | qualquer  | qualquer| ❌ Solo saturado |
| Não   | qualquer| < 5.0 ou > 7.5 | qualquer | ❌ Alertar pH |
| Não   | < 60%   | 5.0–7.5   | ausentes | ❌ Sem nutrientes|
| Não   | < 60%   | 5.0–7.5   | presente | ✅ **IRRIGAR**   |
| Não   | 60–79%  | qualquer  | qualquer| ❌ Umidade ok   |

---

## 6. Código ESP32 — C/C++

O código principal está em `esp32/farmtech_irrigacao.ino`.

### Principais funções:

| Função           | Descrição                                                   |
|------------------|-------------------------------------------------------------|
| `setup()`        | Inicializa pinos, serial e DHT22                            |
| `loop()`         | Lê sensores, processa lógica e aciona atuadores a cada 3s   |
| `ldrParaPH()`    | Converte leitura bruta 0–4095 do LDR para pH 0.0–14.0      |
| `deveIrrigar()`  | Aplica a lógica de decisão para soja                        |
| `lerSerial()`    | Recebe dado de previsão de chuva enviado pelo Python        |
| `exibirStatus()` | Exibe dados no Monitor Serial (formato legível + CSV)       |

### Saída serial (exemplo):
```
--------------------------------------------------
Cultura: SOJA | Hora: 12
NPK -> N:SIM | P:NAO | K:SIM
pH (LDR): 6.23 [IDEAL PARA SOJA]
Umidade Solo: 52.0% | Temperatura: 27.5°C
Chuva Prevista: NAO
Bomba d'agua (rele): LIGADA
CSV,1,0,1,6.23,52.0,27.5,0,1
--------------------------------------------------
```

---

## 7. Integração Python + OpenWeather API (Ir Além 1)

Script: `python/farmtech_api.py`

### Funcionalidades:

1. **Consulta automática** à API [OpenWeatherMap](https://openweathermap.org/api) a cada 5 minutos
2. **Leitura de dados via Serial** (pyserial) — parseia linhas CSV enviadas pelo ESP32
3. **Modo simulação** — quando sem hardware ou Serial indisponível, gera dados para teste
4. **Envio de decisão** ao ESP32 via Serial ('0' = sem chuva, '1' = chuva prevista)
5. **Persistência** — grava histórico completo em `farmtech_historico.csv`
6. **Dashboard** — exibe painel visual atualizado no terminal a cada leitura

### Como configurar a API:

```bash
# 1. Crie conta gratuita em https://openweathermap.org
# 2. Gere sua API Key
# 3. Edite farmtech_api.py:
API_KEY = "sua_chave_aqui"
CIDADE  = "Santa Maria,BR"   # ou sua cidade
```

### Instalação:

```bash
cd python/
pip install -r requirements.txt
python farmtech_api.py
```

### Exemplo de dashboard no terminal:

```
============================================================
   🌱 FARMTECH SOLUTIONS - Irrigação Inteligente - SOJA
   Aluno: Kauan Maciel Forgiarini | RM 574005
============================================================
  ⏰ 2025-08-22 14:35:10

  📍 CLIMA (OpenWeather)
     Cidade     : Santa Maria
     Condição   : Parcialmente nublado
     Chuva 3h   : 0.0 mm
     Alerta     : ☀️  Sem chuva

  🧪 SOLO (ESP32 / Sensores)
     Nitrogênio : ✅ Presente
     Fósforo    : ✅ Presente
     Potássio   : ❌ Ausente
     pH         : 6.35  ✅ Ideal
     Umidade    : 52.0%  ⬇️  Baixa
     Temperatura: 28.5°C

  💧 DECISÃO DE IRRIGAÇÃO
     Status     : 🟢 BOMBA LIGADA - IRRIGANDO
     Motivo     : Umidade baixa (52.0%) com nutrientes disponíveis - IRRIGAR
============================================================
```

---

## 8. Análise Estatística em R (Ir Além 2)

Script: `r-analysis/farmtech_analise.R`

### O que o script faz:

1. **Carrega** o CSV gerado pelo Python (ou gera dados simulados se não existir)
2. **Estatísticas descritivas** — média, mediana, desvio padrão de pH, umidade e temperatura
3. **Análise de frequência** — proporção de ativações da bomba
4. **Gráficos** exportados em PNG:
   - Histograma de umidade por status da bomba
   - Scatter plot pH × umidade
   - Boxplot umidade por presença de Fósforo
   - Série temporal de umidade
5. **Regressão Logística** — modelo preditivo de ativação da bomba com métricas de acurácia
6. **Predição individual** — simulação de um novo cenário de campo

### Como executar:

```r
# No RStudio ou terminal R:
setwd("r-analysis/")
source("farmtech_analise.R")
```

### Exemplo de saída da regressão:

```
Registros para treino: 160
Registros para teste : 40

Acurácia : 94.2%
Sensibilidade (irrigar quando deve): 91.3%
Especificidade (não irrigar quando não deve): 96.7%
```

---

## 9. Como Executar o Projeto

### Passo 1 — Circuito no Wokwi

1. Acesse [wokwi.com](https://wokwi.com) e crie um novo projeto ESP32
2. Importe o arquivo `esp32/diagram.json` ou monte manualmente conforme o diagrama
3. Copie e cole o conteúdo de `esp32/farmtech_irrigacao.ino` no editor
4. Clique em **▶ Play** para iniciar a simulação
5. Abra o **Monitor Serial** (115200 baud) para ver as leituras

### Passo 2 — Testar sensores

| Ação                         | Efeito esperado                              |
|------------------------------|----------------------------------------------|
| Pressionar BTN P ou BTN K   | Nutrientes presentes                         |
| Diminuir luz no LDR          | pH cai (mais ácido)                          |
| Aumentar umidade no DHT22   | Umidade sobe (menos necessidade de irrigar)  |
| Digitar `1` no Serial        | Chuva prevista → bomba desliga               |
| Digitar `0` no Serial        | Sem chuva → lógica normal retomada           |

### Passo 3 — Script Python

```bash
pip install requests pyserial
cd python/
python farmtech_api.py
```

### Passo 4 — Análise R

```bash
Rscript r-analysis/farmtech_analise.R
# Os gráficos serão salvos em r-analysis/graficos/
```

---

## 10. Estrutura de Pastas

```
farmtech-fase2/
│
├── esp32/
│   ├── farmtech_irrigacao.ino    # Código principal ESP32 (C/C++)
│   └── diagram.json              # Diagrama Wokwi importável
│
├── python/
│   ├── farmtech_api.py           # Integração OpenWeather + Serial + CSV
│   └── requirements.txt          # Dependências Python
│
├── r-analysis/
│   ├── farmtech_analise.R        # Script de análise estatística
│   └── graficos/                 # Gráficos gerados (PNG)
│
├── docs/
│   └── images/                   # Capturas de tela do Wokwi
│
└── README.md                     # Este arquivo
```

---

## 11. Referências

- EMBRAPA. *Tecnologias de Produção de Soja — Região Central do Brasil 2023*. Disponível em: https://www.embrapa.br
- OpenWeatherMap API. Disponível em: https://openweathermap.org/api
- Wokwi ESP32 Simulator. Disponível em: https://wokwi.com
- ESP32 Arduino Reference. Disponível em: https://docs.espressif.com
- R Core Team. *R: A Language and Environment for Statistical Computing*. Vienna, 2024.
- FIAP. *Material de Aula — Inteligência Artificial, Fase 2*. 2025.

---

## 12. Vídeo Demonstrativo

> 🎥 Link do vídeo no YouTube (sem listagem): **[A ser inserido após gravação]**

O vídeo demonstra:
- Montagem do circuito no Wokwi
- Funcionamento dos sensores em tempo real
- Lógica de decisão da bomba sendo acionada
- Dashboard Python com integração da API OpenWeather
- Resultados da análise em R com os gráficos gerados

---

*Desenvolvido por Kauan Maciel Forgiarini — RM 574005 | FIAP IA — Fase 2 | 2025*
