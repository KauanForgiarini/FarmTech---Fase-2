# ============================================================
#  FarmTech Solutions - Análise Estatística em R
#  Fase 2 - FIAP Inteligência Artificial
#  Aluno: Kauan Maciel Forgiarini | RM 574005
# ============================================================
#
#  Objetivo:
#    Analisar o histórico de leituras do sistema de irrigação
#    e aplicar estatísticas descritivas + regressão logística
#    para prever se a bomba deve ser ativada.
#
#  Entrada : farmtech_historico.csv (gerado pelo Python)
#  Saída   : graficos/ (PNGs gerados pelo ggplot2)
# ============================================================

# ---- Instala pacotes se necessário ----
pacotes <- c("ggplot2", "dplyr", "caret", "readr")
novos   <- pacotes[!(pacotes %in% installed.packages()[, "Package"])]
if (length(novos) > 0) install.packages(novos, repos = "https://cran.r-project.org")

library(ggplot2)
library(dplyr)
library(caret)
library(readr)

cat("============================================================\n")
cat("  FarmTech Solutions - Analise Estatistica (R)\n")
cat("  Aluno: Kauan Maciel Forgiarini | RM 574005\n")
cat("============================================================\n\n")

# ============================================================
# 1. CARREGAMENTO E PREPARAÇÃO DOS DADOS
# ============================================================

arquivo_csv <- "farmtech_historico.csv"

if (file.exists(arquivo_csv)) {
  df <- read_csv(arquivo_csv, show_col_types = FALSE)
  cat("Dados carregados de:", arquivo_csv, "\n")
  cat("   Registros:", nrow(df), "\n\n")
} else {
  cat("AVISO: CSV nao encontrado. Gerando dados simulados...\n\n")
  set.seed(42)
  n <- 200

  umidade_sim <- runif(n, 30, 95)
  ph_sim      <- runif(n, 4.0, 9.0)
  N_sim       <- sample(c(0, 1), n, replace = TRUE, prob = c(0.4, 0.6))
  P_sim       <- sample(c(0, 1), n, replace = TRUE, prob = c(0.3, 0.7))
  K_sim       <- sample(c(0, 1), n, replace = TRUE, prob = c(0.35, 0.65))
  chuva_sim   <- sample(c(0, 1), n, replace = TRUE, prob = c(0.7, 0.3))
  temp_sim    <- runif(n, 18, 38)

  # Lógica idêntica ao C/C++ e Python
  bomba_ativa_sim <- as.integer(
    chuva_sim == 0 &
    umidade_sim < 60 &
    ph_sim >= 5.0 & ph_sim <= 7.5 &
    (P_sim == 1 | K_sim == 1)
  )

  df <- data.frame(
    timestamp       = seq.POSIXt(Sys.time() - 3600 * n / 12, Sys.time(), length.out = n),
    N               = N_sim,
    P               = P_sim,
    K               = K_sim,
    pH              = round(ph_sim, 2),
    `umidade_%`     = round(umidade_sim, 1),
    temperatura_C   = round(temp_sim, 1),
    chuva_prevista  = chuva_sim,
    volume_chuva_mm = round(ifelse(chuva_sim == 1, runif(n, 1, 15), 0), 1),
    condicao_clima  = ifelse(chuva_sim == 1, "Chuva leve", "Ceu claro"),
    bomba_ativa     = bomba_ativa_sim,
    motivo          = "Simulado",
    check.names     = FALSE
  )
}

# Renomear coluna de umidade (evita problemas com o símbolo %)
if ("umidade_%" %in% names(df)) {
  names(df)[names(df) == "umidade_%"] <- "umidade"
}

# Garantir tipos corretos para colunas numéricas
df$pH           <- as.numeric(df$pH)
df$umidade      <- as.numeric(df$umidade)
df$temperatura_C <- as.numeric(df$temperatura_C)
df$bomba_ativa  <- as.integer(df$bomba_ativa)
df$chuva_prevista <- as.integer(df$chuva_prevista)
df$N <- as.integer(df$N)
df$P <- as.integer(df$P)
df$K <- as.integer(df$K)

# Versão fatorada (para gráficos)
df$bomba_fator    <- factor(df$bomba_ativa,    levels = c(0, 1), labels = c("Desligada", "Ligada"))
df$chuva_fator    <- factor(df$chuva_prevista, levels = c(0, 1), labels = c("Nao", "Sim"))
df$N_fator        <- factor(df$N, levels = c(0, 1), labels = c("Ausente", "Presente"))
df$P_fator        <- factor(df$P, levels = c(0, 1), labels = c("Ausente", "Presente"))
df$K_fator        <- factor(df$K, levels = c(0, 1), labels = c("Ausente", "Presente"))

cat("--- Preview dos dados ---\n")
print(head(df[, c("umidade", "pH", "N_fator", "P_fator", "K_fator",
                   "chuva_fator", "bomba_fator")], 6))
cat("\n")

