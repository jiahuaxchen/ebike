data4 <- data1 %>% 
  mutate_if(is.character,as.factor) %>% 
  mutate(injury_level = fct_collapse(injury,'No injury'=c("No injury"),
                                     'Injury no treatment'=c("Injury, no treatment"),
                                     'Injury with treatment'=c("Injury, hospitalized","Injury, saw family doctor","Injury, hospital emergency visit"),
                                     'Unknown'=c("Unknown"),
                                     level=c("A","B","C")))%>%
  mutate(injury_level = factor(injury_level, levels=c('No injury', 'Injury no treatment', 'Injury with treatment'))) %>% 
  mutate(ebike_speed = factor(ebike_speed, levels=c('Under 5 mph', 'Between 5-20 mph', 'Over 20 mph')))

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
