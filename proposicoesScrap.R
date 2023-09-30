# 0. Setup inicial ##########
## Carrega bibliotecas
library(cli)
library(dplyr)
library(glue)
library(httr)
library(lubridate)
library(purrr)
library(readr)
library(rvest)
library(stringr)

## Define url base
url_base <- "https://www.alepe.pe.gov.br/proposicoes/"

## Lê dados já obtidos do portal da ALEPE
alepe <- readRDS("data/alepe.RDS")

# 1. Criação dos scrappers ##########
## Cria uma função para realizar o scrap
## dos dados das proposições a cada página
scrapper_main <- function(pag) {
  
  ### Aguarda 2s
  Sys.sleep(2)
  
  ### Comunica progresso
  cli::cli_inform("Extraindo página #{pag}...")
  
  ### Faz requisição para a página
  resp = httr::POST(url = url_base,
                    body = list(pagina = pag),
                    encode = "form")
  
  ### Extrai o conteúdo da requisição
  page = httr::content(resp)
  
  ### Obtém o autor da proposição
  autor = page |> 
    rvest::html_elements(xpath = "//td[1]") |> 
    rvest::html_text()
  
  ### Obtém a id da proposição
  proposicao = page |> 
    rvest::html_elements(xpath = "//td[2]") |> 
    rvest::html_text()
  
  ### Obtém link para a proposição
  proposicao_link = page |> 
    rvest::html_elements(xpath = "//td/a") |> 
    rvest::html_attr("href")
  proposicao_link = glue::glue("https://www.alepe.pe.gov.br{proposicao_link}")
  
  ### Obtém data da proposição
  data = page |> 
    rvest::html_elements(xpath = "//td[3]") |> 
    rvest::html_text()
  
  ### Gera a tibble
  dplyr::tibble(
    autor = autor,
    proposicao = proposicao,
    proposicao_link = proposicao_link,
    data = data
  )
  
}
safe_scrapper_main <- try(scrapper_main)

## Cria uma função para realizar o
## scrap dos textos de cada proposição
scrapper_text <- function(link, text) {
  
  ### Aguarda 1s
  Sys.sleep(1)
  
  ### Comunica progresso
  cli::cli_inform("Extraindo texto #{text}...")
  
  ### Obtém texto da proposição
  text = link |> 
    rvest::read_html() |> 
    rvest::html_elements(xpath = "//article/div/div[2]/div[2]") |> 
    rvest::html_text2() |> 
    stringr::str_squish()
  
}
safe_scrapper_text <- purrr::safely(scrapper_text)

# 2. Execução dos scrappers ##########
## Inicializa lista para conter os conteúdos
dados <- list()

## Inicializa contador de páginas
pagina <- 0

## Obtém a data mais recente de coleta já efetuada
past <- alepe |> 
  dplyr::pull(data) |> 
  max()

## Inicializa verificador de proposições já obtidas
existeNovos <- TRUE

## Executa o scrap dos dados sobre as proposições
## até encontrar uma página com proposições já obtidas
cli::cli_h1("Extração de páginas")
while (existeNovos) {
  
  ### Itera sobre a página
  pagina = pagina + 1
  
  ### Aplica a função de scrap
  extraido = safe_scrapper_main(pagina)
  
  ### Confirma que extração ocorreu com sucesso
  if ("try-error" %in% class(extraido)) {
    
    cli::cli_warn("Erro na página {pagina}")
    
  } else {
    
    ### Converte datas
    extraido = extraido |> 
      dplyr::mutate(data = lubridate::dmy(data))
    
    ### Verifica se já foi atingida a data anterior
    ### à mais recente dentre as proposições já coletadas
    existeNovos = extraido |> 
      dplyr::pull(data) |> 
      min()
    existeNovos = as.numeric(past - existeNovos) < 2
    
    ### Insere resultados na lista
    dados[[pagina]] = extraido
    
  }
  
}

## Converte os resultados a uma única tibble
dados <- purrr::list_rbind(dados)

## Lista resultados já obtidos
priori <- alepe |> 
  dplyr::pull(proposicao)

## Elimina resultados já obtidos
dados <- dados |> 
  dplyr::filter(!(proposicao %in% priori))

## Elimina possíveis duplicatas
dados <- dados |> 
  dplyr::arrange(desc(data), desc(proposicao_link), desc(proposicao), desc(autor)) |> 
  dplyr::distinct(proposicao_link, .keep_all = TRUE)

## Executa o scrap dos textos das proposições
cli::cli_h1("Extração de textos")
texto <- dados$proposicao_link |> 
  purrr::imap(safe_scrapper_text) |> 
  purrr::map(~.$result) |> 
  purrr::map_if(~is.null(.), ~NA) |>
  purrr::map_chr(~.)

## Guarda os resultados na tibble
dados <- dados |>  
  dplyr::mutate(texto = texto)

## Adiciona coluna com NA's para o resumo
dados <- dados |>  
  dplyr::mutate(resumo = NA)

## Adequa texto e resumo dos documentos de "Redação Final"
dados <- dados |>  
  dplyr::mutate(
    across(
      .cols = c(texto, resumo),
      .fns = ~ifelse(
        autor == "Redação Final",
        "Documentos da Redação Final não costumam apresentar texto.",
        .
      )
    )
  )

## Une resultados novos e antigos
dados <- dplyr::bind_rows(dados, alepe)

## Salva como .csv e .RDS
saveRDS(dados, "data/alepe.RDS")
readr::write_csv(dados, "data/alepe.csv")
