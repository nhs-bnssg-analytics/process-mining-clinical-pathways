#---------------------------------------------------------------------------------------------------------------------------
#Cleaning Data for Process Mining
#---------------------------------------------------------------------------------------------------------------------------
library(RODBC)
library(lubridate)
library(dplyr)

#---------------------------------------------------------------------------------------------------------------------------
con <- RODBC::odbcDriverConnect("") #deleted the connection string and server details for sharing purposes
#---------------------------------------------------------------------------------------------------------------------------
View(all_elective_hip_pats[1:115])
rstudioapi::writeRStudioPreference("data_viewer_max_columns", 1000L) #So I can scroll through more variables in View()
#---------------------------------------------------------------------------------------------------------------------------
#(1) BNSSG System Wide Dataset for all matching nhs_numbers

s_attributes <- " select nhs_number
  from
(SELECT *, ROW_NUMBER() OVER (PARTITION BY nhs_number ORDER BY InsertedDate desc) as RN
  FROM [MODELLING_SQL_AREA].[dbo].[primary_care_attributes]
  WHERE isnull(nhs_number,'') <> ''
  and attribute_period >= '2019-10-01') a
where RN = 1"


attributes_swd  <- RODBC::sqlQuery(con, s_attributes)
#---------------------------------------------------------------------------------------------------------------------------
#Hip Cohort 
#(2) NHS numbers of those who have had hip replacement between 01/07/2018 to 01/09/2019
#Therefore could be multiple hip replacements in here

options('stringsAsFactors'=FALSE) #Make sure strings aren't imported as factors

s_elective_hip_pats <- "select *
from [MODELLING_SQL_AREA].[dbo].[JC_all_hip_replacements]
where AIMTC_Pseudo_NHS is not null"

elective_hip_pats  <- RODBC::sqlQuery(con, s_elective_hip_pats)

#'JC_all_hip_replacements' originates from the SQL script included for this project

#---------------------------------------------------------------------------------------------------------------------------
#(3) Extract all e-referrals for the list of NHS numbers in the Hip replacement patients past 01/06/2018

#Other GP Referrals

s_GPreferral_hip_pats <- " select a.* 
from [MODELLING_SQL_AREA].[dbo].[JC_complete_ereferral] a
inner join [MODELLING_SQL_AREA].[dbo].[JC_all_hip_replacements] b
on a.Pseudo_NHS_Number = b.AIMTC_Pseudo_NHS"


GPreferral_hip_pats  <- RODBC::sqlQuery(con, s_GPreferral_hip_pats)

#'JC_complete_ereferral' data is a restructured version of the e-referral dataset
#---------------------------------------------------------------------------------------------------------------------------
# (4) Isolate the earliest hip e-referral and corresponding appointment date
# for a particular NHS and URBN-ID combination *important

GPreferral_hip_pats %>% 
  filter(str_detect(SERVICE_NAME, regex('hip', ignore_case = T))) %>% 
  group_by(Pseudo_NHS_Number, UBRN_ID) %>% #For a particular nhs and URBN_ID combo because patient could have multiple hip appointments
  slice(which.max(APPT_DT_TM)) -> referral_hips   


#---------------------------------------------------------------------------------------------------------------------------
# (5) Select the earliest hip referral appointment from the dataset above

referral_hips %>% 
  filter(str_detect(SERVICE_NAME, regex('hip', ignore_case = T))) %>% 
  group_by(Pseudo_NHS_Number) %>% ##this time only group by NHS number as extracting the earliest appointment date for a particular referral
  slice(which.min(APPT_DT_TM)) %>% 
  select(SERVICE_NAME, Pseudo_NHS_Number, APPT_DT_TM, UBRN_ID, PATIENT_AGE)-> earliest_referral_appt
#Need Patient Age to remove those referred under 18 or to at least label them

#---------------------------------------------------------------------------------------------------------------------------
# (6) Select the earliest hip replacement appt_date after the date identified above
#Left join earliest date above onto elective_hip_pats

#First remove duplicate records in terms of selected variables from the hip elective data
#Remove duplicated rows based on the following:
#If there are duplicate rows, only the first row is preserved

