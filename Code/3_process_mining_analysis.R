#---------------------------------------------------------------------------------------------------------------------------
#Process Analysis
#---------------------------------------------------------------------------------------------------------------------------
#Read in cleaned data which is in event log form and has been enriched with attributes

hip_pathway <- readRDS( "hip_pathway_enriched.rds")
#---------------------------------------------------------------------------------------------------------------------------
#Libraries (mainly from BupaR suite of packages)
#---------------------------------------------------------------------------------------------------------------------------
library(bupaR)
library(eventdataR)
library(xesreadR)
library(edeaR)
library(processmapR)
library(processmonitR)
library(processanimateR)
library(processcheckR)

library(tableone)
library(dplyr)
library(plyr)
library(ggplot2)
library(svgPanZoom)
library(DiagrammeRsvg)
#---------------------------------------------------------------------------------------------------------------------------
#Iterative cleaning steps for community data with similar service names
#---------------------------------------------------------------------------------------------------------------------------
hip_pathway %>% 
   mutate(activity = replace(activity, 
                            activity=="community_district nursing service; long term conditions case management service; musculoskeletal service", "community_musculoskeletal service")) %>% 
  mutate(activity = replace(activity, 
                            activity=="community_district nursing service; podiatry service", "community_podiatry service")) -> hip_pathway

#---------------------------------------------------------------------------------------------------------------------------
#Create as an eventlog format
#---------------------------------------------------------------------------------------------------------------------------

hip_pathway %>% #a data.frame with the information in the table above
  eventlog(
    case_id = "Pseudo_NHS_Number",
    activity_id = "activity",
    activity_instance_id = "activity_instance",
    lifecycle_id = "status",
    timestamp = "timestamp",
    resource_id = "resource"
  ) -> hip_log

#---------------------------------------------------------------------------------------------------------------------------
#Summarise eventlog
#---------------------------------------------------------------------------------------------------------------------------
hip_log

hip_log %>%
  filter_activity(selected_activity) 

str(hip_log)

#---------------------------------------------------------------------------------------------------------------------------
#Activity Frequency and Activity Presence
#---------------------------------------------------------------------------------------------------------------------------

hip_log %>% activity_presence() %>% plot()

hip_log %>% activity_frequency(level = "activity") %>% plot()


hip_log %>% activity_frequency(level = "activity") %>% View()

hip_log %>% activity_frequency(level = "activity") %>% 
  as.data.frame()-> activities


setwd("")
write.csv(activities, "activities.csv")

#---------------------------------------------------------------------------------------------------------------------------
#Selecting specific activities
#---------------------------------------------------------------------------------------------------------------------------

selected_activity<- c("APPT_made",
                       "community_musculoskeletal service",
                       "community_physiotherapy service",
                       "elec_hip_replace",
                       "GP_refers_for_hip",
                       "OP_anaesthetic service",
                       "OP_diagnostic imaging service",
                       "OP_pain management service",
                       "OP_physiotherapy service",
                       "OP_trauma and orthopaedic service",
                       "primary_care_analgesic",
                       "primarycare_msk",
                       "OP_rheumatology service",
                       "AE")

hip_log %>%
  filter_activity(selected_activity) %>% 
  activity_frequency(level = "activity") %>% 
  plot()

hip_log %>% 
  filter_activity(selected_activity) %>% 
  activity_frequency(level = "activity") %>% 
  as.data.frame()-> activities2

write.csv(activities2, "activities2.csv")
#---------------------------------------------------------------------------------------------------------------------------
#Summary Statistics for reduced activities
#---------------------------------------------------------------------------------------------------------------------------
hip_log %>%
  filter_activity(selected_activity)

hip_log %>% filter_activity(selected_activity) %>% throughput_time()

hip_log %>% filter_activity(selected_activity) %>% trace_length()
#---------------------------------------------------------------------------------------------------------------------------
#Trace Coverage
#The trace coverage metric shows the relationship between the number of 
#different activity sequences (i.e. traces) and the number of cases they cover.

hip_log %>%
  filter_activity(selected_activity) %>% 
  trace_coverage("trace") %>%
  plot()

#Trace Explorer
#Cover a fixed number of traces
hip_log %>% 
filter_activity(selected_activity) %>% 
  processmapR::trace_explorer(n_traces=30) 


#Explorer will stop when it reaches a cumulative coverage of 70% or more.
#Default set at a low coverage due to expectation of unstructured data

hip_log %>%
  filter_activity(selected_activity) %>% 
  processmapR::trace_explorer(coverage=0.7) 
