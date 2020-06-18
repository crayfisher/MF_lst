
fn <- "D:/Pawel/modelling/EPA_FPR/LY_EPA_FPR_v6/mf/sens_rerun_final - Copy/closure2/base/mf.lst"

fn <- c("D:/Pawel/modelling/EPA_FPR/LY_EPA_FPR_v6/mf/sens_rerun_final - Copy/closure2/base/mf_ss.lst",
        "D:/Pawel/modelling/EPA_FPR/LY_EPA_FPR_v6/mf/sens_rerun_final - Copy/closure2/null/mf_ss.lst")

fun_get_lst_multi <- function(fn,i){get_lst(fn) %>% 
    mutate(file = fn,
           index = i)}

df <- imap_dfr(fn,fun_get_lst_multi)



df <- get_lst(fn)

df_long <- df %>% 
  pivot_longer(  cols =c(-kper:-time,-file,-index)) %>% 
  mutate(file2 = str_glue("file {index}"))

remove_flag <-
  df_long %>% 
  group_by(name,file,file2,index) %>% 
  summarise(value_min = min(value),
            value_max = max(value)) %>% 
  mutate( remove = ifelse((value_min == 0) & (value_max == 0),
                          0,1))

df_long2 <- left_join(df_long,remove_flag) %>% 
  filter(remove == 1)
  


df_filt <- df_long2 %>% 
    filter(name %in% input$terms )


df_types <- df_long2 %>% 
    distinct(name) %>% 
    mutate(type3 = case_when(str_detect(name,"_IN$")  ~ "IN", 
                             str_detect(name,"_OUT$")  ~ "OUT",
                              TRUE ~ "other"))
df_types




#str_detect(name,"_IN$")
chart <- df_filt %>% 
  ggplot(aes(totim,value,col = name)) +
  geom_line()

