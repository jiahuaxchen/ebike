calculate_age <- function(data){
  df_age <- data %>% 
    mutate(age = as.numeric(age)) %>% 
    mutate(birthmonth = as.numeric(birthmonth)) %>% 
    #impute month = January (1) for NAs
    mutate(month_imp = case_when(!is.na(age)&is.na(birthmonth) ~ 1,!is.na(birthmonth) ~ birthmonth)) %>%
    #combine year and month
    mutate(date = as.character(with(., sprintf("%d-%02d", age, month_imp)))) %>%
    #add date (1) to the year-month
    mutate(date_imp = ifelse(is.na(age), as.integer(NA), paste(date, "-01", sep=""))) 
  
  # turn into date format
  df_age$date_imp <- as.Date(df_age$date_imp)
  
  # calculate age from born date to report date
  age_func <- function(dob, age.day, units = "years", floor = TRUE) {
    calc.age = lubridate::interval(dob, age.day) / lubridate::duration(num = 1, units = units)
    if (floor) return(as.integer(floor(calc.age)))
    return(calc.age)
  }
  
  df_age$age_imp <- age_func(df_age$date_imp,
                             df_age$report_date)
  
  # put in age group
  df_age <- df_age %>% 
    mutate(age_group = case_when(
      age_imp <= 12            ~ "0-12",
      age_imp > 13 & age_imp <= 17 ~ "13-17",
      age_imp > 18 & age_imp <= 24 ~ "18-24",
      age_imp > 25 & age_imp <= 34 ~ "25-34",
      age_imp > 35 & age_imp <= 44 ~ "35-44",
      age_imp > 45 & age_imp <= 54 ~ "45-54",
      age_imp > 55 & age_imp <= 64 ~ "55-64",
      age_imp > 65 & age_imp <= 74 ~ "65-74",
      age_imp > 75            ~ "75+"
    ),
    age_group = as.factor(age_group)) %>% 
    mutate(age_group=fct_relevel(age_group,c("0-12","13-17","18-24","25-34","35-44","45-54","55-64","65-74","75+")))
  
  data$age_group <- df_age$age_group
  data$age_imp <- df_age$age_imp
  
  return (data)
}