#---------------------------------------------------------------------------------------------------------------------------
#Dotted Chart

hip_log %>% 
  filter_activity(selected_activity) %>% 
  dotted_chart()

#---------------------------------------------------------------------------------------------------------------------------
#Cohort summary
#---------------------------------------------------------------------------------------------------------------------------
hip_pathway %>% 
  distinct(Pseudo_NHS_Number, .keep_all = T) ->tblonedf

myVars <- c("sex", "smoking", "qof_af", 
            "qof_chd", "qof_hf", "qof_ht", "qof_pad", "qof_stroke", "qof_asthma", 
            "qof_copd", "qof_obesity", "qof_cancer", "qof_ckd", "qof_diabetes", 
            "qof_pall", "qof_dementia", "qof_depression", "qof_epilepsy", 
            "qof_learndis", "qof_mental", "qof_osteoporosis", "qof_rheumarth", 
            "hearing_impair", "visual_impair", "phys_disability", 
            "PATIENT_AGE", "age_group", "ethnicgroup")

## Vector of categorical variables that need transformation
catVars <- c("sex", "smoking", "qof_af", 
             "qof_chd", "qof_hf", "qof_ht", "qof_pad", "qof_stroke", "qof_asthma", 
             "qof_copd", "qof_obesity", "qof_cancer", "qof_ckd", "qof_diabetes", 
             "qof_pall", "qof_dementia", "qof_depression", "qof_epilepsy", 
             "qof_learndis", "qof_mental", "qof_osteoporosis", "qof_rheumarth", 
             "hearing_impair", "visual_impair", "phys_disability", 
             "age_group", "ethnicgroup")

## Create a TableOne object
tab2 <- CreateTableOne(vars = myVars, data = tblonedf, factorVars = catVars)

tab3Mat <- print(tab2, quote = FALSE, noSpaces = TRUE, printToggle = FALSE)

## Save to a CSV file
write.csv(tab3Mat, file = "tableone.csv")

#---------------------------------------------------------------------------------------------------------------------------
#Process Maps
#---------------------------------------------------------------------------------------------------------------------------
#Maybe want to restrict to fewer activities to get a clearer process map
#For sharing in documents, otherwise including a zoom-in factor in R Markdown
#Would be an alternate solution.

restricted_activity<- c("APPT_made",
                      "community_musculoskeletal service",
                      "elec_hip_replace",
                      "GP_refers_for_hip",
                      "OP_diagnostic imaging service",
                      "OP_physiotherapy service",
                      "OP_trauma and orthopaedic service",
                      "primary_care_analgesic",
                      "primarycare_msk")

#------------------------------------------------------------------------
#Process Maps

hip_log %>% 
  filter_activity(restricted_activity) %>% 
  process_map(type=performance(median, units = "days")) %>% 
  DiagrammeRsvg::export_svg() %>% 
  svgPanZoom::svgPanZoom()

hip_log %>% 
  filter_activity(restricted_activity) %>% 
  process_map() %>%   
  DiagrammeRsvg::export_svg() %>% 
  svgPanZoom::svgPanZoom()

hip_log$cost2<- hip_log$cost
hip_log$cost2[is.na(hip_log$cost2)]<-0

#Same again but show the cost per stage

hip_log %>% 
  filter_activity(restricted_activity) %>% 
  process_map(type=custom(attribute="cost2", median, units = "£"))

hip_log %>% 
  filter_activity(restricted_activity) %>% 
  process_map(type_nodes=custom(attribute="cost2", median, units = "£"))

#Mixing performance and frequency maps

hip_log %>% 
  filter_activity(restricted_activity) %>%
  process_map(type_nodes = frequency("relative_case"),
              type_edges = performance(median, units = "days"))
#--------------------------------------------------------------------------
#How long are people waiting on average from GP_referral to OP to  hip replacement

main<-c("GP_refers_for_hip", "OP_Trauma And Orthopaedic Service", "elec_hip_replace")

hip_log %>% 
  filter_activity(main) %>%
  process_map(type=performance(median, units = "days"))


hip_log %>% 
  filter_activity(main) %>%
  throughput_time()

#---------------------------------------------------------------------------------------------------------------------------
#Animated Process Maps
#---------------------------------------------------------------------------------------------------------------------------
hip_log %>% filter_activity(restricted_activity) %>%
  animate_process()


#By Age Group
hip_log %>% filter_activity(restricted_activity) %>%
  animate_process(mode='relative', jitter=10, legend = "color",
                  mapping = token_aes(color= token_scale("age_group",
                                                         scale = "ordinal",
                                                         range = RColorBrewer::brewer.pal(2, "Spectral"))))

