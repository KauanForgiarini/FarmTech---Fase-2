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
#  Arquivo de entrada: farmtech_historico.csv (gerado pelo Python)
# ============================================================

# ---- Instala pacotes se necessário ----
pacotes <- c("ggplot2", "dplyr", "caret", "corrplot", "readr")
novos <- pacotes[!(pacotes %in% installed.packages()[,"Package"])]
if (length(novos)) install.packages(novos, repos="https://cran.r-project.org")

library(ggplot2)
library(dplyr)
library(caret)
library(corrplot)
library(readr)

cat("============================================================\n")
cat("  FarmTech Solutions - Análise Estatística (R)\n")
cat("  Aluno: Kauan Maciel Forgiarini | RM 574005\n")
cat("============================================================\n\n")

# ============================================================
# 1. CARREGAMENTO E PREPARAÇÃO DOS DADOS
# ============================================================

# Se o CSV real existir, usa-o; caso contrário, gera dados simulados
arquivo_csv <- "farmtech_historico.csv"

if (file.exists(arquivo_csv)) {
  df <- read_csv(arquivo_csv, show_col_types = FALSE)
  cat("✅ Dados carregados de:", arquivo_csv, "\n")
  cat("   Registros:", nrow(df), "\n\n")
} else {
  cat("⚠️  CSV não encontrado. Gerando dados simulados para demonstração...\n\n")
  set.seed(42)
  n <- 200
  
  umidade  <- runif(n, 30, 95)
  ph       <- runif(n, 4.0, 9.0)
  N        <- sample(c(0,1), n, replace=TRUE, prob=c(0.4, 0.6))
  P        <- sample(c(0,1), n, replace=TRUE, prob=c(0.3, 0.7))
  K        <- sample(c(0,1), n, replace=TRUE, prob=c(0.35, 0.65))
  chuva    <- sample(c(0,1), n, replace=TRUE, prob=c(0.7, 0.3))
  temp     <- runif(n, 18, 38)
  
  # Lógica realista de bomba (igual ao C/C++ e Python)
  bomba_ativa <- as.integer(
    chuva == 0 &
    umidade < 60 &
    ph >= 5.0 & ph <= 7.5 &
    (P == 1 | K == 1)
  )
  
  df <- data.frame(
    timestamp       = seq.POSIXt(Sys.time() - 3600*n/12, Sys.time(), length.out=n),
    N               = N,
    P               = P,
    K               = K,
    pH              = round(ph, 2),
    `umidade_%`     = round(umidade, 1),
    temperatura_C   = round(temp, 1),
    chuva_prevista  = chuva,
    volume_chuva_mm = round(ifelse(chuva==1, runif(n, 1, 15), 0), 1),
    condicao_clima  = ifelse(chuva==1, "Chuva leve", "Céu claro"),
    bomba_ativa     = bomba_ativa,
    motivo          = "Simulado"
  )
}

# Renomear coluna de umidade para facilitar
names(df)[names(df) == "umidade_%"] <- "umidade"

# Transformar colunas em fatores
df$bomba_ativa     <- factor(df$bomba_ativa,    levels=c(0,1), labels=c("Desligada","Ligada"))
df$chuva_prevista  <- factor(df$chuva_prevista, levels=c(0,1), labels=c("Não","Sim"))
df$N <- factor(df$N, levels=c(0,1), labels=c("Ausente","Presente"))
df$P <- factor(df$P, levels=c(0,1), labels=c("Ausente","Presente"))
df$K <- factor(df$K, levels=c(0,1), labels=c("Ausente","Presente"))

cat("--- Preview dos dados ---\n")
print(head(df[, c("umidade","pH","N","P","K","chuva_prevista","bomba_ativa")], 6))
cat("\n")

# ============================================================
# 2. ESTATÍSTICAS DESCRITIVAS
# ============================================================
cat("============================================================\n")
cat("  2. ESTATÍSTICAS DESCRITIVAS - Variáveis Contínuas\n")
cat("============================================================\n")

vars_continuas <- df %>% select(pH, umidade, temperatura_C)
print(summary(vars_continuas))
cat("\n")

# Desvio padrão
cat("--- Desvio Padrão ---\n")
cat("pH           :", round(sd(df$pH), 4), "\n")
cat("Umidade (%)  :", round(sd(df$umidade), 4), "\n")
cat("Temperatura  :", round(sd(df$temperatura_C), 4), "\n\n")

