################################################################################

# DeptOfEduEligibility_download_transform.R
# Julie Kellner
# Last modified September 6, 2024

# This R code will download the past 3 years of fiscal year eligibility matrix data files
# and most recent MSEIP Eligibility Institutions from the Department of Education
# Note: older years have a different format so this code will not work on those files

# This code was tested and works on data eligibility files from 2022-2024
# and MSEIP file from 2023 (2022 and 2024 were not available)

# The code then processes each sheet in the downloaded eligibility files,
# adds a column for the year and original datafile,
# takes the General Eligibility (only Yes and Elgible)
# and the HBCU/TCCU columns for each year,
# and combines into a single dataset 
# of columns Institution Name, UnitID, GENERAL ELIGIBILITY, year, datafile, sheet
# where the sheet column is AANAPISI, ANNH, HSI, NASNTI, PBI, SIP, and MSEIP eligibility
# and HBCU and TCCU

# Output saved includes original downloaded files
# And 1 new file of eligible institutions for all years

# Original Data Source:
# Eligibility Designations and Applications for Waiver of Eligibility Requirements
# https://www2.ed.gov/about/offices/list/ope/idues/eligibility.html#el-inst

# The FY Eligibility Matrix consists of:
#   
# Asian American and Native American Pacific Islander Serving Institutions (AANAPISI) 
# AANAPISI – Asian and Pacific Islander UG enrollment equal to or greater than 10%.
# 
# Alaska Native and Native Hawaiian Serving Institutions (ANNH) 
# ANNH – Alaska Native UG enrollment equal to or greater than 20% and Native Hawaiian UG enrollment equal to or greater than 10%.
# 
# Hispanic Serving Institutions (HSI) 
# HSI, HSI Stem and PPOHA – Hispanic FT UG enrollment equal to or greater than 25%.
# 
# Native American Serving Non-Tribal Institutions (NASNTI) 
# NASNTI - Native American UG enrollment equal to or greater than 10%.
# 
# Predominantly Black Institutions (PBI) 
# PBI and PBI-MA – Black enrollment equal to or greater than 40%, at least 1,000 undergraduate students, and meets the additional requirements list in the PBI statute.
# 
# Strengthening Institutions Program (SIP)
# an institution must have at least 50 percent of its degree students receiving need-based assistance, 
# or have a substantial number of enrolled students receiving Pell Grants, and have low educational and general expenditures. 
# 
# The FY Eligibility Matrix also includes the statutory lists of: 
# Historically Black Colleges and Universities (HBCU) 
# Tribally Controlled Colleges and Universities (TCCU) 
# 
# The FY Eligible Institutions for the Minority Science Engineering Improvement Program (MSEIP)
# MSEIP – Total minority enrollment (except Asian) equal to or greater than 50%.

################################################################################

#Load libraries
library(httr)
#library(utils)
#library(readr)
library(readxl)
library(tidyverse)
library(RCurl)

# Make directory to store downloaded files
main_dir <- "~/Downloads"
sub_dir <- paste0("DeptOfEduEligibilityMatrix_download_", format(Sys.time(),format="%Y-%m-%d"))
dir.create(file.path(main_dir, sub_dir))
setwd(file.path(main_dir, sub_dir))
rm(main_dir,sub_dir)

# Get current and past years of datafiles for current and past years
# Read the sheet names
# Import into R
# Append columns for year, original filename and sheet

number_of_pastyears = 2 # year 0 is current year
current_year <- as.numeric(format(Sys.time(),format="%Y"))
files = c("eligibilitymatrix","mseipeligibility")

