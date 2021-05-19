----------------------------------------------------------------------------------
--1. NHS number of those who have had hip replacement
----------------------------------------------------------------------------------
select t1.* ---select only the variables in t1 so you can union the tables together
into #overallhip
from [Analyst_SQL_Area].[dbo].[tbl_BNSSG_Datasets_Elective_SPELLS_Standard_Script] t1
inner join [MODELLING_SQL_AREA].[dbo].[JC_OPCS_hip] t2 on t1.PrimaryProcedure_OPCS=t2.[Operation OPCS codes]
where [Operation OPCS codes] NOT IN ('W521', 'W531', 'W541', 'W581', 'Z843', 'Z761', 'Z756')
AND (StartDate_HospitalProviderSpell >= '2018-07-01' AND StartDate_HospitalProviderSpell <= '2019-09-01');

---[JC_OPCS_hip] is a lookup table for OPCS4 codes which relate to hip replacements

select * from #overallhip
---Drawing out data for the codes which require combination with other data

----------------------------------------------------------------------------------
 with cte as (
 select *
 from [Analyst_SQL_Area].[dbo].[tbl_BNSSG_Datasets_Elective_SPELLS_Standard_Script] t1
 where (PrimaryProcedure_OPCS = 'W521'
 OR PrimaryProcedure_OPCS = 'W531'
 OR PrimaryProcedure_OPCS = 'W541'
 OR PrimaryProcedure_OPCS = 'W581')
 AND (StartDate_HospitalProviderSpell >= '2018-07-01' AND StartDate_HospitalProviderSpell <= '2019-09-01') 
 ) 
 

 select *
 into #additionalhip
 from cte
where Procedure2nd_OPCS = 'Z843'
OR Procedure2nd_OPCS = 'Z761'
OR Procedure2nd_OPCS = 'Z756'
	
OR Procedure3rd_OPCS = 'Z843'	
OR Procedure3rd_OPCS = 'Z761'	
OR Procedure3rd_OPCS = 'Z756'	

 OR Procedure4th_OPCS = 'Z843'
  OR Procedure4th_OPCS = 'Z761'
   OR Procedure4th_OPCS = 'Z756'

 OR Procedure5th_OPCS = 'Z843'
  OR Procedure5th_OPCS = 'Z761'
   OR Procedure5th_OPCS = 'Z756'

 OR Procedure6th_OPCS = 'Z843'
 OR Procedure6th_OPCS = 'Z761'
 OR Procedure6th_OPCS = 'Z756'

 OR Procedure7th_OPCS = 'Z843'
 OR Procedure7th_OPCS = 'Z761'
 OR Procedure7th_OPCS = 'Z756'

 OR Procedure8th_OPCS = 'Z843'
 OR Procedure8th_OPCS = 'Z761'
 OR Procedure8th_OPCS = 'Z756'

 OR Procedure9th_OPCS = 'Z843'
  OR Procedure9th_OPCS = 'Z761'
   OR Procedure9th_OPCS = 'Z756'

 OR Procedure10th_OPCS = 'Z843'
  OR Procedure10th_OPCS = 'Z761'
   OR Procedure10th_OPCS = 'Z756';

----------------------------------------------------------------------------------
---combining the records above for hip replacement using the two different methods


select *
into [MODELLING_SQL_AREA].[dbo].[JC_all_hip_replacements]
from #overallhip

UNION ALL

