# Monitor ALEPE

## Acesso 🔗
App: http://projesp.seplag.pe.gov.br/apps/alepe/

![image](https://github.com/IcaroBernardes/monitorALEPE/assets/7217965/96b39b1e-f4fa-4604-9bd1-ff7fecad2f90)

## O que é ❓
Painel que facilita o acesso aos debates de interesse na Assembléia Legislativa de Pernambuco (ALEPE).

A contrução do painel consistiu nas seguintes etapas:
- extração automatizada das proposições da Assembléia Legislativa do Estado de Pernambuco - ALEPE;
- uso da API do ChatGPT para classificar automaticamente tais proposições de acordo com os eixos prioritários do governo de Pernambuco;
- criação de uma plataforma em R/Shiny com os dados obtidos.

## Estrutura do repositório 🗃️
- Dados que alimentam o app: [data/alepe.csv](https://github.com/IcaroBernardes/monitorALEPE/blob/main/data/alepe.csv);
- Código para scrap dos dados e textos das proposições da ALEPE: [scripts/scrapper_alepe.R](https://github.com/IcaroBernardes/monitorALEPE/blob/main/proposicoesScrap.R);
- Código para produção de resumo e extração de temas através do chatGPT: [scripts/chatGPT.R](https://github.com/IcaroBernardes/monitorALEPE/blob/main/scripts/proposicoesGPT.R).

## Submissão de artigo
Esse trabalho foi submetido ao 16º CONGRESSO DE GESTÃO PÚBLICA DO RIO GRANDE DO NORTE (CONGESP) com o nome **MONITOR ALEPE: SOLUCIONANDO PROBLEMAS DE CLASSIFICAÇÃO COM USO DE INTELIGÊNCIA ARTIFICIAL**

![image](https://github.com/IcaroBernardes/monitorALEPE/assets/7217965/1cd0369d-2e45-455b-8857-efd255cc0f7c)