cat("--- Frequência da Bomba ---\n")
print(table(df$bomba_ativa))
cat("\nProporção:\n")
print(prop.table(table(df$bomba_ativa)))
cat("\n")

cat("--- Bomba x Chuva ---\n")
print(table(Bomba=df$bomba_ativa, Chuva=df$chuva_prevista))
cat("\n")

# ============================================================
# 3. VISUALIZAÇÕES
# ============================================================
cat("============================================================\n")
cat("  3. GERANDO GRÁFICOS\n")
cat("============================================================\n")

dir.create("graficos", showWarnings=FALSE)

# --- Gráfico 1: Distribuição de Umidade por Status da Bomba ---
g1 <- ggplot(df, aes(x=umidade, fill=bomba_ativa)) +
  geom_histogram(bins=20, alpha=0.7, position="identity") +
  scale_fill_manual(values=c("Desligada"="#e74c3c","Ligada"="#2ecc71")) +
  labs(
    title    = "Distribuição de Umidade do Solo por Status da Bomba",
    subtitle = "Cultura: Soja | FarmTech Solutions",
    x        = "Umidade do Solo (%)",
    y        = "Frequência",
    fill     = "Bomba d'água"
  ) +
  theme_minimal(base_size=13) +
  theme(plot.title=element_text(face="bold"))

ggsave("graficos/01_umidade_bomba.png", g1, width=8, height=5, dpi=150)
cat("✅ graficos/01_umidade_bomba.png\n")

# --- Gráfico 2: pH vs Umidade colorido por bomba ---
g2 <- ggplot(df, aes(x=pH, y=umidade, color=bomba_ativa)) +
  geom_point(alpha=0.6, size=2.5) +
  scale_color_manual(values=c("Desligada"="#e74c3c","Ligada"="#2ecc71")) +
  geom_vline(xintercept=c(5.0, 7.5), linetype="dashed", color="orange", linewidth=0.8) +
  geom_hline(yintercept=c(60, 80),   linetype="dashed", color="blue",   linewidth=0.8) +
  annotate("text", x=5.0, y=95, label="pH mín\n(5.0)", size=3, color="orange") +
  annotate("text", x=7.5, y=95, label="pH máx\n(7.5)", size=3, color="orange") +
  annotate("text", x=4.2, y=60, label="Umid 60%", size=3, color="blue") +
  annotate("text", x=4.2, y=80, label="Umid 80%", size=3, color="blue") +
  labs(
    title    = "pH vs Umidade do Solo",
    subtitle = "Linhas tracejadas = limites ideais para Soja",
    x        = "pH do Solo (simulado via LDR)",
    y        = "Umidade do Solo (%)",
    color    = "Bomba d'água"
  ) +
  theme_minimal(base_size=13) +
  theme(plot.title=element_text(face="bold"))

ggsave("graficos/02_ph_umidade_scatter.png", g2, width=8, height=5, dpi=150)
cat("✅ graficos/02_ph_umidade_scatter.png\n")

# --- Gráfico 3: Boxplot Umidade por Presença de Nutrientes ---
g3 <- ggplot(df, aes(x=P, y=umidade, fill=bomba_ativa)) +
  geom_boxplot(alpha=0.7) +
  scale_fill_manual(values=c("Desligada"="#e74c3c","Ligada"="#2ecc71")) +
  labs(
    title = "Umidade do Solo por Disponibilidade de Fósforo (P)",
    x     = "Fósforo (P)",
    y     = "Umidade (%)",
    fill  = "Bomba d'água"
  ) +
  theme_minimal(base_size=13) +
  theme(plot.title=element_text(face="bold"))

ggsave("graficos/03_boxplot_fosforo.png", g3, width=7, height=5, dpi=150)
cat("✅ graficos/03_boxplot_fosforo.png\n")

# --- Gráfico 4: Série temporal de umidade (primeiros 50 registros) ---
df_serie <- df %>% slice(1:min(50, nrow(df)))
df_serie$indice <- seq_len(nrow(df_serie))

g4 <- ggplot(df_serie, aes(x=indice, y=umidade)) +
  geom_line(color="#3498db", linewidth=1) +
  geom_point(aes(color=bomba_ativa), size=3) +
  scale_color_manual(values=c("Desligada"="#e74c3c","Ligada"="#2ecc71")) +
  geom_hline(yintercept=60, linetype="dashed", color="orange") +
  geom_hline(yintercept=80, linetype="dashed", color="red") +
  labs(
    title    = "Série Temporal - Umidade do Solo",
    subtitle = "Primeiras 50 leituras | Linhas = limites 60% e 80%",
    x        = "Leitura nº",
    y        = "Umidade (%)",
    color    = "Bomba"
  ) +
  theme_minimal(base_size=13) +
  theme(plot.title=element_text(face="bold"))

