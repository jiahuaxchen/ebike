library(dplyr)

ebike_na <- data_prep %>% 
  filter(ebike=="Yes") %>% 
  rowwise() %>%
  mutate(na_count = sum(is.na(across(everything()))))

hist(ebike_na$na_count)

ebike_drop50NA <- data_prep %>% 
  filter(ebike=="Yes") %>% 
  rowwise() %>%
  mutate(na_count = sum(is.na(across(everything())))) %>%
  filter(na_count < 12) 

library(naniar)  

vis_miss(ebike_drop50NA)