select *
from #additionalhip
----------------------------------------------------------------------------------
--2.Extract all e-referrals for the list of NHS numbers past 01/06/2018
 ------------------------------------------------------------------
 --Extract all e referral records, not date restrictions

 SELECT
	 [data_source]
			,[UBRN_ID]
			,[Pseudo_NHS_Number]
			,[DATE_DECISION_TO_REFER]
			,[PRIORITY]
			,[SPECIALTY_CD]
			,[SPECIALTY_DESC] 
			,[CLINIC_TYPE]
			,REFERRING_ORG_ID 
			,ORG_REFERRING_PAT
			,[ACTION_DESC]
			,[BUS_FUNCTION_ID]
			,[ORG_ID] as [ORG_ID] --org last updating
			,[ORG_REFERRED_TO]
			,[referred_org_1b]
			,convert(datetime,[APPT_DT_TM],120) [APPT_DT_TM]
			,[referral_rejection_date]
			,convert(datetime,[ACTION_DT_TM],120) [ACTION_DT_TM]
			,action_cd
			,SERVICE_ID
			,SERVICE_NAME
			,PATIENT_AGE

			INTO [MODELLING_SQL_AREA].[dbo].[JC_complete_ereferral]



	 FROM   (

	 --Convert date time format and account for error records where not dd has been included; causing conversion errors
			SELECT
			 [data_source]
			,[UBRN_ID]
			,[Pseudo_NHS_Number]
			,[DATE_DECISION_TO_REFER]
			,[PRIORITY]
			,[SPECIALTY_CD]
			,[SPECIALTY_DESC] 
			,[CLINIC_TYPE]
			,REFERRING_ORG_ID 
			,ORG_REFERRING_PAT
			,[ACTION_DESC]
			,[BUS_FUNCTION_ID]
			,[ORG_ID] as [ORG_ID] --org last updating
			,[ORG_REFERRED_TO]
			,[referred_org_1b]
			,case 
				when data_source = 'ebsx02' and right([APPT_DT_TM],6) = '000000' then replace([APPT_DT_TM],'000000','01') ---cleaning the dates
				else left([APPT_DT_TM],8) end as [APPT_DT_TM]
			,[referral_rejection_date]
			,case 
				when data_source = 'ebsx02' and right([ACTION_DT_TM],6) = '000000' then replace([ACTION_DT_TM],'000000','01') ---cleaning the dates
				else left([ACTION_DT_TM],8) end as [ACTION_DT_TM]
			,action_cd
			,SERVICE_ID
			,SERVICE_NAME
			,PATIENT_AGE
		
			FROM (


--Main EBSX Data query, includes query of EBSX data and joins for lookups, and use of row_number() split by ubrn_ID sorted by action_dt_tm descending to get latest record



----------Essentially a cleaning stage for nulls etc
		SELECT 
						 'ebsx02' as [data_source]
						,cast([UBRN_ID] as varchar) as [UBRN_ID]
						,[Pseudo_NHS_Number]
						,case when [DATE_DECISION_TO_REFER] = '' then Null
							  else [DATE_DECISION_TO_REFER] 
							  end as [DATE_DECISION_TO_REFER]
						,[PRIORITY] as [PRIORITY]
						,case 
							WHEN [SPECIALTY_CD] = '' then NULL
							ELSE [SPECIALTY_CD] END as [SPECIALTY_CD]
						,[SPECIALTY_DESC] as [SPECIALTY_DESC] 
						,[CLINIC_TYPE] as [CLINIC_TYPE]
						,REFERRING_ORG_ID as REFERRING_ORG_ID
						,ORG_REFERRING_PAT
						,[ACTION_DESC] as [ACTION_DESC]
						,[BUS_FUNCTION_ID] as [BUS_FUNCTION_ID]
						,[ORG_ID] as [ORG_ID] --org last updating
						,null as [referred_org_1b]
						,[ORG_REFERRED_TO]
						,case	when [APPT_DT_TM] = '' then null 
								else convert(varchar,[APPT_DT_TM])
							end as [APPT_DT_TM]	
						,null as [referral_rejection_date]
						,case	when [ACTION_DT_TM] = '' then null 
								else convert(varchar,[ACTION_DT_TM])
							end as [ACTION_DT_TM]      -------not sure if this needs amending to add the null argument	
						,action_cd
						,SERVICE_ID
						,SERVICE_NAME
						,PATIENT_AGE
	
						FROM (


SELECT 	
									'ebsx02' as [data_source] ---Manually added
									,a.[ubrn_id]
									,a.[UBRN]
									,nhs.[pseudo_nhs_number]
									,a.[DATE_DECISION_TO_REFER] 
									,a.[SPECIALTY_CD]
									,b.[DISPLAY] [SPECIALTY_DESC]
									,c.[DISPLAY] [CLINIC_TYPE]
									,d.DISPLAY [PRIORITY]
									,a.REFERRING_ORG_ID
									,j.ORG_NAME as ORG_REFERRING_PAT
									,a.action_cd
									,f.MEANING [ACTION_DESC]
									,g.MEANING [BUS_FUNCTION_ID]
									,a.ORG_ID
									,i.ORG_NAME as ORG_REFERRED_TO
									,a.APPT_DT_TM
									,a.ACTION_DT_TM
									,a.ACTION_ID
									,a.SERVICE_ID ---Added this one
									,h.SERVICE_NAME ---added this one
									,a.PATIENT_AGE ---Added this one
									,ROW_NUMBER() OVER (Partition by a.[ubrn_id] order by [action_id] desc) as [RN] ---Not necessarily needed

								FROM [Analyst_SQL_Area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX02_bnssg] a
								LEFT JOIN [analyst_sql_area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX03]  b on a.SPECIALTY_CD = b.CODE
								LEFT JOIN [analyst_sql_area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX03]  c on a.CLINIC_TYPE_CD = c.CODE
								LEFT JOIN [analyst_sql_area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX03]  d on a.PRIORITY_CD = d.CODE
								LEFT JOIN [analyst_sql_area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX03]  f on a.ACTION_CD = f.CODE
								LEFT JOIN [analyst_sql_area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX03]  g on a.BUS_FUNCTION_CD = g.CODE
								LEFT JOIN [Analyst_SQL_Area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX05] h on a.SERVICE_ID = h.SERVICE_ID  ---adding this for service_name for service_id
								LEFT JOIN [Analyst_SQL_Area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX04] i on a.ORG_ID = i.ORG_ID  ---adding this for organisation name referred to for ORG_ID, will do the same for referring_org_id
								LEFT JOIN [Analyst_SQL_Area].[dbo].[tbl_BNSSG_Datasets_eRefs_EBSX04] j on a.referring_org_id = j.ORG_ID  ---adding this for organisation name referred to for ORG_ID, will do the same for referring_org_id
								LEFT JOIN [ABI].[Supplementary].[EReferrals_EBSX13] nhs on a.UBRN_ID = nhs.UBRN_ID --bridging file
								) A
					)  A

			)A
 where Pseudo_NHS_Number is not null
 order by Pseudo_NHS_Number, ACTION_DT_TM, APPT_DT_TM

 ------------------------------------------------------------------
select *
from [MODELLING_SQL_AREA].[dbo].[JC_complete_ereferral]
 
 ------------------------------------------------------------------

 select a.* 
from [MODELLING_SQL_AREA].[dbo].[JC_complete_ereferral] a
inner join [MODELLING_SQL_AREA].[dbo].[JC_all_hip_replacements] b
on a.Pseudo_NHS_Number = b.AIMTC_Pseudo_NHS
