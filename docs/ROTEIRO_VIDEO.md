# 🎬 ROTEIRO DO VÍDEO — FarmTech Solutions Fase 2
**Aluno:** Kauan Maciel Forgiarini | RM 574005  
**Duração máxima:** 5 minutos  
**Plataforma:** YouTube (sem listagem)

---

## ⏱️ ESTRUTURA GERAL

| Parte | Tempo        | Conteúdo                                 |
|-------|-------------|------------------------------------------|
| 1     | 0:00 – 0:30 | Apresentação e introdução ao projeto     |
| 2     | 0:30 – 1:30 | Circuito no Wokwi — componentes          |
| 3     | 1:30 – 3:00 | Demonstração ao vivo dos sensores        |
| 4     | 3:00 – 4:00 | Script Python + API OpenWeather          |
| 5     | 4:00 – 4:45 | Análise em R — gráficos e regressão      |
| 6     | 4:45 – 5:00 | Encerramento                             |

---

## 🎙️ PARTE 1 — APRESENTAÇÃO (0:00 – 0:30)

**O QUE MOSTRAR:**  
Tela do GitHub do projeto aberta, ou uma slide simples com o nome do projeto.

**O QUE FALAR:**  
> "Olá! Me chamo Kauan Maciel Forgiarini, RM 574005. Neste vídeo vou demonstrar o projeto da Fase 2 da FarmTech Solutions: um sistema de irrigação inteligente para lavoura de soja, desenvolvido na disciplina de Inteligência Artificial da FIAP.
>
> O sistema combina um circuito ESP32 simulado no Wokwi, com integração Python via API OpenWeatherMap e análise estatística em R. Vamos lá!"

---

## 🎙️ PARTE 2 — CIRCUITO NO WOKWI (0:30 – 1:30)

**O QUE ABRIR:**  
Navegador com o projeto no Wokwi.com aberto. O circuito deve estar **montado e pausado** (ainda não rodando).

**O QUE MOSTRAR E FALAR:**  
Aponte o cursor para cada componente enquanto fala:

> "Aqui está o circuito montado no Wokwi. Vou apresentar rapidamente cada componente:
>
> — O **ESP32** é o microcontrolador central, o cérebro do sistema.  
>
> — Esses **três botões verdes** representam os níveis de nutrientes: Nitrogênio, Fósforo e Potássio — o famoso NPK. Quando pressionado, indica que o nutriente está presente.
>
> — O sensor **LDR**, aqui, está sendo utilizado como simulação do pH do solo. Quanto mais luz recebe, maior o valor analógico lido, que mapeamos para uma escala de pH de 0 a 14.
>
> — O **DHT22** simula o sensor de umidade do solo. Na prática ele mede umidade do ar, mas para fins didáticos, usamos como umidade do solo.
>
> — O **relé azul** representa a bomba d'água. Quando ativado, a irrigação está funcionando.
>
> — E os **LEDs** verde e vermelho indicam visualmente se a bomba está ligada ou desligada."

---

## 🎙️ PARTE 3 — DEMONSTRAÇÃO DOS SENSORES (1:30 – 3:00)

**O QUE FAZER:**  
Clique em **▶ Play** para iniciar a simulação. Abra o **Monitor Serial** (ícone no canto inferior direito do Wokwi).

**O QUE MOSTRAR E FALAR:**

> "Vou iniciar a simulação agora."

*[Clique em Play]*

> "O Monitor Serial está exibindo as leituras em tempo real. Observem as informações: valores de NPK, pH, umidade, temperatura e o status da bomba."

**Cenário 1 — Sem nutrientes, umidade baixa → Não deve irrigar:**

> "Inicialmente os botões estão soltos — ou seja, sem nutrientes detectados. Mesmo com umidade baixa, o sistema decide NÃO irrigar pois P e K estão ausentes."

*[Mostre o Monitor Serial com 'Bomba: DESLIGADA']*

**Cenário 2 — Com P e K pressionados, umidade baixa → Deve irrigar:**

> "Agora vou pressionar os botões de Fósforo e Potássio, simulando que esses nutrientes estão presentes no solo."

*[Pressione BTN P e BTN K ao mesmo tempo no Wokwi]*

> "Vejam! Com P e K presentes e umidade abaixo de 60%, o sistema ativou a bomba. O LED verde acendeu e o relé foi acionado."

*[Mostre o LED verde aceso e 'Bomba: LIGADA' no serial]*

**Cenário 3 — Ajustando o LDR para pH fora do ideal:**

> "Agora vou simular um pH muito ácido, movendo o LDR para receber menos luz."

*[Arraste o slider de luz do LDR para o mínimo]*

> "O pH caiu para menos de 5.0. O sistema identificou o pH fora da faixa ideal para a soja e desligou a bomba — emitindo um alerta no serial."

