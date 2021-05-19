#---------------------------------------------------------------------------------------------------------------------------
#Extracting Data needed for Process Mining
#Using the date_lookup table to define the population and the time window
#Appended further attributes to this lookup table for different patient groups
#So can analyse by age, gender, ethnicity etc
#---------------------------------------------------------------------------------------------------------------------------
library(dplyr) 
library(dbplyr) 
library(odbc) 
library(DBI) 
library(tidyr)
#---------------------------------------------------------------------------------------------------------------------------
con <- RODBC::odbcDriverConnect("") #deleted the connection string and server details for sharing purposes
#---------------------------------------------------------------------------------------------------------------------------
View(all_elective_hip_pats[1:115])
rstudioapi::writeRStudioPreference("data_viewer_max_columns", 1000L) #So I can scroll through more variables in View()
#---------------------------------------------------------------------------------------------------------------------------
#Lookup table to define time window for data extraction
date_lookup <- readRDS("date_lookup.rds")
#---------------------------------------------------------------------------------------------------------------------------
#Save date_lookup to SQL to use when drawing out data
#---------------------------------------------------------------------------------------------------------------------------

DBI_Connection <- DBI::dbConnect(odbc::odbc(),
                           Driver = "",
                           Server = "",
                           Database = "",
                           Trusted_Connection = "")


tablename_schema <- DBI::Id(
  schema  = "dbo",
  table   = "JC_date_lookup_more_complete"
)

dbWriteTable(DBI_Connection, name=tablename_schema, date_lookup, overwrite=FALSE)
#dbWriteTable(DBI_Connection,"JC_date_lookup", date_lookup, overwrite=FALSE) #This is the default schema

close(DBI_Connection)
#---------------------------------------------------------------------------------------------------------------------------
#[1] Extracting Data Sources for the Event Logs
#---------------------------------------------------------------------------------------------------------------------------
con <- RODBC::odbcDriverConnect("")
options('stringsAsFactors'=FALSE) #Make sure strings aren't factors
#---------------------------------------------------------------------------------------------------------------------------
# Data for Patient Attributes from the System Wide Dataset for hip cohort
#---------------------------------------------------------------------------------------------------------------------------
s_attributes_hip_pats <- " with cte as (select *
  from
(SELECT *, ROW_NUMBER() OVER (PARTITION BY nhs_number ORDER BY InsertedDate desc) as RN
  FROM [primary_care_attributes] #removed full database name for sharing purposes
  WHERE isnull(nhs_number,'') <> ''
  and attribute_period >= '2019-10-01') a
where RN = 1)


select a.*
 from cte a
 inner join [JC_date_lookup_more_complete] b #removed full database name for sharing purposes
on a.nhs_number = b.Pseudo_NHS_Number
where PATIENT_AGE>=18 
and trauma  like 'Non-Trauma'
and swd_match = 1 
and e_referral_not_complete = 0"


swd_attributes_hip  <- RODBC::sqlQuery(con, s_attributes_hip_pats)

#---------------------------------------------------------------------------------------------------------------------------
#Supplementary Data for Patient Attributes from the System Wide Dataset for hip cohort
#---------------------------------------------------------------------------------------------------------------------------
s_supp_hip_pats <- "with cte as (select *
from
(select *, ROW_NUMBER() OVER (PARTITION BY nhs_number ORDER BY InsertedDate desc) as RN
from [primary_care_supplemental] #removed full database name for sharing purposes
  WHERE isnull(nhs_number,'') <> ''
  and attribute_period >= '2020-02-01') a
where RN = 1)

select a.*
 from cte a
 inner join [JC_date_lookup_more_complete] b #removed full database name for sharing purposes
on a.nhs_number = b.Pseudo_NHS_Number
where PATIENT_AGE>=18 
and trauma  like 'Non-Trauma'
and swd_match = 1 
and e_referral_not_complete = 0"


swd_supp_hip  <- RODBC::sqlQuery(con, s_supp_hip_pats)


