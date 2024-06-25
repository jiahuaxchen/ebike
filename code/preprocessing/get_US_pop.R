


census_api_key("f66d60e3dba0f71ea1155716f84a314391139d8f", install = TRUE)
options(tigris_use_cache = TRUE)

options(tigris_cache_dir = "code")

p1_2020 <- load_variables(2020, "pl", cache = TRUE)
View(p1_2020)

states <- state.abb  # Built-in R dataset containing state abbreviations

#remove states that has no bike incident reports
updated_states <- states[!states %in% c("ME", "MS","NH","ND","OK","WY","NY")]

state <- "NY"  # Example with New York

blocks_data <- get_decennial(
  geography = "block",
  variables = "P1_001N",
  year = 2020,
  state = state,
  geometry = TRUE
)

if (exists("blocks_data")) {
  saveRDS(blocks_data, file = paste0(getwd(), "/RDA/blocks_data_", state, ".rds"))
  print(paste("Data saved for", state))
} else {
  print(paste("No data retrieved for", state))
}

# for all states

for (state in states) {
  print(paste("Processing:", state))
  # Attempt to download block data for each state
  blocks_data <- get_decennial(
    geography = "block",
    variables = "P1_001N",  # Total population
    year = 2020,
    state = state,
    geometry = TRUE
  )
  if (exists("blocks_data")) {
    saveRDS(blocks_data, file = paste0(getwd(), "/RDA/blocks_data_", state, ".rds"))
    print(paste("Data saved for", state))
  } else {
    print(paste("No data retrieved for", state))
  }
}