for (i in 0:number_of_pastyears) {
  for (ii in 1:length(files)) {
    filename <- paste0(current_year - i, files[ii], ".xlsx")
    url <-
      paste0("https://www2.ed.gov/about/offices/list/ope/idues/",filename)
    if (url.exists(url) == TRUE) {
      GET(url, write_disk(filename, overwrite = TRUE))
      excelsheets <- excel_sheets(filename)
      excelsheets <- excelsheets[excelsheets != "Program Interactions"] # remove the program interactions sheet
      
      for (iii in 1:length(excelsheets)) {
        temp <- read_excel(filename, sheet = excelsheets[iii])
        temp <- temp[is.na(temp[,1]) == FALSE,] #remove every row where value in first column is NA
        colnames(temp) <- temp[1,] #column names are in the first row
        temp <- temp[- 1, ] #remove first row
        temp$year <- current_year - i
        temp$datafile <- gsub(".xlsx", "", filename)
        temp$sheet <- excelsheets[iii]
        
        # fix typo in some datasets (e.g. in some imported HSI sheets, may be in others)
        if("GENERAL ELIGIBLITY" %in% colnames(temp)) {
          temp$`GENERAL ELIGIBILITY` <- temp$`GENERAL ELIGIBLITY`
          temp$`GENERAL ELIGIBLITY` <- NULL
        }
        
        # assign temp to a dataframe
        assign(paste0(files[ii],current_year - i,"_",excelsheets[iii]),temp)
        
      }
    }
  }
}
rm(temp,i,ii,iii,excelsheets,url,files,filename)


# Create eligibility matrix for all years

list_df <- mget(ls(pattern = "HBCU"))
temp <- bind_rows(list_df)
rm(list_df,list=ls(pattern="HBCU"))
HBCU <- temp
HBCU$"GENERAL ELIGIBILITY" <- HBCU$"HBCU/\r\nHBGI"
HBCU$"HBCU/\r\nHBGI" <- NULL
HBCU <- HBCU[,c("Institution Name","UnitID","GENERAL ELIGIBILITY","year","datafile","sheet")]

list_df <- mget(ls(pattern = "TCCU"))
temp <- bind_rows(list_df)
rm(list_df,list=ls(pattern="TCCU"))
TCCU <- temp
TCCU$"GENERAL ELIGIBILITY" <- TCCU$"TCCU List"
TCCU$"TCCU List" <- NULL
TCCU <- TCCU[,c("Institution Name","UnitID","GENERAL ELIGIBILITY","year","datafile","sheet")]

# AANAPISI, ANNH, HSI, NASNTI, PBI, SIP, MSEIP
list_df <- mget(ls(pattern = "elig"))
columns = c("Institution Name","UnitID","GENERAL ELIGIBILITY","year","datafile","sheet")
list_df <- lapply(list_df, "[", columns)
temp <- bind_rows(list_df)
rm(list_df,list=ls(pattern="elig"))
ELIGIBILITY <- temp

rm(temp, columns)

# Filter general eligibility column by Yes and Eligible only
# and combine with HBCU and TCCU

# unique(ELIGIBILITY$`GENERAL ELIGIBILITY`)
# [1] "Yes"                                 
# [2] "No"                                  
# [3] "Eligible, Exemption Request Approved"
# [4] "Eligible, Application Approved"      
# [5] "Eligible, via IPEDS data"            
# [6] "Ineligible, but Receives FCS Waiver"
# [7] "Ineligible, Exemption Request Denied"
# [8] "Not Eligible"
# FCS means Federal Cost-Share

ELIGIBLE <- do.call("rbind", list(HBCU, 
                                  TCCU, 
                                  filter(ELIGIBILITY, `GENERAL ELIGIBILITY` == "Yes"), 
                                  filter(ELIGIBILITY, startsWith(`GENERAL ELIGIBILITY`, "Elig") == TRUE)
                                  ))

rm(ELIGIBILITY, HBCU, TCCU, current_year, number_of_pastyears)

# export each dataframe as csv
main_dir <- "~/Downloads"
sub_dir <- paste0("DeptOfEduEligibilityMatrix_export_transform", format(Sys.time(),format="%Y-%m-%d"))
dir.create(file.path(main_dir, sub_dir))
setwd(file.path(main_dir, sub_dir))
rm(main_dir,sub_dir)

list_df <- mget(ls(pattern = ""))

list_df %>% 
  names(.) %>% 
  map(~ write_csv(list_df[[.]], paste0( ., ".csv")))

rm(list_df)