#---------------------------------------------------------------------------------------------------------------------------
#Activity Data from System Wide Dataset for hip cohort
#---------------------------------------------------------------------------------------------------------------------------
s_activity_hip_pats <- " select t1.*
 from [swd_activity] t1
 inner join [JC_date_lookup_more_complete] t2 #removed full database name for sharing purposes
 on t1.nhs_number = t2.Pseudo_NHS_Number
 where (arr_date > DATE_DECISION_TO_REFER and arr_date <hip_rep_start_dttm)
 and PATIENT_AGE>=18 
 and trauma  like 'Non-Trauma'
 and swd_match = 1 
 and e_referral_not_complete = 0"


swd_activity_hip  <- RODBC::sqlQuery(con, s_activity_hip_pats)

#---------------------------------------------------------------------------------------------------------------------------
#Outpatient appointment data (can also be taken from the SWD)
#---------------------------------------------------------------------------------------------------------------------------
s_out_hip_pats <- "  select t1.*
  from [tbl_BNSSG_Datasets_Outpatient_Standard_Script] t1
 inner join [JC_date_lookup_more_complete] t2 #removed full database name for sharing purposes
 on t1.NHS_Number_Pseudo = t2.Pseudo_NHS_Number
 where (AppointmentDate > DATE_DECISION_TO_REFER and AppointmentDate <hip_rep_start_dttm)
 and PATIENT_AGE>=18 
 and trauma  like 'Non-Trauma'
 and swd_match = 1 
 and e_referral_not_complete = 0"


outpatient  <- RODBC::sqlQuery(con, s_out_hip_pats)

#---------------------------------------------------------------------------------------------------------------------------
#Non elective spells (Can also be taken from the SWD)
#Occasionally additional data needed from original dataset
#---------------------------------------------------------------------------------------------------------------------------

s_nonelec_hip_pats <- " select t1.*
  from [tbl_BNSSG_Datasets_NEL_SPELLS_Standard_Script] t1
inner join [JC_date_lookup_more_complete] t2 #removed full database name for sharing purposes
 on t1.AIMTC_Pseudo_NHS = t2.Pseudo_NHS_Number
 where (AIMTC_ProviderSpell_Start_Date > DATE_DECISION_TO_REFER and AIMTC_ProviderSpell_Start_Date <hip_rep_start_dttm)
 and PATIENT_AGE>=18 
 and trauma  like 'Non-Trauma'
 and swd_match = 1 
 and e_referral_not_complete = 0"



non_elective  <- RODBC::sqlQuery(con, s_nonelec_hip_pats)

#---------------------------------------------------------------------------------------------------------------------------
#Other electives (Can also be taken from the SWD)
#Occasionally additional data needed from original dataset
#---------------------------------------------------------------------------------------------------------------------------

s_elec_hip_pats <- " select t1.*
  from [tbl_BNSSG_Datasets_Elective_SPELLS_Standard_Script] t1
inner join [JC_date_lookup_more_complete] t2 #removed full database name for sharing purposes
 on t1.AIMTC_Pseudo_NHS = t2.Pseudo_NHS_Number
 where (StartDate_HospitalProviderSpell > DATE_DECISION_TO_REFER and StartDate_HospitalProviderSpell <hip_rep_start_dttm)
 and PATIENT_AGE>=18 
 and trauma  like 'Non-Trauma'
 and swd_match = 1 
 and e_referral_not_complete = 0"


electives  <- RODBC::sqlQuery(con, s_elec_hip_pats)

#---------------------------------------------------------------------------------------------------------------------------
#[2] Converting data into Event Logs
#---------------------------------------------------------------------------------------------------------------------------
date_lookup %>% 
  filter(PATIENT_AGE>=18 & trauma=="Non-Trauma" & swd_match==1 & e_referral_not_complete == 0) -> date_lookup_final

#date_lookup_final$DATE_DECISION_TO_REFER.y <- NULL

#---------------------------------------------------------------------------------------------------------------------------
#Event log for referral data
#---------------------------------------------------------------------------------------------------------------------------

