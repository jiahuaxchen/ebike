# install packages
install.packages("quanteda")
install.packages("igraph")
install.packages("quanteda.textplots") 

library(quanteda)
library(quanteda.textplots)
library(igraph)
library(widyr)
library(tidygraph)
conflicted::conflicts_prefer(quanteda::stopwords)
conflicted::conflicts_prefer(igraph::degree)

data_ebike <- data %>% 
  filter(ebike == "Yes")%>% 
  dplyr::select(index, details)
data_pedal <- data %>% 
  filter(ebike == "No")%>% 
  dplyr::select(index, details)

ebike_corpus <- corpus(data_ebike$details)
pedal_corpus <- corpus(data_pedal$details)

# Preprocess the Ebike corpus
ebike_tokens <- tokens(ebike_corpus,
                       remove_punct = TRUE,
                       remove_symbols = TRUE,
                       remove_numbers = TRUE) %>%
  tokens_wordstem() %>%
  tokens_tolower() %>%
  tokens_remove(stopwords("en"))
# Create a document-feature matrix
ebike_dfm <- dfm(ebike_tokens)

# Identify top 50 keywords
top_keywords <- names(topfeatures(ebike_dfm, n = 50))
# Filter tokens to keep only the top keywords
ebike_tokens_top <- tokens_select(ebike_tokens, pattern = top_keywords, selection = "keep")

# Create the co-occurrence matrix
ebike_cooccurrence <- fcm(ebike_tokens_top, context = "window", window = 5)

options(ggrepel.max.overlaps = Inf)
ebike_fcm_30 <- fcm_select(ebike_cooccurrence, pattern = top_keywords)
# Convert the fcm object to an adjacency matrix
adj_matrix <- as.matrix(ebike_fcm_30)
# Create an igraph object from the adjacency matrix
graph <- graph_from_adjacency_matrix(adj_matrix, mode = "undirected", weighted = TRUE, diag = FALSE)
# Compute degree centrality
degree_centrality <- degree(graph)

textplot_network(ebike_fcm_30,
                 #min_freq = 0.5,
                 vertex_labelsize = 0.1*rowSums(ebike_fcm_30)/min(rowSums(ebike_fcm_30)))



#------------------------------------
# Preprocess the Pedal corpus
pedal_tokens <- tokens(pedal_corpus,
                       remove_punct = TRUE,
                       remove_symbols = TRUE,
                       remove_numbers = TRUE) %>%
  tokens_tolower() %>%
  tokens_wordstem() %>%
  tokens_remove(stopwords("en"))

# Create a document-feature matrix
pedal_dfm <- dfm(pedal_tokens)

# Identify top 50 keywords
top_keywords <- names(topfeatures(pedal_dfm, n = 50))
# Filter tokens to keep only the top keywords
pedal_tokens_top <- tokens_select(pedal_tokens, pattern = top_keywords, selection = "keep")

# Create the co-occurrence matrix
pedal_cooccurrence <- fcm(pedal_tokens_top, context = "window", window = 5)

pedal_fcm_30 <- fcm_select(pedal_cooccurrence, pattern = top_keywords)
# Convert the fcm object to an adjacency matrix
adj_matrix <- as.matrix(pedal_fcm_30)
# Create an igraph object from the adjacency matrix
graph <- graph_from_adjacency_matrix(adj_matrix, mode = "undirected", weighted = TRUE, diag = FALSE)
# Compute degree centrality
degree_centrality <- degree(graph)

fcm_select(pedal_cooccurrence, pattern = top_keywords) %>%
  textplot_network(min_freq = 0.2,
                   vertex_size = 0.1*degree_centrality)