# ============================================================
# 2. ESTATÍSTICAS DESCRITIVAS
# ============================================================
cat("============================================================\n")
cat("  2. ESTATISTICAS DESCRITIVAS - Variaveis Continuas\n")
cat("============================================================\n")

vars_continuas <- df %>% select(pH, umidade, temperatura_C)
print(summary(vars_continuas))
cat("\n")

cat("--- Desvio Padrao ---\n")
cat("pH          :", round(sd(df$pH,           na.rm = TRUE), 4), "\n")
cat("Umidade (%) :", round(sd(df$umidade,      na.rm = TRUE), 4), "\n")
cat("Temperatura :", round(sd(df$temperatura_C, na.rm = TRUE), 4), "\n\n")

cat("--- Frequencia da Bomba ---\n")
print(table(df$bomba_fator))
cat("\nProporcao:\n")
print(round(prop.table(table(df$bomba_fator)), 3))
cat("\n")

cat("--- Bomba x Chuva ---\n")
print(table(Bomba = df$bomba_fator, Chuva = df$chuva_fator))
cat("\n")

# ============================================================
# 3. VISUALIZAÇÕES
# ============================================================
cat("============================================================\n")
cat("  3. GERANDO GRAFICOS\n")
cat("============================================================\n")

dir.create("graficos", showWarnings = FALSE)

tema_farm <- theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold"),
    plot.subtitle = element_text(color = "gray40")
  )

# --- Gráfico 1: Distribuição de Umidade por Status da Bomba ---
g1 <- ggplot(df, aes(x = umidade, fill = bomba_fator)) +
  geom_histogram(bins = 20, alpha = 0.7, position = "identity") +
  scale_fill_manual(values = c("Desligada" = "#e74c3c", "Ligada" = "#2ecc71")) +
  geom_vline(xintercept = 60, linetype = "dashed", color = "blue",   linewidth = 0.8) +
  geom_vline(xintercept = 80, linetype = "dashed", color = "orange", linewidth = 0.8) +
  labs(
    title    = "Distribuicao de Umidade do Solo por Status da Bomba",
    subtitle = "Linhas: limites 60% e 80% | Cultura: Soja | FarmTech Solutions",
    x        = "Umidade do Solo (%)",
    y        = "Frequencia",
    fill     = "Bomba d'agua"
  ) +
  tema_farm

ggsave("graficos/01_umidade_bomba.png", g1, width = 8, height = 5, dpi = 150)
cat("OK: graficos/01_umidade_bomba.png\n")

# --- Gráfico 2: pH vs Umidade colorido por status da bomba ---
g2 <- ggplot(df, aes(x = pH, y = umidade, color = bomba_fator)) +
  geom_point(alpha = 0.6, size = 2.5) +
  scale_color_manual(values = c("Desligada" = "#e74c3c", "Ligada" = "#2ecc71")) +
  geom_vline(xintercept = c(5.0, 7.5), linetype = "dashed", color = "orange", linewidth = 0.8) +
  geom_hline(yintercept = c(60, 80),   linetype = "dashed", color = "blue",   linewidth = 0.8) +
  annotate("text", x = 5.0, y = max(df$umidade, na.rm = TRUE) * 0.98,
           label = "pH 5.0", size = 3, color = "orange", hjust = -0.1) +
  annotate("text", x = 7.5, y = max(df$umidade, na.rm = TRUE) * 0.98,
           label = "pH 7.5", size = 3, color = "orange", hjust = -0.1) +
  labs(
    title    = "pH vs Umidade do Solo",
    subtitle = "Linhas tracejadas = limites ideais para Soja",
    x        = "pH do Solo (simulado via LDR)",
    y        = "Umidade do Solo (%)",
    color    = "Bomba d'agua"
  ) +
  tema_farm

ggsave("graficos/02_ph_umidade_scatter.png", g2, width = 8, height = 5, dpi = 150)
cat("OK: graficos/02_ph_umidade_scatter.png\n")

# --- Gráfico 3: Boxplot Umidade por Presença de Fósforo ---
g3 <- ggplot(df, aes(x = P_fator, y = umidade, fill = bomba_fator)) +
  geom_boxplot(alpha = 0.7) +
  scale_fill_manual(values = c("Desligada" = "#e74c3c", "Ligada" = "#2ecc71")) +
  labs(
    title    = "Umidade do Solo por Disponibilidade de Fosforo (P)",
    subtitle = "Cultura: Soja | FarmTech Solutions",
    x        = "Fosforo (P)",
    y        = "Umidade (%)",
    fill     = "Bomba d'agua"
  ) +
  tema_farm

ggsave("graficos/03_boxplot_fosforo.png", g3, width = 7, height = 5, dpi = 150)
cat("OK: graficos/03_boxplot_fosforo.png\n")

# --- Gráfico 4: Série temporal de umidade ---
n_serie   <- min(50, nrow(df))
df_serie  <- df %>% slice(1:n_serie)
df_serie$indice <- seq_len(nrow(df_serie))