date_lookup_final %>% 
  # mutate(activity_instance = 1:nrow(.)) %>% 
  select(Pseudo_NHS_Number, DATE_DECISION_TO_REFER, APPT_DT_TM, SERVICE_NAME) %>% 
  rename(GP_refers_for_hip = DATE_DECISION_TO_REFER) %>% 
  rename(APPT_hip = APPT_DT_TM) %>% 
     
  gather(activity, timestamp, GP_refers_for_hip, APPT_hip) %>% 
  
  #Important these steps completed after gathering
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") %>% #Add this for lack of transactional lifecycle data where event is = to an activity instance
  mutate(timestamp=as.POSIXct(timestamp, origin = "1970-01-01"))  -> eventlog  #Restore date time format 

#Create an activity instance ID for referral related activity.
eventlog$activity_instance<- paste("Referral", 1:nrow(eventlog), sep="_")

eventlog1<- eventlog

#---------------------------------------------------------------------------------------------------------------------------
#Adding in the alternative eventlog1 using APPT_made
#---------------------------------------------------------------------------------------------------------------------------
date_lookup_final %>% 
  # mutate(activity_instance = 1:nrow(.)) %>% 
  select(Pseudo_NHS_Number, DATE_DECISION_TO_REFER, ACTION_DT_TM, SERVICE_NAME) %>% 
  rename(GP_refers_for_hip = DATE_DECISION_TO_REFER) %>% 
  rename(APPT_made = ACTION_DT_TM) %>% 
  
  gather(activity, timestamp, GP_refers_for_hip, APPT_made) %>% 
  
  #Important these steps completed afterward gathering
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") %>% #Add this for lack of transactional lifecycle data where event is = to an activity instance
  mutate(timestamp=as.POSIXct(timestamp, origin = "1970-01-01"))  -> eventlog  #Restore date time format 


#Create an activity instance ID for referral related activity.
eventlog$activity_instance<- paste("Referral", 1:nrow(eventlog), sep="_")

eventlog1a<- eventlog

#------------------------------------------------------------------------  
# Event log for the actual hip replacement  
#------------------------------------------------------------------------    
#Add activity instance ID as you have start and end dates which will be part of the lifecycle

date_lookup_final$activity_instance<- paste("elec_hip_replace", 1:nrow(date_lookup_final), sep="_")

date_lookup_final %>% 
  select(Pseudo_NHS_Number, hip_rep_start_dttm, hip_rep_end_dttm, `Dominant Procedure`, `Cost +MFF`, activity_instance ) %>% 
  mutate(activity = "elec_hip_replace") %>%
 # mutate(activity_instance = paste("elec_hip_replace", 1:nrow(.), sep='_')) %>% 
    rename(start = hip_rep_start_dttm) %>% 
  rename(complete = hip_rep_end_dttm) %>% 
  rename(cost = `Cost +MFF`) %>% 
  gather(status, timestamp, start, complete) %>% 
  
  #Important these steps completed afterward gathering
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(timestamp=as.POSIXct(timestamp, origin = "1970-01-01")) -> eventlog2a #its 2a because I added in costs

#------------------------------------------------------------------------
#Event log for outpatient appointments
#------------------------------------------------------------------------
#No need to gather as already in the right format

outpatient %>% 
  select(NHS_Number_Pseudo, AppointmentDate, `Treatment Function Description`, `Cost +MFF`) %>% 
  rename(Pseudo_NHS_Number = NHS_Number_Pseudo) %>% 
  rename(timestamp = AppointmentDate) %>% 
  rename(cost = `Cost +MFF`) %>% 
  mutate(activity = paste("OP", `Treatment Function Description`, sep='_')) %>% 
  mutate(activity_instance = paste("OP", 1:nrow(.), sep='_')) %>% 
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") %>% #Add this for lack of transactional lifecycle data where event is = to an activity instance
  mutate(timestamp=as.POSIXct(timestamp, origin = "1970-01-01")) ->eventlog3