**Cenário 4 — Chuva prevista via Serial:**

> "Por fim, vou simular a chegada de uma previsão de chuva do script Python. Vou digitar '1' aqui no Monitor Serial."

*[Digite '1' no campo de input do Monitor Serial do Wokwi e pressione Enter]*

> "Perfeito! O sistema recebeu a informação de chuva prevista e imediatamente suspendeu a irrigação para economizar água."

---

## 🎙️ PARTE 4 — SCRIPT PYTHON + API (3:00 – 4:00)

**O QUE ABRIR:**  
VS Code ou terminal com o script `farmtech_api.py` visível. Em outra aba/janela, mostre o arquivo `farmtech_historico.csv` sendo gerado.

**O QUE MOSTRAR E FALAR:**

> "Aqui está o script Python que integra o sistema ao mundo real. Ele consulta a API OpenWeatherMap a cada 5 minutos para verificar a previsão de chuva."

*[Role o código até a função `obter_previsao_chuva()`]*

> "Essa função faz a chamada HTTP para a API, busca as próximas 3 horas de previsão e verifica se há volume de chuva acima de 1mm — que é nosso limiar para suspender a irrigação."

*[Execute o script: `python farmtech_api.py`]*

> "Ao executar, o script entra em modo de monitoramento contínuo. Ele exibe este dashboard no terminal com todas as informações consolidadas: dados do solo vindos do ESP32 e previsão climática da API."

*[Mostre o dashboard sendo exibido no terminal]*

> "E aqui — deixa eu abrir o CSV — o histórico de todas as leituras está sendo gravado automaticamente, com timestamp, todos os parâmetros e a decisão tomada. Esses dados serão usados na análise em R."

*[Abra o `farmtech_historico.csv` no Excel ou VSCode]*

---

## 🎙️ PARTE 5 — ANÁLISE EM R (4:00 – 4:45)

**O QUE ABRIR:**  
RStudio com o script `farmtech_analise.R` aberto. Mostre o console enquanto executa.

**O QUE MOSTRAR E FALAR:**

> "No módulo de análise de dados, utilizamos R para extrair insights do histórico coletado."

*[Execute o script com `source("farmtech_analise.R")` ou clique em Source]*

> "O script calcula estatísticas descritivas como média, mediana e desvio padrão da umidade, temperatura e pH. Vejam que a média de umidade ficou em torno de 62%, indicando que o solo frequentemente está na faixa de atenção."

*[Mostre o output do `summary()` no console]*

> "Em seguida, geramos gráficos automáticos. Este histograma mostra a distribuição da umidade separada por status da bomba — fica claro que irrigações ocorrem concentradas abaixo de 60%."

*[Abra o arquivo `graficos/01_umidade_bomba.png`]*

> "Este scatter plot de pH versus umidade com os limites tracejados é excelente para visualizar onde estão as leituras ideais para a soja."

*[Abra o arquivo `graficos/02_ph_umidade_scatter.png`]*

> "Por fim, treinamos um modelo de **Regressão Logística** com 80% dos dados e testamos nos 20% restantes. O modelo atingiu alta acurácia na previsão de quando ativar a bomba — confirmando que nossa lógica de negócio está bem definida."

*[Mostre o output da matriz de confusão no console]*

---

## 🎙️ PARTE 6 — ENCERRAMENTO (4:45 – 5:00)

**O QUE MOSTRAR:**  
Volte para a tela do GitHub com o repositório organizado.

**O QUE FALAR:**

> "O projeto está disponível no GitHub com toda a documentação: código do ESP32, script Python, análise em R e este README detalhado. O link está na descrição do vídeo.
>
> A FarmTech Solutions demonstrou como IoT, integração de APIs e Data Science podem trabalhar juntos para tornar a irrigação agrícola mais eficiente e inteligente — economizando água e aumentando a produtividade da lavoura de soja.
>
> Obrigado pela atenção! Kauan Maciel Forgiarini, RM 574005."

---

## 🎬 DICAS TÉCNICAS PARA A GRAVAÇÃO

- **Software sugerido:** OBS Studio (gratuito) para captura de tela
- **Resolução:** 1920×1080 (Full HD)
- **Microfone:** Use fone com microfone para melhor qualidade de áudio
- **Janelas abertas antes de gravar:**
  1. Navegador com Wokwi.com (circuito pronto)
  2. VS Code com `farmtech_api.py`
  3. Terminal pronto para rodar o Python
  4. RStudio com `farmtech_analise.R`
  5. Explorador de arquivos com a pasta `graficos/`
  6. GitHub do projeto
- **Ensaie uma vez** antes de gravar para garantir que cabe em 5 minutos
- **Não feche o Monitor Serial** do Wokwi durante a demonstração — ele é visual importante
- **Deixe o CSV pré-gerado** com alguns dados para não precisar esperar durante a gravação