ggsave("graficos/04_serie_temporal_umidade.png", g4, width=9, height=5, dpi=150)
cat("✅ graficos/04_serie_temporal_umidade.png\n\n")

# ============================================================
# 4. REGRESSÃO LOGÍSTICA - Prever ativação da bomba
# ============================================================
cat("============================================================\n")
cat("  4. REGRESSÃO LOGÍSTICA - Previsão de Ativação da Bomba\n")
cat("============================================================\n")

# Prepara dados numéricos para o modelo
df_modelo <- df %>%
  mutate(
    bomba_num   = ifelse(bomba_ativa == "Ligada", 1, 0),
    chuva_num   = ifelse(chuva_prevista == "Sim", 1, 0),
    N_num       = ifelse(N == "Presente", 1, 0),
    P_num       = ifelse(P == "Presente", 1, 0),
    K_num       = ifelse(K == "Presente", 1, 0)
  )

# Divisão treino/teste (80/20)
set.seed(123)
idx_treino <- createDataPartition(df_modelo$bomba_num, p=0.8, list=FALSE)
treino     <- df_modelo[idx_treino, ]
teste      <- df_modelo[-idx_treino, ]

cat("Registros para treino:", nrow(treino), "\n")
cat("Registros para teste :", nrow(teste),  "\n\n")

# Ajuste do modelo
modelo_logistico <- glm(
  bomba_num ~ umidade + pH + N_num + P_num + K_num + chuva_num + temperatura_C,
  data   = treino,
  family = binomial(link="logit")
)

cat("--- Sumário do Modelo ---\n")
print(summary(modelo_logistico))

# Predições no conjunto de teste
prob_pred <- predict(modelo_logistico, newdata=teste, type="response")
classe_pred <- ifelse(prob_pred >= 0.5, 1, 0)

# Matriz de confusão
cat("\n--- Matriz de Confusão ---\n")
conf_matrix <- confusionMatrix(
  factor(classe_pred, levels=c(0,1), labels=c("Desligada","Ligada")),
  factor(teste$bomba_num, levels=c(0,1), labels=c("Desligada","Ligada")),
  positive="Ligada"
)
print(conf_matrix)

# ============================================================
# 5. EXEMPLO DE PREVISÃO INDIVIDUAL
# ============================================================
cat("============================================================\n")
cat("  5. EXEMPLO - Previsão para novo cenário de campo\n")
cat("============================================================\n")

novo_cenario <- data.frame(
  umidade       = 52.0,   # Solo com umidade baixa
  pH            = 6.3,    # pH ideal para soja
  N_num         = 1,      # Nitrogênio presente
  P_num         = 1,      # Fósforo presente
  K_num         = 0,      # Potássio ausente
  chuva_num     = 0,      # Sem previsão de chuva
  temperatura_C = 28.5
)

prob_irrigar <- predict(modelo_logistico, newdata=novo_cenario, type="response")
decisao <- ifelse(prob_irrigar >= 0.5, "✅ IRRIGAR", "❌ NÃO IRRIGAR")

cat("Cenário analisado:\n")
cat("  Umidade     :", novo_cenario$umidade, "%\n")
cat("  pH          :", novo_cenario$pH, "\n")
cat("  Nitrogênio  :", ifelse(novo_cenario$N_num==1,"Presente","Ausente"), "\n")
cat("  Fósforo     :", ifelse(novo_cenario$P_num==1,"Presente","Ausente"), "\n")
cat("  Potássio    :", ifelse(novo_cenario$K_num==1,"Presente","Ausente"), "\n")
cat("  Chuva       :", ifelse(novo_cenario$chuva_num==1,"Sim","Não"), "\n")
cat("  Temperatura :", novo_cenario$temperatura_C, "°C\n\n")
cat("  Probabilidade de irrigar:", round(prob_irrigar * 100, 1), "%\n")
cat("  Decisão do modelo       :", decisao, "\n\n")

cat("============================================================\n")
cat("  Análise concluída! Gráficos salvos em ./graficos/\n")
cat("============================================================\n")