#---------------------------------------------------------------------------------------------------------------------------
#Can filter by frequency or the presence/absence of certain activities
#---------------------------------------------------------------------------------------------------------------------------
#Looking at process maps for those with physio
#Look at differences in dotted charts, trace explorer, throughput time
#activity frequencies etc
#---------------------------------------------------------------------------------------------------------------------------

#Throughput time plot

hip_log %>% 
  filter_activity(selected_activity) %>% 
  check_rule(contains("OP_physiotherapy service", n=1)) %>% 
  group_by(contains_OP_physiotherapy_service_1) %>% 
  throughput_time() %>% 
  plot()

#Trace length plot

hip_log %>% 
  filter_activity(selected_activity) %>% 
  check_rule(contains("OP_physiotherapy service", n=1)) %>% 
  group_by(contains_OP_physiotherapy_service_1) %>% 
  trace_length() %>% 
  plot()


#Process maps for those with physio versus those without

hip_log %>% 
  filter_activity(restricted_activity) %>% 
  check_rule(contains("OP_physiotherapy service", n=1)) %>% 
  group_by(contains_OP_physiotherapy_service_1) %>% 
  process_map(type_nodes = frequency("relative_case"),
              type_edges = performance(median, units = "days"))

#Trace length averages
hip_log %>% 
  filter_activity(selected_activity) %>% 
  check_rule(contains("OP_physiotherapy service", n=1)) %>% 
  group_by(contains_OP_physiotherapy_service_1) %>% 
  trace_length() %>% View()

#Throughput time averages
hip_log %>% 
  filter_activity(selected_activity) %>% 
  check_rule(contains("OP_physiotherapy service", n=1)) %>% 
  group_by(contains_OP_physiotherapy_service_1) %>% 
  throughput_time() %>% View()

#---------------------------------------------------------------------------------------------------------------------------
#Attributes of patients having physio versus not
#---------------------------------------------------------------------------------------------------------------------------
hip_log %>% 
  filter_activity(selected_activity) %>% 
  check_rule(contains("OP_physiotherapy service", n=1)) ->physio_marker


physio_marker %>% 
  distinct(Pseudo_NHS_Number, .keep_all=T)->dist_physio


myVars <- c("sex", "smoking", "qof_af", 
            "qof_chd", "qof_hf", "qof_ht", "qof_pad", "qof_stroke", "qof_asthma", 
            "qof_copd", "qof_obesity", "qof_cancer", "qof_ckd", "qof_diabetes", 
            "qof_pall", "qof_dementia", "qof_depression", "qof_epilepsy", 
            "qof_learndis", "qof_mental", "qof_osteoporosis", "qof_rheumarth", 
            "hearing_impair", "visual_impair", "phys_disability", 
            "PATIENT_AGE", "age_group", "total_cost", "cost_impact", "ethnicgroup")
## Vector of categorical variables that need transformation
catVars <- c("sex", "smoking", "qof_af", 
             "qof_chd", "qof_hf", "qof_ht", "qof_pad", "qof_stroke", "qof_asthma", 
             "qof_copd", "qof_obesity", "qof_cancer", "qof_ckd", "qof_diabetes", 
             "qof_pall", "qof_dementia", "qof_depression", "qof_epilepsy", 
             "qof_learndis", "qof_mental", "qof_osteoporosis", "qof_rheumarth", 
             "hearing_impair", "visual_impair", "phys_disability", 
             "age_group", "cost_impact", "ethnicgroup")
## Create a TableOne object
tab2 <- CreateTableOne(vars = myVars, data = dist_physio,strata = "contains_OP_physiotherapy_service_1", factorVars = catVars)

tab3Mat <- print(tab2, quote = FALSE, noSpaces = TRUE, printToggle = FALSE)

setwd("")
write.csv(tab3Mat, file = "tableone_physio.csv")


#---------------------------------------------------------------------------------------------------------------------------
#Pathways by cost grouping - summing total cost for each patient and then grouping to high, medium, low
#Costing information is not available for all activities so this is for illustration purposes 
#---------------------------------------------------------------------------------------------------------------------------
hip_log$cost2<- hip_log$cost
hip_log$cost2[is.na(hip_log$cost2)]<-0

sum(hip_log$cost2)

hip_log %>% 
  filter(status=="complete") %>% #This will ensure not double counting costs for hip replacement which has start/stop
  filter_activity(selected_activity) %>% 
  group_by(Pseudo_NHS_Number) %>% 
  dplyr::mutate(total_cost = sum(cost2)) -> cost_to_join

