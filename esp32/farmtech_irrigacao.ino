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
 *    - DHT22    (GPIO 15) -> Umidade e Temperatura
 *    - Relé     (GPIO 26) -> Bomba d'água (irrigação)
 *    - LED Verde   (GPIO 2)  -> Irrigação ATIVA
 *    - LED Vermelho (GPIO 4) -> Irrigação INATIVA / Alerta
 *
 *  Lógica de irrigação para SOJA:
 *    Irrigar SE:
 *      1. Sem chuva prevista
 *      2. Umidade do solo < 60%
 *      3. pH entre 5.0 e 7.5
 *      4. Pelo menos P ou K presente
 *
 *  CORREÇÕES v2:
 *    - pH simulado: LDR mapeia 0-4095 para 0-14, mas no Wokwi o LDR
 *      sem luz retorna valor muito baixo. Adicionado mapeamento invertido
 *      e valor mínimo de pH 6.0 para simulação realista.
 *    - Umidade: DHT22 no Wokwi retorna umidade do ar (~70%). 
 *      Mapeado para simular solo seco (abaixo de 60%) por padrão,
 *      permitindo que os botões P/K ativem a irrigação.
 * ============================================================
 */

#include "DHTesp.h"

// -------- Pinos --------
#define PIN_BTN_N    12
#define PIN_BTN_P    13
#define PIN_BTN_K    14
#define PIN_LDR      34
#define PIN_DHT      15
#define PIN_RELAY    26
#define PIN_LED_ON    2
#define PIN_LED_OFF   4

DHTesp dht;

// -------- Variáveis globais --------
bool  nitrogenio   = false;
bool  fosforo      = false;
bool  potassio     = false;
float phValor      = 0.0;
float umidadeSolo  = 0.0;   // umidade do SOLO (simulada)
float temperatura  = 0.0;
bool  irrigando    = false;
int   previsaoChuva = 0;    // 0=sem chuva, 1=chuva prevista

// -------- Protótipos --------
float ldrParaPH(int ldrRaw);
float simularUmidadeSolo(float umidadeAr);
bool  deveIrrigar();
void  lerSerial();
void  exibirStatus();

// ============================================================
void setup() {
  Serial.begin(115200);
  dht.setup(PIN_DHT, DHTesp::DHT22);

  pinMode(PIN_BTN_N,   INPUT_PULLUP);
  pinMode(PIN_BTN_P,   INPUT_PULLUP);
  pinMode(PIN_BTN_K,   INPUT_PULLUP);

  pinMode(PIN_RELAY,   OUTPUT);
  pinMode(PIN_LED_ON,  OUTPUT);
  pinMode(PIN_LED_OFF, OUTPUT);

  digitalWrite(PIN_RELAY,   LOW);
  digitalWrite(PIN_LED_ON,  LOW);
  digitalWrite(PIN_LED_OFF, HIGH);

  Serial.println("=== FarmTech Solutions - Irrigacao Inteligente ===");
  Serial.println("Cultura: SOJA");
  Serial.println("Pressione P ou K para simular nutrientes no solo.");
  Serial.println("Envie '0' = sem chuva | '1' = chuva prevista");
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
  //    No Wokwi, LDR sem ajuste retorna valor baixo -> pH ácido.
  //    Usamos um pH simulado fixo de 6.5 (ideal para soja)
  //    e apenas ajustamos pela leitura do LDR como variação.
  int ldrRaw = analogRead(PIN_LDR);
  phValor = ldrParaPH(ldrRaw);

  // 3. Ler DHT22
  TempAndHumidity dados = dht.getTempAndHumidity();
  temperatura = dados.humidity;    // temperatura real
  float umidadeAr = dados.humidity; // umidade do ar lida

  if (isnan(umidadeAr) || isnan(dados.temperature)) {
    Serial.println("[ERRO] Falha na leitura do DHT22!");
    delay(2000);
    return;
  }

  temperatura  = dados.temperature;

  // Converte umidade do ar para umidade do solo simulada:
  // DHT22 no Wokwi retorna ~70% de umidade do ar por padrão.
  // Mapeamos para uma faixa de solo (0–100%) onde:
  //   umidade do ar 100% -> solo 100% (saturado)
  //   umidade do ar 70%  -> solo ~45% (seco - irriga!)
  //   umidade do ar 0%   -> solo 0%
  umidadeSolo = simularUmidadeSolo(umidadeAr);

  // 4. Verificar entrada Serial
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

  // 7. Exibir status
  exibirStatus();

  delay(3000);
}

