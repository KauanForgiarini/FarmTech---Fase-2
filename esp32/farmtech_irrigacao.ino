/*
 * ============================================================
 *  FarmTech Solutions - Sistema de Irrigação Inteligente
 *  Fase 2 - FIAP Inteligência Artificial
 *  Aluno: Kauan Maciel Forgiarini | RM 574005
 * ============================================================
 *
 *  Cultura monitorada: SOJA
 *
 *  Mapeamento de sensores:
 *    - Botão N  (GPIO 12) -> Nível de Nitrogênio
 *    - Botão P  (GPIO 13) -> Nível de Fósforo
 *    - Botão K  (GPIO 14) -> Nível de Potássio
 *    - LDR      (GPIO 34) -> Simulação de pH (0–14 mapeado de 0–4095)
 *    - DHT22    (GPIO 15) -> Umidade do solo (leitura de umidade do ar)
 *    - Relé     (GPIO 26) -> Bomba d'água (irrigação)
 *    - LED Verde (GPIO 2) -> Irrigação ATIVA
 *    - LED Vermelho (GPIO 4) -> Irrigação INATIVA / Alerta
 *
 *  Lógica de irrigação para SOJA:
 *    Irrigar SE:
 *      1. Umidade < 60% (solo abaixo do ideal)
 *      2. pH entre 5.5 e 7.0 (ideal para soja)
 *      3. Pelo menos P ou K presente (nutrientes mínimos)
 *      4. Sem chuva prevista (dado via Serial do script Python)
 *
 *    NÃO irrigar SE:
 *      - Umidade >= 80% (solo já saturado)
 *      - pH < 5.0 ou > 7.5 (solo inadequado, alertar agricultor)
 *      - Chuva prevista nas próximas horas
 * ============================================================
 */

#include <DHT.h>

// -------- Pinos --------
#define PIN_BTN_N    12
#define PIN_BTN_P    13
#define PIN_BTN_K    14
#define PIN_LDR      34
#define PIN_DHT      15
#define PIN_RELAY    26
#define PIN_LED_ON   2
#define PIN_LED_OFF  4

// -------- Configuração DHT22 --------
#define DHTTYPE DHT22
DHT dht(PIN_DHT, DHTTYPE);

// -------- Variáveis globais --------
bool nitrogenio   = false;
bool fosforo      = false;
bool potassio     = false;
float phValor     = 0.0;
float umidade     = 0.0;
float temperatura = 0.0;
bool irrigando    = false;

// Dado recebido do Python via Serial (0=sem chuva, 1=chuva prevista)
int previsaoChuva = 0;

// -------- Protótipos --------
float ldrParaPH(int ldrRaw);
bool deveIrrigar();
void lerSerial();
void exibirStatus();

// ============================================================
void setup() {
  Serial.begin(115200);
  dht.begin();

  pinMode(PIN_BTN_N,   INPUT_PULLUP);
  pinMode(PIN_BTN_P,   INPUT_PULLUP);
  pinMode(PIN_BTN_K,   INPUT_PULLUP);
  pinMode(PIN_RELAY,   OUTPUT);
  pinMode(PIN_LED_ON,  OUTPUT);
  pinMode(PIN_LED_OFF, OUTPUT);

  digitalWrite(PIN_RELAY,  LOW);
  digitalWrite(PIN_LED_ON, LOW);
  digitalWrite(PIN_LED_OFF, HIGH);

  Serial.println("=== FarmTech Solutions - Irrigacao Inteligente ===");
  Serial.println("Cultura: SOJA");
  Serial.println("Aguardando leituras...");
  Serial.println("(Envie '0' = sem chuva | '1' = chuva prevista)");
  Serial.println("==================================================");
  delay(2000);
}

// ============================================================
void loop() {
  // 1. Ler botões NPK (LOW = pressionado com INPUT_PULLUP)
  nitrogenio = (digitalRead(PIN_BTN_N) == LOW);
  fosforo    = (digitalRead(PIN_BTN_P) == LOW);
  potassio   = (digitalRead(PIN_BTN_K) == LOW);

  // 2. Ler LDR e converter para pH
  int ldrRaw = analogRead(PIN_LDR);
  phValor = ldrParaPH(ldrRaw);

  // 3. Ler DHT22 (umidade = solo simulado)
  umidade     = dht.readHumidity();
  temperatura = dht.readTemperature();

  // Verificar falha de leitura
  if (isnan(umidade) || isnan(temperatura)) {
    Serial.println("[ERRO] Falha na leitura do DHT22!");
    delay(2000);
    return;
  }

  // 4. Verificar entrada Serial do Python
  lerSerial();

  // 5. Decidir irrigação
  irrigando = deveIrrigar();

  // 6. Acionar relé e LEDs
  if (irrigando) {
    digitalWrite(PIN_RELAY,   HIGH);
    digitalWrite(PIN_LED_ON,  HIGH);
    digitalWrite(PIN_LED_OFF, LOW);
  } else {
    digitalWrite(PIN_RELAY,   LOW);
    digitalWrite(PIN_LED_ON,  LOW);
    digitalWrite(PIN_LED_OFF, HIGH);
  }

  // 7. Exibir status no Monitor Serial
  exibirStatus();

  delay(3000); // Leitura a cada 3 segundos
}