cost_to_join %>% 
  distinct(Pseudo_NHS_Number, total_cost, sex) -> cost_to_join2

#Histogram to get an idea of the distribution of cost
mu <- ddply(cost_to_join2, "sex", summarise, grp.mean=mean(total_cost))

ggplot(cost_to_join2, aes(x=total_cost, color=sex)) +
  geom_histogram(binwidth = 80) +
  geom_vline(data=mu, aes(xintercept=grp.mean, color=sex),linetype="dashed") +
  labs(x = "Total Cost")+
  scale_fill_discrete(name = "Sex")

summary(cost_to_join2$total_cost)
quantile(cost_to_join2$total_cost, c(.1, .2, .3, .4, .5, .6, .7, .8, .9)) 


hip_log %>% 
  filter_activity(selected_activity) %>% 
  left_join(cost_to_join2[,c("Pseudo_NHS_Number", "total_cost")], by=c("Pseudo_NHS_Number"="Pseudo_NHS_Number")) ->hip_log2

#Cutpoints based on 1st and 3rd quartiles

hip_log2 %>% 
  dplyr::mutate(cost_impact = case_when(total_cost>7200 ~ "High", 
                                 total_cost>=6775 & total_cost<=7200 ~ "Medium", 
                                 TRUE ~ "Low")) ->hip_log2


hip_log2 %>% 
  group_by(cost_impact) %>% #Can change this to performance or cost etc etc
  throughput_time() %>% #change this to different aspects
  plot()

#---------------------------------------------------------------------------------------------------------------------------
#Appending throughput time for each patient and then grouping into short, medium and long duration
#---------------------------------------------------------------------------------------------------------------------------
hip_log %>% 
  filter_activity(selected_activity) %>% 
  throughput_time(level = "case", units="days", append = TRUE) ->hip_log2

#---------------------------------------------------------------------------------------------------------------------------
#Throughput time

hip_log2 %>% 
  distinct(Pseudo_NHS_Number, .keep_all=T) -> distinct_duration


#Histogram to get an idea of the distribution of throughput time
ggplot(distinct_duration, aes(x=throughput_time_case)) +
  geom_histogram(color="black") +
  labs(x = "Throughput Time")

summary(hip_log2$throughput_time_case)

#Code as a whole

hip_log %>% 
  filter_activity(selected_activity) %>% 
  throughput_time(level = "case", units="days", append = TRUE) %>% 
  mutate(performance = case_when(throughput_time_case>=190 ~ "Long_duration", 
                                 throughput_time_case>80 & throughput_time_case<190 ~ "Medium_duration", 
                                 TRUE ~ "Short_duration")) -> hip_log2
#---------------------------------------------------------------------------------------------------------------------------

hip_log2 %>% 
  distinct(Pseudo_NHS_Number, .keep_all=T) -> distinct_duration

myVars <- c("sex", "smoking", "qof_af", 
            "qof_chd", "qof_hf", "qof_ht", "qof_pad", "qof_stroke", "qof_asthma", 
            "qof_copd", "qof_obesity", "qof_cancer", "qof_ckd", "qof_diabetes", 
            "qof_pall", "qof_dementia", "qof_depression", "qof_epilepsy", 
            "qof_learndis", "qof_mental", "qof_osteoporosis", "qof_rheumarth", 
            "hearing_impair", "visual_impair", "phys_disability", 
            "ethnicgroup", "PATIENT_AGE", "age_group", "total_cost", "cost_impact")

## Vector of categorical variables that need transformation
catVars <- c("sex", "smoking", "qof_af", 
             "qof_chd", "qof_hf", "qof_ht", "qof_pad", "qof_stroke", "qof_asthma", 
             "qof_copd", "qof_obesity", "qof_cancer", "qof_ckd", "qof_diabetes", 
             "qof_pall", "qof_dementia", "qof_depression", "qof_epilepsy", 
             "qof_learndis", "qof_mental", "qof_osteoporosis", "qof_rheumarth", 
             "hearing_impair", "visual_impair", "phys_disability", 
             "ethnicgroup", "age_group", "cost_impact")

## Create a TableOne object
tab2 <- CreateTableOne(vars = myVars, data = distinct_duration,strata = "performance", factorVars = catVars)

tab3Mat <- print(tab2, quote = FALSE, noSpaces = TRUE, printToggle = FALSE)

setwd("")
write.csv(tab3Mat, file = "tableone_perf_duration.csv")

#---------------------------------------------------------------------------------------------------------------------------