#---------------------------------------------------------------------------------------------------------------------------
#Analgesics (painkillers) prescriptions dates and event log
#---------------------------------------------------------------------------------------------------------------------------
analgesics <- read.csv("analgesic_prescriptions.csv") %>%
  mutate(productname = tolower(productname))

swd_activity_hip %>% 
  filter(pod_l1=="primary_care_prescription") %>% 
  select(nhs_number, arr_date, cost1, spec_l1b) %>% 
  rename(Pseudo_NHS_Number = nhs_number) %>% 
    mutate(spec_l1b = tolower(spec_l1b)) %>% 
  inner_join(analgesics, by=c("spec_l1b" = "productname")) %>% 
  select(Pseudo_NHS_Number, arr_date, cost1, spec_l1b) %>% 
  
  rename(timestamp = arr_date) %>% 
  rename(cost = cost1) %>% 
  mutate(activity = paste("primary_care_analgesic")) %>% 
  mutate(activity_instance = paste("analgesic", 1:nrow(.), sep='_')) %>% 
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") -> eventlog4
  
#---------------------------------------------------------------------------------------------------------------------------
#Primary care contacts event log
#---------------------------------------------------------------------------------------------------------------------------

swd_activity_hip %>% 
filter(pod_l1=="primary_care_contact") %>% 
  select(nhs_number, arr_date, cost1, spec_l1a) %>%
  rename(Pseudo_NHS_Number = nhs_number) %>% 
  rename(timestamp = arr_date) %>% 
  rename(cost = cost1) %>% 
  mutate(activity = paste("primarycare", spec_l1a, sep='_')) %>% #aggregate if this makes the model too complex
  mutate(activity_instance = paste("primary_care_contact", 1:nrow(.), sep='_')) %>% 
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") -> eventlog5

#---------------------------------------------------------------------------------------------------------------------------
#Non-electives event log - would probably be more interested in this activity after their hip replacement
#Including code for completeness
#---------------------------------------------------------------------------------------------------------------------------
#Could do treatment function description as activity name

non_elective %>% 
  select(AIMTC_Pseudo_NHS, `Spell_Start Date Time`, `Spell END Date Time`,DischargeDestination_HospitalProviderSpell, 
         Flag_Falls, `Admission Method`, `Treatment Function Description`, `Primary Diagnosis`, 
         `Primary Procedure`, `Cost +MFF`) %>% 
  rename(Pseudo_NHS_Number = AIMTC_Pseudo_NHS) %>% 
  
  
  mutate(activity = paste(Flag_Falls, "non_elective", sep='_')) %>%
  rename(start =`Spell_Start Date Time`) %>% 
  rename(complete = `Spell END Date Time`) %>% 
  rename(cost =`Cost +MFF`) %>% 
  mutate(activity_instance = paste("non_elec", 1:nrow(.), sep='_')) %>% 
  gather(status, timestamp, start, complete) %>% 
  
  #Important these steps completed after gathering
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(timestamp=as.POSIXct(timestamp, origin = "1970-01-01")) %>% 
  select(Pseudo_NHS_Number, activity, status, timestamp, activity_instance, 
         cost, `Treatment Function Description`, `Primary Diagnosis`) -> eventlog6

#---------------------------------------------------------------------------------------------------------------------------
#Community contacts event log
#---------------------------------------------------------------------------------------------------------------------------

