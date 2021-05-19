#---------------------------------------------------------------------------------------------------------------------------
#Process Discovery
#---------------------------------------------------------------------------------------------------------------------------
#Libraries (mainly from BupaR suite of packages)
#---------------------------------------------------------------------------------------------------------------------------
library(bupaR)
library(eventdataR)
library(xesreadR)
library(edeaR)
library(processmapR)
library(processmonitR)
library(svgPanZoom)
library(DiagrammeRsvg)
library(heuristicsmineR)
library(petrinetR)
library(DiagrammeR)
library(dplyr)
#---------------------------------------------------------------------------------------------------------------------------
#Reticulate and PM4Py setup for connecting to Python
#Required for conformance checking of Heuristics Miner and for the Inductive Miner algorithm
#---------------------------------------------------------------------------------------------------------------------------
#Steps required as of 01/04/2021:
#1 Install Python on the machine
#2 Install Reticulate through R it will automatically make a Python environment.
#3 Make sure the paths point to this environment and the right version of Python for that environment for reticulate
#4 Download Microsoft Visual Studio C++ builder 14.00 onto your PC if this comes up as an error/not available on your PC
# https://visualstudio.microsoft.com/visual-cpp-build-tools/ 
#  (https://stackoverflow.com/questions/48541801/microsoft-visual-c-14-0-is-required-get-it-with-microsoft-visual-c-build-t) 
#5 Use Windows command prompt to install 'ortools' using pip install and ensure it installs to the right path
#6 Follow instructions on bupaR webpage to install pm4py (Correct version) https://www.bupar.net/pm4py.html 

install.packages("reticulate")
library(reticulate)

library(pm4py)
pm4py::install_pm4py()

#---------------------------------------------------------------------------------------------------------------------------
#Read in cleaned data which is in event log form and has been enriched with attributes
#---------------------------------------------------------------------------------------------------------------------------
hip_pathway<-readRDS("hip_pathway_enriched.rds")
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

#---------------------------------------------------------------------------------------------------------------------------
#Reduced activities identified from the heuristics model (with 0.5 threshold)
#---------------------------------------------------------------------------------------------------------------------------