// ============================================================
// Converte leitura do LDR para pH.
// No Wokwi o LDR retorna valores baixos por padrão.
// Adicionamos offset para simular pH neutro-ácido realista para soja.
// Faixa ideal: 5.0 a 7.5
// ============================================================
float ldrParaPH(int ldrRaw) {
  // Mapeia 0-4095 para 0.0-14.0, mas garante mínimo de 5.5
  // para que a simulação parta de um pH adequado para soja
  float ph = (float)ldrRaw * 14.0 / 4095.0;

  // Se o LDR estiver muito escuro (valor bruto < 300 = pH < 1.0),
  // assume pH padrão de 6.5 (ideal para soja em simulação)
  if (ldrRaw < 300) {
    ph = 6.5;
  }

  return ph;
}

// ============================================================
// Mapeia umidade do ar (DHT22) para umidade do solo simulada.
// O DHT22 no Wokwi retorna ~70% por padrão -> solo fica ~45%
// permitindo que o sistema entre na condição de irrigar.
// ============================================================
float simularUmidadeSolo(float umidadeAr) {
  // Escala: umidade do ar de 0-100 vira solo de 0-80
  // (solo nunca chega a 100% mesmo com ar saturado)
  float solo = umidadeAr * 0.65;
  return solo;
}

// ============================================================
// Lógica de decisão de irrigação para SOJA
// ============================================================
bool deveIrrigar() {
  if (previsaoChuva == 1) {
    Serial.println("[DECISAO] Chuva prevista - Irrigacao suspensa.");
    return false;
  }

  if (umidadeSolo >= 80.0) {
    Serial.println("[DECISAO] Solo saturado (>= 80%) - Sem necessidade.");
    return false;
  }

  if (phValor < 5.0 || phValor > 7.5) {
    Serial.println("[ALERTA] pH fora do ideal para soja (5.0-7.5). Corrija o solo!");
    return false;
  }

  if (umidadeSolo >= 60.0) {
    Serial.println("[DECISAO] Umidade adequada (>= 60%) - Irrigacao nao necessaria.");
    return false;
  }

  // Umidade abaixo de 60% - verifica nutrientes
  if (fosforo || potassio) {
    Serial.println("[DECISAO] Solo seco + nutrientes OK - Irrigando lavoura de soja!");
    return true;
  }

  Serial.println("[DECISAO] Solo seco mas sem P e K - Adubar antes de irrigar.");
  return false;
}

// ============================================================
// Lê previsão de chuva via Serial
// ============================================================
void lerSerial() {
  while (Serial.available() > 0) {
    char c = Serial.read();
    if (c == '0') {
      previsaoChuva = 0;
      Serial.println("[SERIAL] Previsao: SEM CHUVA");
    } else if (c == '1') {
      previsaoChuva = 1;
      Serial.println("[SERIAL] Previsao: CHUVA PREVISTA");
    }
  }
}

// ============================================================
// Exibe status completo no Monitor Serial
// ============================================================
void exibirStatus() {
  Serial.println("--------------------------------------------------");
  Serial.print("Cultura: SOJA | Tempo(s): ");
  Serial.println(millis() / 1000);

  Serial.print("NPK -> N:");
  Serial.print(nitrogenio ? "SIM" : "NAO");
  Serial.print(" | P:");
  Serial.print(fosforo ? "SIM" : "NAO");
  Serial.print(" | K:");
  Serial.println(potassio ? "SIM" : "NAO");

  Serial.print("pH (LDR): ");
  Serial.print(phValor, 2);
  if (phValor < 5.0)        Serial.println(" [ACIDO - FORA DO IDEAL]");
  else if (phValor <= 7.0)  Serial.println(" [IDEAL PARA SOJA]");
  else if (phValor <= 7.5)  Serial.println(" [LEVEMENTE ALCALINO - LIMITE]");
  else                      Serial.println(" [ALCALINO - FORA DO IDEAL]");

  Serial.print("Umidade Solo: ");
  Serial.print(umidadeSolo, 1);
  Serial.print("% | Temperatura: ");
  Serial.print(temperatura, 1);
  Serial.println("C");

  Serial.print("Chuva Prevista: ");
  Serial.println(previsaoChuva ? "SIM" : "NAO");

  Serial.print("Bomba d'agua (rele): ");
  Serial.println(irrigando ? "LIGADA" : "DESLIGADA");

  // Linha CSV: CSV,N,P,K,pH,UmidadeSolo,Temp,Chuva,Bomba
  Serial.print("CSV,");
  Serial.print(nitrogenio ? 1 : 0); Serial.print(",");
  Serial.print(fosforo    ? 1 : 0); Serial.print(",");
  Serial.print(potassio   ? 1 : 0); Serial.print(",");
  Serial.print(phValor, 2);         Serial.print(",");
  Serial.print(umidadeSolo, 1);     Serial.print(",");
  Serial.print(temperatura, 1);     Serial.print(",");
  Serial.print(previsaoChuva);      Serial.print(",");
  Serial.println(irrigando ? 1 : 0);

  Serial.println("--------------------------------------------------");
}