swd_activity_hip %>% 
  filter(pod_l1=="community") %>% 
  select(nhs_number, arr_date, cost1, spec_l1b) %>%
  rename(Pseudo_NHS_Number = nhs_number) %>% 
  rename(timestamp = arr_date) %>% 
  rename(cost = cost1) %>% 
  mutate(activity = paste("community", spec_l1b, sep='_')) %>% #aggregate if this makes the model too complex
  mutate(activity_instance = paste("community", 1:nrow(.), sep='_')) %>% 
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") -> eventlog7
#---------------------------------------------------------------------------------------------------------------------------
#Outpatient appointment event log based on System Wide Dataset
#---------------------------------------------------------------------------------------------------------------------------
swd_activity_hip %>% 
  filter(pod_l1=="secondary" & pod_l2a=="op") %>% 
  select(nhs_number, arr_date, cost1, spec_l1b) %>%
  rename(Pseudo_NHS_Number = nhs_number) %>% 
  rename(timestamp = arr_date) %>% 
  rename(cost = cost1) %>% 
  mutate(activity = paste("OP", spec_l1b, sep='_')) %>% #aggregate if this makes the model too big and messy
  mutate(activity_instance = paste("outpatient", 1:nrow(.), sep='_')) %>% 
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") -> eventlog8

#---------------------------------------------------------------------------------------------------------------------------
#AE event log based on System Wide Dataset
#Need to also link on HRG description onto table for under spec_l2b for when the code matches in spec_l2a
#---------------------------------------------------------------------------------------------------------------------------

swd_activity_hip %>% 
  filter(pod_l1=="secondary" & pod_l2a=="ae") %>% 
  select(nhs_number, arr_date, cost1,spec_l2a, spec_l2b) -> swd_activity_hip_ae


query_HRGcode <- "SELECT HRGCode as spec_l2a, HRG_Chapter_Description as spec_l2b
  FROM [tbl_HRG_Lookup]" #removed full database name for sharing purposes

HRGcode <- RODBC::sqlQuery(con, query_HRGcode)

HRGcode$spec_l2a<- as.character(HRGcode$spec_l2a)
HRGcode$spec_l2b<- as.character(HRGcode$spec_l2b)
swd_activity_hip_ae$spec_l2a<- as.character(swd_activity_hip_ae$spec_l2a)

HRGcode <- dplyr::mutate_at(HRGcode, "spec_l2a", tolower) #converts to lower case
swd_activity_hip_ae <- dplyr::mutate_at(swd_activity_hip_ae, "spec_l2a", tolower) #converts to lower case

swd_activity_hip_ae_label <- dplyr::left_join(swd_activity_hip_ae, HRGcode, by = "spec_l2a")

swd_activity_hip_ae_label %>%  
  select("nhs_number", "arr_date", "cost1", "spec_l2a", "spec_l2b.y") %>% 
  dplyr::rename(spec_l2b = spec_l2b.y) ->swd_activity_hip_ae_label

#---------------------------------------------------------------------------------------------------------------------------

swd_activity_hip_ae_label %>% 
  select(nhs_number, arr_date, cost1) %>% # this does not need distinguishing as spec_l2b the same descriptor for everyone
  dplyr::rename(Pseudo_NHS_Number = nhs_number) %>% 
  dplyr::rename(timestamp = arr_date) %>% 
  dplyr::rename(cost = cost1) %>% 
  mutate(activity = "AE") %>%          
  mutate(activity_instance = paste("AE", 1:nrow(.), sep='_')) %>% 
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(status = "complete") -> eventlog9

#---------------------------------------------------------------------------------------------------------------------------
#Non elective data event log but including only when ICD-10 is equal to activity potentially hip replacement related
#More for interest after the hip replacement but included for completeness below
#---------------------------------------------------------------------------------------------------------------------------

