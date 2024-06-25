impute <- function(data){
  
  # check if the factor variables in the dataframe have more than one level, 
  # if not, drop the variable
  
  data_recipe_all <- recipe(injury2 ~ . , data = data) %>%
    step_impute_bag(all_predictors())
  
  all_imputed <- 
    prep(data_recipe_all) %>% bake(new_data = data)
  
  return (all_imputed)
}