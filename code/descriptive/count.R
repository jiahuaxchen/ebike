library(dplyr)
library(naniar)

world <- X20240620world %>% 
  dplyr::filter(date > as.Date('2016-11-30')) %>% 
  dplyr::filter(report_date < as.Date('2024-04-26')) 

data <- rbind(readßxl::read_excel("data/20240425Canada.xlsx"),
              readxl::read_excel("data/20240425United States.xlsx"))

Canada <- readxl::read_excel("data/20240425Canada.xlsx") %>% 
  dplyr::filter(date > as.Date('2016-11-30'))
US <- readxl::read_excel("data/20240425United States.xlsx") %>% 
  dplyr::filter(date > as.Date('2016-11-30'))

US_Can <- data %>% 
  dplyr::filter(date > as.Date('2016-11-30')) %>% # n=5013
  dplyr::filter(!is.na(ebike)) %>% # n=3820
  dplyr::filter(!is.na(injury)) %>%  #didn't change sample size
  dplyr::filter(personal_involvement=="Yes") %>% 
  dplyr::filter(ebike=="Yes")

US_Can <- data %>% 
  dplyr::filter(date > as.Date('2016-11-30')) %>% # n=5013
  dplyr::filter(!is.na(injury)) %>%  #didn't change sample size
  dplyr::filter(personal_involvement=="Yes") %>% 
  dplyr::filter(ebike=="Yes")

US_Can <- data %>% 
  dplyr::filter(date > as.Date('2016-11-30')) %>% 
  dplyr::filter(ebike =="Yes")  # n=3820
  

vis_miss(US_Can)

range(as.Date(US_Can$date))

