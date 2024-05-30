data4 <- data3 %>%
  dplyr::filter(!is.na(ebike_speed)) %>% 
  dplyr::select(-c(report_date,details,impact,pk,direction,x,y,injury,infrastructure_changed,geometry)) %>%
  #drop all column with more than 50% missing
  purrr::discard(~sum(is.na(.x))/length(.x)* 100 >=50) %>% 
  #mutate(injury_level = factor(injury_level, levels=c('No injury', 'Injury no treatment', 'Injury with treatment'))) %>% 
  mutate(ebike_speed = factor(ebike_speed, levels=c('Under 5 mph', 'Between 5-20 mph', 'Over 20 mph')))

vis_miss(data3)
vis_miss(data4)

summary(data4$injury_level)

data4 %>% 
  dplyr::filter(!is.na(ebike_speed)) %>%
  ggplot(aes(ebike_speed,fill=injury_level)) + 
  geom_bar(position="fill") #+
  #scale_x_discrete(guide = guide_axis(n.dodge=2))

data4 %>% 
  dplyr::filter(!is.na(ebike_speed)) %>%
  ggplot(aes(ebike_speed,fill=injury_level)) + 
  geom_histogram(stat = "count") #+
  #scale_x_discrete(guide = guide_axis(n.dodge=2))


# binary
data5 <- data4 %>%
  dplyr::filter(!is.na(ebike_speed)) %>% 
  #drop all column with more than 50% missing
  purrr::discard(~sum(is.na(.x))/length(.x)* 100 >=50) 
summary(data5)
  