non_elective %>% 
  filter(`Primary Diagnosis`=="Fracture of lower end of both ulna and radius" |
         `Primary Diagnosis`=="Infection following a procedure, not elsewhere classified"|
         `Primary Diagnosis`=="Tendency to fall, not elsewhere classified"|
         `Primary Diagnosis`=="Hypokalaemia"|
         `Primary Diagnosis`=="Hypo-osmolality and hyponatraemia"|
         `Primary Diagnosis`=="Fracture of lower end of both ulna and radius"|
         `Primary Diagnosis`=="Cellulitis of other parts of limb"|
         `Primary Diagnosis`=="Fractures of other parts of lower leg") %>% 
  
  select(AIMTC_Pseudo_NHS, `Spell_Start Date Time`, `Spell END Date Time`,DischargeDestination_HospitalProviderSpell, 
         Flag_Falls, `Admission Method`, `Treatment Function Description`, `Primary Diagnosis`, 
         `Primary Procedure`, `Cost +MFF`) %>% 
  rename(Pseudo_NHS_Number = AIMTC_Pseudo_NHS) %>% 
  
  
  mutate(activity = paste("non_elective", `Treatment Function Description`, sep='_')) %>%
  rename(start =`Spell_Start Date Time`) %>% 
  rename(complete = `Spell END Date Time`) %>% 
  rename(cost =`Cost +MFF`) %>% 
  mutate(activity_instance = paste("non_elec", 1:nrow(.), sep='_')) %>% 
  gather(status, timestamp, start, complete) %>% 
  
  #Important these steps completed afterward gathering
  mutate(resource = NA) %>% #Not recording resources so include but make equal to NA
  mutate(timestamp=as.POSIXct(timestamp, origin = "1970-01-01")) %>% 
  select(Pseudo_NHS_Number, activity, status, timestamp, activity_instance, 
         cost, reatment Function Description`, `Primary Diagnosis`) -> eventlog10

#---------------------------------------------------------------------------------------------------------------------------
#Combine all the activity/event logs that you are interested in investigating
#---------------------------------------------------------------------------------------------------------------------------
#Save so you can select event logs later down the line without having to run all the previous queries
#As csv/RDS files:

setwd("")

dput(ls())

eventlogs<- list("eventlog1", "eventlog10", "eventlog1a", "eventlog2a", 
"eventlog3", "eventlog4", "eventlog5", "eventlog6", "eventlog7", "eventlog8", "eventlog9")

for (i in eventlogs) {

eventlogname<- get(i)
file_name<- paste0(i,".csv")  
write.csv(eventlogname, file_name)  
saveRDS(eventlogname, file_name)  

}

#Read in event logs
eventlog1<- readRDS("eventlog1.RDS")
eventlog10<- readRDS("eventlog10.RDS")
eventlog1a<- readRDS("eventlog1a.RDS")
eventlog2a<- readRDS("eventlog2a.RDS")
eventlog3<- readRDS("eventlog3.RDS")
eventlog4<- readRDS("eventlog4.RDS")
eventlog5<- readRDS("eventlog5.RDS")
eventlog6<- readRDS("eventlog6.RDS")
eventlog7<- readRDS("eventlog7.RDS")
eventlog8<- readRDS("eventlog8.RDS")
eventlog9<- readRDS("eventlog9.RDS")

#---------------------------------------------------------------------------------------------------------------------------
#combine event logs together
#---------------------------------------------------------------------------------------------------------------------------
hip_pathway<- bind_rows(eventlog1a, eventlog2a, eventlog4, eventlog5, eventlog7, eventlog8, eventlog9)
saveRDS(hip_pathway, "hip_pathway.rds")
#---------------------------------------------------------------------------------------------------------------------------
date_lookup <- readRDS("date_lookup.rds")

date_lookup %>% 
  filter(PATIENT_AGE>=18 & trauma=="Non-Trauma" & swd_match==1 & e_referral_not_complete == 0) -> date_lookup_final

#date_lookup_final$DATE_DECISION_TO_REFER.y <- NULL

#---------------------------------------------------------------------------------------------------------------------------
#[3] Appending additional variables to group pathways
#---------------------------------------------------------------------------------------------------------------------------
hip_pathway %>% 
  left_join(date_lookup[ , c("Pseudo_NHS_Number", "PATIENT_AGE", "age_group")], by ="Pseudo_NHS_Number") %>% 
  as.data.frame() -> hip_pathway
#---------------------------------------------------------------------------------------------------------------------------
#Joining on attributes from the System Wide Dataset:
#---------------------------------------------------------------------------------------------------------------------------
con <- RODBC::odbcDriverConnect("")

s_attributes <- " select nhs_number, ethnicity, sex, smoking, qof_af, qof_chd, qof_hf,
qof_ht, qof_pad, qof_stroke, qof_asthma, qof_copd,
qof_obesity, qof_cancer, qof_ckd, qof_diabetes, qof_pall, 
qof_dementia, qof_depression, qof_epilepsy, qof_learndis, 
qof_mental, qof_osteoporosis, qof_rheumarth, lsoa, hearing_impair, visual_impair, phys_disability

  from
(SELECT *, ROW_NUMBER() OVER (PARTITION BY nhs_number ORDER BY InsertedDate desc) as RN
  FROM [primary_care_attributes]
  WHERE isnull(nhs_number,'') <> ''
  and attribute_period >= '2019-10-01') a
where RN = 1"

attributes_swd  <- RODBC::sqlQuery(con, s_attributes)

hip_pathway6 %>% 
  left_join(attributes_swd, by =c("Pseudo_NHS_Number" = "nhs_number")) %>% 
  as.data.frame() -> hip_pathway6

#---------------------------------------------------------------------------------------------------------------------------
#Using a lookup for ethnicity groupings
#---------------------------------------------------------------------------------------------------------------------------
con <- RODBC::odbcDriverConnect("")
 
string_eth <- "select [Ethnicity_description] as ethnicity, [Main group] as ethnicgroup
     FROM [swd_ethnicity_groupings]"  
ethnic<-RODBC::sqlQuery(con,string_eth)
close(con)

ethnic<-ethnic %>%
  mutate(ethnicity=tolower(as.character(ethnicity)))
ethnic<-ethnic %>%
  mutate(ethnicgroup=recode(ethnicgroup,"Any other Asian background"="Asian",
                            "Asian / Asian British"="Asian",
                            "Bangladeshi or British Bangladeshi"="Asian",
                            "Pakistani or British Pakistani"="Asian",
                            "Other Asian, Asian unspecified"="Asian",
                            "Indian or British Indian"="Asian",
                            "Chinese"="Asian",
                            "Any other Black background"="Black",
                            "Black / African / Caribbean / Black British"="Black",
                            "Mixed / Multiple ethnic groups"="Mixed",
                            "Any other mixed background"="Mixed",
                            "White and Asian"="Mixed",
                            "Scottish"="White",
                            "Irish"="White",
                            "British, Mixed British"="Unknown",
                            "Other ethnic group"="Unknown",
                            "White"="White",
                            "Any other White background"="White"))
hip_pathway<-hip_pathway %>%
  mutate(ethnicity=tolower(as.character(ethnicity))) %>%
  left_join(ethnic,by="ethnicity")

#---------------------------------------------------------------------------------------------------------------------------
#Clean the appended attributes
#---------------------------------------------------------------------------------------------------------------------------
#list of variables you want to change

cc_variables <-c("qof_af", 
                 "qof_chd", "qof_hf", "qof_ht", "qof_pad", "qof_stroke", "qof_asthma", 
                 "qof_copd", "qof_obesity", "qof_cancer", "qof_ckd", "qof_diabetes", 
                 "qof_pall", "qof_dementia", "qof_depression", "qof_epilepsy", 
                 "qof_learndis", "qof_mental", "qof_osteoporosis", "qof_rheumarth", 
                 "lsoa", "hearing_impair", "visual_impair", "phys_disability")


# replace the NAs with 0
hip_pathway[,cc_variables]<- hip_pathway[,cc_variables] %>% 
  replace(., is.na(.), 0)


#ethnicgroup change NAs to unknown
table(hip_pathway$ethnicgroup, useNA="always")

hip_pathway %>% 
mutate(ethnicgroup = replace(ethnicgroup, is.na(ethnicgroup), "Unknown")) -> hip_pathway

#---------------------------------------------------------------------------------------------------------------------------
saveRDS(hip_pathway, "hip_pathway_enriched.rds")

#---------------------------------------------------------------------------------------------------------------------------
#End#
#---------------------------------------------------------------------------------------------------------------------------