selected_activity2<- c("APPT_made",
                       "community_musculoskeletal service",
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


#---------------------------------------------------------------------------------------------------------------------------
#[1] Heuristics miner
#---------------------------------------------------------------------------------------------------------------------------
#Filtering event log for the selected activities
hip_log %>% filter_activity(selected_activity) -> selected_activity_log
#Ensuring additional levels are not in the model after reducing the activities (can become a problem for inductive miner)
selected_activity_log$activity<- factor(selected_activity_log$activity) 
selected_activity_log$status<- factor(selected_activity_log$status) 
#---------------------------------------------------------------------------------------------------------------------------
#Filtering event log for the selected activities
#Reduced activities identified from the heuristics model (with 0.5 threshold)
hip_log %>% filter_activity(selected_activity2) -> selected_activity_log2 
#Ensuring additional levels are not in the model after reducing the activities (can become a problem for inductive miner)
selected_activity_log2$activity<- factor(selected_activity_log2$activity) 
selected_activity_log2$status<- factor(selected_activity_log2$status) 

#---------------------------------------------------------------------------------------------------------------------------
# Exploring Dependency graph / matrix for the selected_activity_log
#---------------------------------------------------------------------------------------------------------------------------
# Dependency graph / matrix
dependency_matrix(selected_activity_log) %>% render_dependency_matrix()
# Causal graph / Heuristics net
causal_net(selected_activity_log) %>% render_causal_net()
# Efficient precedence matrix
m <- precedence_matrix_absolute(selected_activity_log)
as.matrix(m)
#---------------------------------------------------------------------------------------------------------------------------
#Setting different dependency value thresholds for the Heuristics Miner model
#---------------------------------------------------------------------------------------------------------------------------
# Dependency graph / matrix

dependency_matrix(selected_activity_log, threshold = 0.5) %>% 
  render_dependency_matrix()%>% 
  DiagrammeRsvg::export_svg() %>% #These lines allow you to zoom in on more complex models
  svgPanZoom::svgPanZoom() #These lines allow you to zoom in on more complex models

#---------------------------------------------------------------------------------------------------------------------------
#Changing parameters of the model
#all_connected - if TRUE the best antecedent and consequent (as determined by dependency measure) are going to be added

#`Or there is an `endpoints_connected` parameter when generating the dependency matrix.
#---------------------------------------------------------------------------------------------------------------------------

dependency_matrix(selected_activity_log, threshold = 0.6, 
                  dependency_type = dependency_type_fhm(all_connected = TRUE)) %>% 
  render_dependency_matrix()%>% 
  DiagrammeRsvg::export_svg() %>% 
  svgPanZoom::svgPanZoom()

#---------------------------------------------------------------------------------------------------------------------------
#Visualising a dependency matrix
#Higher dependency threshold means fewer activities
#higher threshold essentially asking for a more common path
#---------------------------------------------------------------------------------------------------------------------------
#This will show all dependency values as threshold set at 0.0

plot(dependency_matrix(selected_activity_log, threshold = 0.0, 
                       dependency_type = dependency_type_fhm(all_connected = TRUE)))
#---------------------------------------------------------------------------------------------------------------------------
# Final Causal graph / Heuristics net for dependency threshold 0.5
#---------------------------------------------------------------------------------------------------------------------------

causal_net(selected_activity_log, threshold = 0.5) %>% render_causal_net() %>% 
  DiagrammeRsvg::export_svg() %>% 
  svgPanZoom::svgPanZoom()

#---------------------------------------------------------------------------------------------------------------------------
#Can be converted to a Petri Net as more formalised notation and for conformance checking
#---------------------------------------------------------------------------------------------------------------------------
cn <- causal_net(selected_activity_log2, threshold = 0.5)
pn <- as.petrinet(cn)

render_PN(pn) %>% 
  DiagrammeRsvg::export_svg() %>% 
  svgPanZoom::svgPanZoom()

pn[["places"]][["id"]] #To determine final marking (will be the last "p_in_x)
#---------------------------------------------------------------------------------------------------------------------------
#Conformance checking
#Requires PM4Py from Python and so reticulate needs to be set up appropriately
#Along with Python and the appropriate modules
#---------------------------------------------------------------------------------------------------------------------------
library(pm4py)
conformance_alignment(selected_activity_log2, pn, 
                      initial_marking = pn$marking, 
                      final_marking = c("p_in_14")) #final marking determined from code above

#---------------------------------------------------------------------------------------------------------------------------
#[2] Inductive Miner
#---------------------------------------------------------------------------------------------------------------------------

selected_activity_log %>% 
  filter(status=="complete") -> patients_completes

#drop levels for status and activity for the subsetted dataframe, or the resulting models will include the original labels

patients_completes$activity<- factor(patients_completes$activity) 
patients_completes$status<- factor(patients_completes$status) 
#---------------------------------------------------------------------------------------------------------------------------
#Inductive Miner algorithm using Python PM4Py
#---------------------------------------------------------------------------------------------------------------------------
#The basic inductive miner code
discovery_inductive(patients_completes, variant = variant_inductive_imdfb()) -> PN

PN %>% str

PN$petrinet %>% render_PN()%>%  DiagrammeRsvg::export_svg() %>% 
  svgPanZoom::svgPanZoom()
#---------------------------------------------------------------------------------------------------------------------------
#Extended Inductive Miner code
#---------------------------------------------------------------------------------------------------------------------------
# Discovery with Inductive Miner
pn <- discovery_inductive(patients_completes)
#variant = variant_inductive_imdfb() is currently the only variant

# This results in an auto-converted bupaR Petri net and markings
str(pn)
class(pn$petrinet)

# Render with bupaR
render_PN(pn$petrinet)

# Render with PM4Py and DiagrammeR
library(DiagrammeR)
viz <- reticulate::import("pm4py.visualization.petrinet")

# Convert back to Python
py_pn <- r_to_py(pn$petrinet)
class(py_pn)

# Render to DOT with PM4Py
dot <- viz$factory$apply(py_pn)$source
grViz(diagram = dot)
#---------------------------------------------------------------------------------------------------------------------------
#Compute alignments and model quality
#---------------------------------------------------------------------------------------------------------------------------
# Compute alignment
alignment <- conformance_alignment(patients_completes, pn$petrinet, pn$initial_marking, pn$final_marking)

# # Alignment is returned in long format as data frame
head(alignment)

# Evaluate model quality
quality <- evaluation_all(patients_completes, pn$petrinet, pn$initial_marking, pn$final_marking)

#---------------------------------------------------------------------------------------------------------------------------
#End
#---------------------------------------------------------------------------------------------------------------------------