elective_hip_pats %>% distinct(AIMTC_Pseudo_NHS,
                               `Spell Start Date Time`,
                               `Spell Discharge Date Time`,
                               `Spell HRG Code`,
                               DiagnosisPrimary_ICD_4Char,
                               `Dominant Procedure`,
                               .keep_all = TRUE) -> elective_hip_pats_clean

#Removes 6 duplicate records based on the above.
#Joining onto the earliest e referral data


elective_hip_pats_clean %>% 
  select(AIMTC_Pseudo_NHS,
         StartDate_HospitalProviderSpell,
         `Spell Start Date Time`,
         `Spell Discharge Date Time`,
         `Spell HRG Code`,
         DiagnosisPrimary_ICD_4Char,
         `Dominant Procedure`,
         `HRG Description`,
         `Cost +MFF`) %>% #Need HRG Description to remove trauma related hip ops or to at least label them
left_join(earliest_referral_appt, by = c("AIMTC_Pseudo_NHS" = "Pseudo_NHS_Number")) -> elective_hip_pats_clean_referraldate

#Keep if `Spell Start Date Time` (date of hip operation) is after or equal to the e referral appointment made >= APPT_DT_TM
#Then take the minimum for each nhs number


elective_hip_pats_clean_referraldate %>% 
  group_by(AIMTC_Pseudo_NHS) %>% 
  filter(`Spell Start Date Time`>=APPT_DT_TM) %>% #here is the conditional argument
  slice(which.min(`Spell Start Date Time`)) %>% 
  select(AIMTC_Pseudo_NHS, 
         `Spell Start Date Time`, 
         `Spell Discharge Date Time`,
         `Spell HRG Code`,
         DiagnosisPrimary_ICD_4Char,
         `Dominant Procedure`,
         `HRG Description`,
         `Cost +MFF`) %>% 
  rename(hip_rep_start_dttm = `Spell Start Date Time`,
         hip_rep_end_dttm = `Spell Discharge Date Time`) -> hip_replacement_dates


#Save this table for future use
saveRDS(hip_replacement_dates, "hip_replacement_dates.rds")

#---------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------
#(7) Make a date look-up table to define dates for each person

#Convert to date format 
GPreferral_hip_pats$DATE_DECISION_TO_REFER <- as.POSIXct(as.character(GPreferral_hip_pats$DATE_DECISION_TO_REFER), format = "%Y%m%d", origin = "1970-01-01")

#Get the earliest date decision to refer to add to lookup table (DATE_DECISION_TO_REFER)
#Take the data only for the URBN_ID 's which we have picked out for the earliest hip referral (the APPT_DT_TM in the e-referrals dataset)

#GPreferral_hip_pats %>% 
#  inner_join(earliest_referral_appt, by = c("UBRN_ID" = "UBRN_ID"), all.x=TRUE) %>% View()

#This is equivalent to the above but only keeps the variables you want
GPreferral_hip_pats %>% 
filter(UBRN_ID %in% earliest_referral_appt$UBRN_ID) %>% View()


GPreferral_hip_pats %>% 
  filter(UBRN_ID %in% earliest_referral_appt$UBRN_ID) %>% #The above code slotted in here
select(UBRN_ID, Pseudo_NHS_Number, DATE_DECISION_TO_REFER, SERVICE_NAME) %>% 
  group_by(UBRN_ID, Pseudo_NHS_Number) %>% #Group by urban ID AND nhs number to get the earliest date for that batch 
  slice(which.min(DATE_DECISION_TO_REFER)) -> date_to_refer

#Taking the minimum of the ubrn_id batch

date_to_refer %>% 
  select(UBRN_ID, Pseudo_NHS_Number, DATE_DECISION_TO_REFER) %>% 
  group_by(Pseudo_NHS_Number) %>% ##this time only group by NHS number as extracting the earliest appointment date for a particular referral
  slice(which.min(DATE_DECISION_TO_REFER)) ->earliest_date_to_refer   

#---------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------
#Need data to join into a reference table
#(8) Join on all the relevant date data to define windows of activity

earliest_date_to_refer #earliest DATE_DECISION_TO_REFER

earliest_referral_appt #earliest APPT_DT_TM

hip_replacement_dates #is as it should be for start_dttm and end_dttm

#Only keep UBRN_ID for one of the first two tables or when you join two versions of UBRN_ID will be introduced
#Remove from earliest_date_to_refer