// ============================================================
// Converte leitura bruta do LDR (0–4095) para pH (0.0–14.0)
// LDR muito iluminado -> valor alto -> pH alto (alcalino)
// LDR no escuro      -> valor baixo -> pH baixo (ácido)
// ============================================================
float ldrParaPH(int ldrRaw) {
  // Mapeia 0–4095 para 0.0–14.0
  return (float)ldrRaw * 14.0 / 4095.0;
}

// ============================================================
// Lógica de decisão de irrigação para SOJA
// Retorna true se deve irrigar
// ============================================================
bool deveIrrigar() {
  // Condição 1: chuva prevista -> não irrigar
  if (previsaoChuva == 1) {
    Serial.println("[DECISAO] Chuva prevista - Irrigacao suspensa.");
    return false;
  }

  // Condição 2: Solo saturado -> não irrigar
  if (umidade >= 80.0) {
    Serial.println("[DECISAO] Solo saturado (umidade >= 80%) - Sem necessidade de irrigacao.");
    return false;
  }

  // Condição 3: pH fora do range -> não irrigar, alertar
  if (phValor < 5.0 || phValor > 7.5) {
    Serial.println("[ALERTA] pH fora do ideal para soja (5.0-7.5). Corrija o solo!");
    return false;
  }

  // Condição 4: Umidade abaixo do ideal E nutrientes mínimos presentes
  if (umidade < 60.0 && (fosforo || potassio)) {
    Serial.println("[DECISAO] Condicoes favoraveis - Irrigando lavoura de soja.");
    return true;
  }

  // Condição 5: Umidade OK (60–79%) -> não irrigar por ora
  if (umidade >= 60.0 && umidade < 80.0) {
    Serial.println("[DECISAO] Umidade adequada - Irrigacao nao necessaria.");
    return false;
  }

  return false;
}

// ============================================================
// Lê dado de previsão de chuva via Serial (enviado pelo Python)
// ============================================================
void lerSerial() {
  if (Serial.available() > 0) {
    char c = Serial.read();
    if (c == '0') {
      previsaoChuva = 0;
      Serial.println("[SERIAL] Previsao atualizada: SEM CHUVA");
    } else if (c == '1') {
      previsaoChuva = 1;
      Serial.println("[SERIAL] Previsao atualizada: CHUVA PREVISTA");
    }
  }
}

// ============================================================
// Exibe status completo no Monitor Serial (formato CSV + legivel)
// ============================================================
void exibirStatus() {
  Serial.println("--------------------------------------------------");
  Serial.print("Cultura: SOJA | Hora: ");
  Serial.println(millis() / 1000);

  Serial.print("NPK -> N:");
  Serial.print(nitrogenio ? "SIM" : "NAO");
  Serial.print(" | P:");
  Serial.print(fosforo ? "SIM" : "NAO");
  Serial.print(" | K:");
  Serial.println(potassio ? "SIM" : "NAO");

  Serial.print("pH (LDR): ");
  Serial.print(phValor, 2);
  if (phValor < 5.0)       Serial.println(" [ACIDO - FORA DO IDEAL]");
  else if (phValor <= 7.0) Serial.println(" [IDEAL PARA SOJA]");
  else if (phValor <= 7.5) Serial.println(" [LEVEMENTE ALCALINO - LIMITE]");
  else                     Serial.println(" [ALCALINO - FORA DO IDEAL]");

  Serial.print("Umidade Solo: ");
  Serial.print(umidade, 1);
  Serial.print("% | Temperatura: ");
  Serial.print(temperatura, 1);
  Serial.println("°C");

  Serial.print("Chuva Prevista: ");
  Serial.println(previsaoChuva ? "SIM" : "NAO");

  Serial.print("Bomba d'agua (rele): ");
  Serial.println(irrigando ? "LIGADA" : "DESLIGADA");

  // Linha CSV para coleta de dados (Python pode capturar)
  // formato: CSV,N,P,K,pH,Umidade,Temp,Chuva,Bomba
  Serial.print("CSV,");
  Serial.print(nitrogenio ? 1 : 0); Serial.print(",");
  Serial.print(fosforo    ? 1 : 0); Serial.print(",");
  Serial.print(potassio   ? 1 : 0); Serial.print(",");
  Serial.print(phValor,  2);        Serial.print(",");
  Serial.print(umidade,  1);        Serial.print(",");
  Serial.print(temperatura, 1);     Serial.print(",");
  Serial.print(previsaoChuva);      Serial.print(",");
  Serial.println(irrigando ? 1 : 0);

  Serial.println("--------------------------------------------------");
}
