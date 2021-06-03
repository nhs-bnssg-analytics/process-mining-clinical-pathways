# Automated discovery of clinical pathways from routinely collected electronic health record data

![image](https://user-images.githubusercontent.com/68733783/120660826-a0a52400-c47f-11eb-92c5-81848c082a2b.png)

Code and outputs generated for the University of Bristol and NHS BNSSG CCG EBI funded project
This work was supported by the [Elizabeth Blackwell Institute](http://www.bristol.ac.uk/blackwell/), University of Bristol and the Wellcome Trust Institutional Strategic Support Fund. This project received funding through the Elizabeth Blackwell Institute Health Data Science research strand for their Autumn 2019 funding call for projects in health data science.

## Summary of Research
This project used process mining to analyse hip replacement pathways and applied existing data mining algorithms to discover processes or clinical pathways from electronic health records.

The data used for the project was the [BNSSG System Wide Dataset](https://bnssghealthiertogether.org.uk/population-health-management/#:~:text=The%20Bristol%2C%20North%20Somerset%20and,who%20have%20not%20opted%20out) which covers primary, secondary, community and mental health care records.

This research used bupaR - an open-source, integrated suite of R-packages for the handling and analysis of business process data - along with [PM4Py](https://pm4py.fit.fraunhofer.de/) in Python and SQL.


![image](https://user-images.githubusercontent.com/68733783/120673337-fcc17580-c48a-11eb-8755-15d4e24503d8.png)


A summary of available discovery algorithms in R are in the below table.


|**Process Discovery Algorithm** | **Features**                                                                                                                                             | **R Package**                                                                                                 |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| **Alpha Miner**                 | Only requires a sequence of activities                                                                                                               | PM4Py Python Modules                                                                                      |
|                             | One of the first process mining algorithms                                                                                                           |                                                                                                           |
|                             | Simple to apply                                                                                                                                      | Can connect using Reticulate and pm4py (Interface to the 'PM4py' Process   Mining Library)                |
|                             | Unable to deal with process loops (when a patient undergoes the same pattern of activity more than once)                                             |                                                                                                           |
|                             | Cannot handle noise and incompleteness                                                                                                               | Apply using bupaR package                                                                                 |
|                             | If there is a choice of activity can lead to problems in the resulting process                                                                       |                                                                                                           |
|                             | Model may not be sound                                                                                                                               |                                                                                                           |
| **Heuristic Miner**             | Takes frequencies of events/sequences into account so can handle noisy or infrequent behaviour                                                       | heuristicsmineR package through bupaR                                                                     |
|                             | Can detect short loops                                                                                                                               |                                                                                                           |
|                             | Allows skipping of single activities                                                                                                                 |                                                                                                           |
|                             | Can change parameters of the algorithm to produce different models e.g. if wanting to focus more on the mainstream behaviour or include more detail. |                                                                                                           |
|                             | Does not guarantee sound process models i.e. may not be able to replay all the cases in the event log                                                |                                                                                                           |
| **Fuzzy Miner**                 | An approach used to deal with spaghetti processes                                                                                                    | Currently not available on CRAN but GitHub version available - https://github.com/nirmalpatel/fuzzymineR  |
|                             | Have many different parameters that the user can set to determine what activities to include                                                         |                                                                                                           |
|                             | Can construct hierarchical models (i.e. less frequent activities can be moved to subprocesses) other algorithms produce ‘flat’ models                |                                                                                                           |
| **Inductive Miner**             | Can handle infrequent behaviour, deal with large event logs                                                                                          | PM4Py Python Module                                                                                       |
|                             | Ensures sound process models i.e. can replay the whole event log                                                                                     |                                                                                                           |
|                             | Uses different types of filtering and aims to show the mainstream behaviour.                                                                         | pm4py (Interface to the 'PM4py' Process Mining Library)                                                   |
|                             | There are a family of inductive mining algorithms with different properties.                                                                         |                                                                                                           |
|                             | Can construct hierarchical models (i.e. less frequent activities can be moved to subprocesses) other algorithms produce ‘flat’ models                | Apply using bupaR package                                                                                 |
|                             | Based on event log splitting                                                                                                                         |                                                                                                           |
|                             | Models tend to be simple/general but may create underfitting models                                                                                  |                                                                                                           |
|                             | Uses hidden transitions (for skipping/looping behaviour)                                                                                             |                                                                                                           |