earliest_date_to_refer %>% 
  select(Pseudo_NHS_Number, DATE_DECISION_TO_REFER) -> earliest_date_to_refer_reduced


earliest_date_to_refer_reduced %>% 
  left_join(earliest_referral_appt, by = c("Pseudo_NHS_Number" = "Pseudo_NHS_Number")) %>% 
  left_join(hip_replacement_dates, by = c("Pseudo_NHS_Number" = "AIMTC_Pseudo_NHS")) %>% 
  #select(-UBRN_ID) %>% 
  filter(!is.na(hip_rep_start_dttm)) -> date_lookup


date_lookup %>% rename(DATE_DECISION_TO_REFER = DATE_DECISION_TO_REFER.x) -> date_lookup


date_lookup %>% View()
#---------------------------------------------------------------------------------------------------------------------------
#(9) Add some additional variables for inclusion/exclusion of cases

attributes_swd$nhs_number<- as.character(attributes_swd$nhs_number)

#label for trauma versus non trauma

date_lookup %>% 
  mutate(trauma = if_else(str_detect(`HRG Description`, "Non-Trauma"), "Non-Trauma", "trauma")) %>% 
  mutate(age_group = if_else(PATIENT_AGE<50, "less_than_50", "50_and_over")) %>% 
  mutate(swd_match = if_else(Pseudo_NHS_Number %in% attributes_swd$nhs_number, 1, 0)) %>% 
  mutate(e_referral_not_complete = if_else(DATE_DECISION_TO_REFER>APPT_DT_TM,1,0)) -> date_lookup
         
#label for age groups
#Less than 50 and over 50 based on hist(date_lookup$PATIENT_AGE)

#date_lookup %>% 
#  group_by(`HRG Description`) %>% 
#  count()

#---------------------------------------------------------------------------------------------------------------------------
#(10) Add dates for 6 months before date decision to refer and 6 months after hip replacement discharge spell to the lookup table

date_lookup %>% 
  mutate(six_after_hip = hip_rep_end_dttm %m+% months(6),
         six_before_refer = DATE_DECISION_TO_REFER %m-% months(6)) -> date_lookup


#---------------------------------------------------------------------------------------------------------------------------
# Additional checks for any dates that don't make sense i.e. before what you are expecting or after a particular date


date_lookup %>% 
  mutate(bad_date = case_when(DATE_DECISION_TO_REFER>APPT_DT_TM ~1,
                              APPT_DT_TM>hip_rep_start_dttm~2,
                              hip_rep_start_dttm>hip_rep_end_dttm ~3,
                              hip_rep_start_dttm<DATE_DECISION_TO_REFER~4,
                              hip_rep_start_dttm<APPT_DT_TM~5)) %>% View()


date_lookup %>% 
  mutate(bad_date = case_when(DATE_DECISION_TO_REFER>APPT_DT_TM ~1,
                         APPT_DT_TM>hip_rep_start_dttm~2,
                         hip_rep_start_dttm>hip_rep_end_dttm ~3,
                         hip_rep_start_dttm<DATE_DECISION_TO_REFER~4,
                         hip_rep_start_dttm<APPT_DT_TM~5)) %>% 
  filter(is.na(discrepency)) %>% 
  select(-discrepency)-> date_lookup
#Remove the ones where discrepency = 1 as they all seem to have the same APPT_DT_TM and most likely due to datacompleteness
#GPreferral_hip_pats %>% 
#  filter(Pseudo_NHS_Number=="9000159320") %>% View()


#I have added the 'e_referral_not_complete' criteria into the date_lookup table line 200 based on these investigations
#---------------------------------------------------------------------------------------------------------------------------
#(11)
date_lookup$DATE_DECISION_TO_REFER<- format(date_lookup$DATE_DECISION_TO_REFER, "%Y-%m-%d %H:%M:%S")
date_lookup$APPT_DT_TM<- format(date_lookup$APPT_DT_TM, "%Y-%m-%d %H:%M:%S")
date_lookup$ACTION_DT_TM<- format(date_lookup$ACTION_DT_TM, "%Y-%m-%d %H:%M:%S")


saveRDS(date_lookup, "date_lookup.rds")

#This is the population to use and for time windows to extract data for all other activity


#---------------------------------------------------------------------------------------------------------------------------
#End#
#---------------------------------------------------------------------------------------------------------------------------
