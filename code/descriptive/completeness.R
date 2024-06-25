
library(dplyr)
library(tidyr)

# completeness table

# Calculate the percentage of non-missing data for each column
non_missing_percentage <- data_prep %>%
  summarise_all(~round(sum(!is.na(.))/n()*100),2) %>% 
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Completeness")

write.csv(non_missing_percentage,"output/summary/completeness.csv")


non_missing_percentage <- data_prep %>%
  filter(ebike == "Yes") %>% 
  summarise_all(~round(sum(!is.na(.))/n()*100),2) %>% 
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Completeness")

non_missing_percentage

write.csv(non_missing_percentage,"output/summary/completeness.csv")