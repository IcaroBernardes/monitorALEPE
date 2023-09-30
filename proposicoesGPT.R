# 0. Setup inicial ##########
## Carrega bibliotecas
library(cli)
library(dplyr)
library(glue)
library(httr)
library(purrr)
library(stringr)

## Carrega dados das proposições feitas na ALEPE
alepe <- readRDS("data/alepe.RDS")

## Carrega token do chatGPT
apiKey <- "SEUTOKENALFANUMERICO"

## Lista temas a classificar
temas <- c(
  "Educação, Conhecimento e Inovação",
  "Saúde e Qualidade de Vida",
  "Segurança Cidadã",
  "Políticas para Mulheres",
  "Inclusão Social e Direitos Humanos",
  "Cidades Sustentáveis e Resilientes",
  "Zona Rural Mais Forte",
  "Clima e Meio Ambiente",
  "Competitividade e Dinamismo Econômico",
  "Turismo",
  "Cultura e Economia Criativa",
  "Ciência, Tecnologia e Inovação",
  "Gestão, Transparência e Colaboração"
)
temas <- tolower(temas)
temas <- glue::glue_collapse(temas, sep = " | ")

# 1. Consulta ao chatGPT por resumos ##########
## Filtra linhas ainda não resumidas
dados <- alepe |> 
  dplyr::filter(is.na(resumo))

## Define a função que faz a request ao API do chatGPT
asker <- function(texto, delay = 20) {
  
  ### Aguarda por alguns segundos
  Sys.sleep(delay)
  
  ### Limita o número de caracteres do texto
  texto = stringr::str_sub(texto, 1L, 10000L)
  
  ### Define prompt
  prompt = glue::glue("Leia o texto a seguir: {texto}\n\nApresente em um parágrafo, precedido pela expressão 'Resumo: ', um resumo do texto com no máximo 200 caracteres. Em outro parágrafo precedido pela expressão 'Temas: ' apresente uma lista do grau de pertencimento do texto aos temas a seguir: {temas}. Apresente apenas os nomes de dois dos temas com alto grau de pertencimento separados por |.")
  
  ### Efetua a request
  response = httr::POST(
    url = "https://api.openai.com/v1/chat/completions", 
    httr::add_headers(Authorization = paste("Bearer", apiKey)),
    httr::content_type_json(),
    encode = "json",
    body = list(
      model = "gpt-3.5-turbo",
      temperature = 0,
      max_tokens = 300,
      top_p = 1.0,
      frequency_penalty = 0.0,
      presence_penalty = 0.0,
      messages = list(list(
        role = "user", 
        content = prompt
      ))
    )
  )
  
  ### Extrai a resposta obtida
  httr::content(response)$choices[[1]]$message$content
}

## Cria versão segura da função
safeAsker <- purrr::safely(asker)

## Cria lista para guardar os resultados
resultados <- list()

## Define cor de destaque para mensagens de erro
cli::cli_div(theme = list(.red = list(color = 'red')))

## Itera ao longo dos textos da ALEPE
for (doc in seq_along(dados$texto)) {
  
  ### Confirma progresso
  cli::cli_par()
  cli::cli_h1("Resumindo texto #{doc}...")
  
  ### Aplica a função e armazena resultado em lista com algum delay
  resultados[[doc]] = safeAsker(texto = dados$texto[doc],
                                delay = 14)
  
  ### Guarda a url da proposição
  resultados[[doc]]$proposicao_link = dados$proposicao_link[doc]
  
  ### Salva resultados temporários
  saveRDS(resultados, "data/tempAlepe.RDS")
  
  ### Exibe parte da resposta
  previewResumo = stringr::str_trunc(
    resultados[[doc]]$result,
    width = 60, side = "right", ellipsis = "[...]"
  )
  previewResumo = stringr::str_remove(previewResumo, "^Resumo: ")
  previewTemas = stringr::str_split_i(resultados[[doc]]$result, "\n{1,2}", 2)
  previewTemas = stringr::str_remove(previewTemas, "^Temas: ")
  cli::cli_alert("{.strong Parte do resumo:} {previewResumo}")
  if (!purrr::is_empty(previewTemas)) {
    cli::cli_alert("{.strong Temas:} {previewTemas}")
  } else {
    cli::cli_alert_danger("{.red Erro na extração dos temas!}")
  }
  
}

## Guarda os resultados numa tibble e elimina as falhas
dadosFinais <- resultados |> 
  purrr::map(function(resp) {
    dplyr::tibble(
      proposicao_link = resp$proposicao_link,
      addResumo = resp$result
    )
  }) |> 
  purrr::list_rbind() |> 
  dplyr::filter(!is.na(addResumo))

## Une resultados novos e antigos
dados <- dplyr::left_join(alepe, dadosFinais) |> 
  dplyr::mutate(resumo = ifelse(is.na(resumo), addResumo, resumo)) |> 
  dplyr::select(-addResumo)

## Salva como .csv e .RDS
saveRDS(dados, "data/alepe.RDS")
readr::write_csv(dados, "data/alepe.csv")
