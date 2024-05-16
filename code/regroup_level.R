regroup <- function(data){

  #install.packages("forcats")
  library(forcats)
  
  data <- data %>% 
    mutate_if(is.character,as.factor)

  #regroup predictors
  #multiple choice for gender, so as long as F is chosen will be grouped into F, same for M
  gender_levels <- factor(data$gender)
  data <- data %>% 
    mutate(gender = fct_collapse(gender, 
                                 "F" = grep("F", levels(gender_levels), value = TRUE),
                                 "M"=grep("M", levels(gender_levels), value = TRUE),
                                 "Unknown"="[]",other_level = "Other"))
  
  data <- data %>% 
    mutate(injury3 = fct_collapse(injury,A=c("No injury"),
                                       B=c("Injury, no treatment"),
                                       C=c("Injury, hospitalized","Injury, saw family doctor","Injury, hospital emergency visit"),
                                       Unknown=c("Unknown"),
                                       level=c("A","B","C"))) %>% 
    mutate(injury2 = as.factor((injury3!="A"))) %>% 
    # lump incidents with vehicles
    mutate(incident_with = fct_collapse(incident_with, vehicle = 
                                          c("Vehicle, turning right",
                                            "Vehicle, head on",
                                            "Vehicle, passing",
                                            "Vehicle, turning left",
                                            "Vehicle, angle",
                                            "Vehicle, rear end",
                                            "Vehicle, side",
                                            "Vehicle, open door"),
                                        bicyclist = "Another cyclist",
                                        pedestrian = "Pedestrian",
                                        other_level = "other")) %>% 
    mutate(i_type = fct_collapse(i_type, 
                                 near_collison = c("Near collision with moving object or vehicle",
                                                    "Near collision with stationary object or vehicle"),
                                 collison_fall= c("Collision with moving object or vehicle",
                                              "Collision with stationary object or vehicle",
                                              "Fall")))
  
  # summary(data3$gender) 
  # the factor label can't not be the same as the level
  
  #convert data into NA
  values_to_convert <- c("I don't know", "Don't remember",  "Don't Remember","I don't remember","Unknown")
  
  # Use dplyr to convert values to NA in the entire dataset
  data <- data %>%
    mutate_if(is.factor, ~replace(., . %in% values_to_convert, NA)) %>% 
    mutate(across(where(is.factor), ~fct_drop(.))) %>% #drop the changed factors
    drop_na(injury3) #drop NAs in the outcome variable
  
  #reorder factor level by frequency (start with most frequent)
  data <- data %>%
    mutate_if(is.factor,~fct_infreq(.))
  data$injury3 <- factor(data$injury3, levels=c('A', 'B', 'C')) 
  
  return (data)
}