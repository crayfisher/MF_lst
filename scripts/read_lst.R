library(reticulate)
library(tidyverse)
library(lubridate)
library(plotly)


source("flopy_r.R")

add_res <- F
replace <- F


base_fd <- "D:/Pawel/modelling/EPA_FPR/LY_EPA_FPR_v4/R1/mf/"
fn_nam <- "mf.lst"
sims <- c("run fixed rech", "v3_res")
#sims <- list.dirs(base_fd,full.names = F,recursive = F)

file_lst <- str_glue("{base_fd}{sims}/{fn_nam}")
  


#save(df_comb,file ="df_comb.rdata")


if(replace == T){df_comb <- filter(!df_comb,sim %in% sims)}
#save.image()

#Sys.sleep(3600)

for (i in 1:length(sims)){
  file_lst1 <- file_lst[i]
  
  
  df <- get_lst(file_lst1) %>% 
    mutate( sim = sims[i] )
  
  if(i ==1 & add_res != T){df_comb <- df}else{df_comb <- bind_rows(df_comb,df)}
  sim = sims[i]
  print(i)
  print(sim)
  print(file_lst[i])
  
}

#save(df_comb,file = "sim1.rdata")

distinct(df_comb,sim)

df_perc <- df_comb %>%
  dplyr::select(time,totim,kper,time_kstp,PERCENT_DISCREPANCY,sim) %>% 
  mutate(sim2 = str_wrap(sim,width = 20))
chart_perc <- ggplot(df_perc,aes(totim ,PERCENT_DISCREPANCY,col = sim2))+
  geom_line()+
  xlab("Simulation Time (days)")+
  ylab("Percent Discrepancy")+
  facet_wrap(~sim,ncol =1)+
  theme(legend.position="bottom")


chart_perc
ggplotly(chart_perc)

#ggsave("ops_v9 perc_disc.png", width = 7, height = 5) 

start_date <- parse_date_time("1/06/2019","dmy")

df_pump <- df_comb %>% 
  mutate(date = start_date + ddays(totim)   ,
         Q=WELLS_OUT/24/3600*1000,
         sim2 = str_wrap(sim,width = 20)) %>% 
  dplyr::select(kper,  kstp,   totim, date,Q,sim,sim2)
  
#df_pump %>% write_excel_csv("df_pump.csv")
  







#sel <- c("run_R3_e_et07 e3 regQ+comb dig ets lower start sy0.05 cln_ini_bot cln_vol tib CH rech")
sel <- sims
df_pump_sel <- df_pump %>% 
  filter(sim %in% sel) 
# %>% 
  #filter(set == "new") %>% 
  #dplyr::select(-set)
#df_pump_sel %>%  write_excel_csv("df_pump_sel.csv")
# df_pump_sel_wide <- df_pump_sel %>% 
#   pivot_wider(names_from = sim_n,
#               values_from = Q) 
# 
# df_pump_sel_wide %>% 
#   write_excel_csv("df_pump_sel_wide.csv")

chart <- ggplot(df_pump_sel,aes(date,Q,col = factor(sim)))+
  geom_step(size = 1)+
  
  ylab("Brine extraction L/s")+
  xlab("Date")+
  #scale_x_datetime( breaks = "1 month",date_labels = "%b")+
  theme(axis.text.x = element_text(vjust = 0.5))+
  scale_color_discrete(name = "simulation")+
  #ggtitle("Brine extraction predictions during ramp-up period")+
  theme(legend.position = "bottom")+
  #ylim ( c(0,5.5))+
  labs("Simulation")
  #facet_wrap(~set,ncol=1)

chart

#create inteactive plot in plotlty
ggplotly(chart)

ggsave("ops_v9clean_brine production.png", width = 7, height = 5)


save(df_pump,file ="df_pump_v9_clean.rdata")

df_comb2 <- df_comb %>% 
  select(sim,everything()) %>% 
  pivot_longer(-(sim:time),names_to = "name", values_to = "value")

distinct(df_comb2,sim)
terms <- distinct(df_comb2,name)
df_comb2_sel <- df_comb2 %>% 
  filter(name %in%  c("ET_SEGMENTS_OUT","ET_OUT"),
         !is.na(value) )
chart <- df_comb2_sel %>% 
  ggplot(aes(time,value,col = sim))+
  geom_line()+
  facet_wrap(~sim,ncol = 1)
chart