g4 <- ggplot(df_serie, aes(x = indice, y = umidade)) +
  geom_line(color = "#3498db", linewidth = 1) +
  geom_point(aes(color = bomba_fator), size = 3) +
  scale_color_manual(values = c("Desligada" = "#e74c3c", "Ligada" = "#2ecc71")) +
  geom_hline(yintercept = 60, linetype = "dashed", color = "orange") +
  geom_hline(yintercept = 80, linetype = "dashed", color = "red") +
  labs(
    title    = "Serie Temporal - Umidade do Solo",
    subtitle = paste0("Primeiras ", n_serie, " leituras | Linhas = limites 60% e 80%"),
    x        = "Leitura n",
    y        = "Umidade (%)",
    color    = "Bomba"
  ) +
  tema_farm

ggsave("graficos/04_serie_temporal_umidade.png", g4, width = 9, height = 5, dpi = 150)
cat("OK: graficos/04_serie_temporal_umidade.png\n\n")

# ============================================================
# 4. REGRESSÃO LOGÍSTICA - Prever ativação da bomba
# ============================================================
cat("============================================================\n")
cat("  4. REGRESSAO LOGISTICA - Previsao de Ativacao da Bomba\n")
cat("============================================================\n")

# Requer pelo menos 20 registros para treino/teste
if (nrow(df) < 20) {
  cat("AVISO: Poucos registros (", nrow(df), ") para regressao logistica.\n")
  cat("       Execute o Python por mais tempo para coletar mais dados.\n\n")
} else {
  df_modelo <- df %>%
    select(bomba_ativa, umidade, pH, N, P, K, chuva_prevista, temperatura_C) %>%
    filter(!is.na(umidade), !is.na(pH))

  # Divisão treino/teste 80/20
  set.seed(123)
  idx_treino <- createDataPartition(df_modelo$bomba_ativa, p = 0.8, list = FALSE)
  treino     <- df_modelo[idx_treino, ]
  teste      <- df_modelo[-idx_treino, ]

  cat("Registros para treino:", nrow(treino), "\n")
  cat("Registros para teste :", nrow(teste),  "\n\n")

  # Ajuste do modelo
  modelo_logistico <- glm(
    bomba_ativa ~ umidade + pH + N + P + K + chuva_prevista + temperatura_C,
    data   = treino,
    family = binomial(link = "logit")
  )

  cat("--- Sumario do Modelo ---\n")
  print(summary(modelo_logistico))

  # Predições no conjunto de teste
  prob_pred   <- predict(modelo_logistico, newdata = teste, type = "response")
  classe_pred <- ifelse(prob_pred >= 0.5, 1, 0)

  # Matriz de confusão
  cat("\n--- Matriz de Confusao ---\n")
  conf_matrix <- confusionMatrix(
    factor(classe_pred,        levels = c(0, 1), labels = c("Desligada", "Ligada")),
    factor(teste$bomba_ativa,  levels = c(0, 1), labels = c("Desligada", "Ligada")),
    positive = "Ligada"
  )
  print(conf_matrix)

  # ============================================================
  # 5. EXEMPLO DE PREVISÃO INDIVIDUAL
  # ============================================================
  cat("============================================================\n")
  cat("  5. EXEMPLO - Previsao para novo cenario de campo\n")
  cat("============================================================\n")

  novo_cenario <- data.frame(
    umidade        = 52.0,   # Solo com umidade baixa
    pH             = 6.3,    # pH ideal para soja
    N              = 1,      # Nitrogenio presente
    P              = 1,      # Fosforo presente
    K              = 0,      # Potassio ausente
    chuva_prevista = 0,      # Sem previsao de chuva
    temperatura_C  = 28.5
  )

  prob_irrigar <- predict(modelo_logistico, newdata = novo_cenario, type = "response")
  decisao      <- ifelse(prob_irrigar >= 0.5, "IRRIGAR", "NAO IRRIGAR")

  cat("Cenario analisado:\n")
  cat("  Umidade     :", novo_cenario$umidade, "%\n")
  cat("  pH          :", novo_cenario$pH, "\n")
  cat("  Nitrogenio  :", ifelse(novo_cenario$N == 1, "Presente", "Ausente"), "\n")
  cat("  Fosforo     :", ifelse(novo_cenario$P == 1, "Presente", "Ausente"), "\n")
  cat("  Potassio    :", ifelse(novo_cenario$K == 1, "Presente", "Ausente"), "\n")
  cat("  Chuva       :", ifelse(novo_cenario$chuva_prevista == 1, "Sim", "Nao"), "\n")
  cat("  Temperatura :", novo_cenario$temperatura_C, "C\n\n")
  cat("  Probabilidade de irrigar:", round(prob_irrigar * 100, 1), "%\n")
  cat("  Decisao do modelo       :", decisao, "\n\n")
}

cat("============================================================\n")
cat("  Analise concluida! Graficos salvos em ./graficos/\n")
cat("============================================================\n")
