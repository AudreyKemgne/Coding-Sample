/*==============================================================================
 Project : Master's thesis - Populism in donor countries and bilateral ODA
 File    : 01_clean.do
 Purpose : Import, append and clean all raw data sources.
 Inputs  : data/raw/*.csv        (ODA files, one per donor)
           data/raw/GPD_v2.1_20251120.csv   (Global Populism Database)
           data/raw/populism_share.xlsx     (populist vote share)
           data/raw/Employment_95.xlsx, Manufacture_VA.xlsx, China_total_trade.csv
 Outputs : data/clean/all_donors.dta
           data/clean/bilateral_donors_f.dta
           data/clean/GPD_cleaned_fin.dta
           data/clean/populism_vote_share.dta
           data/clean/Employment_95.dta, Man_VA_95.dta, ChinaExport.dta
 Run     : after 00_master.do (globals must be defined)
==============================================================================*/

clear all
set more off
version 16

if "${root}" == "" {
    display as error "Globals not defined. Run 00_master.do first."
    exit 198
}

*==============================================================================
* A. ODA DATA: IMPORT AND APPEND ALL DONOR FILES
*==============================================================================

*------------------------------------------------------------------------------
* A.1 Helper program: import one donor file and harmonise variable types
*------------------------------------------------------------------------------
capture program drop import_oda_file
program define import_oda_file
    args fname is_multilateral

    import delimited "$raw/`fname'", clear varnames(1)

    * Structure checks
    confirm variable id
    confirm variable donor_name

    * These two variables are sometimes read as numeric (all missing) -> force string
    foreach v in lvl_1_sector_name long_description {
        capture confirm string variable `v'
        if _rc {
            tostring `v', replace
        }
    }

    * Donor type indicator (value labels are lost by -clear-, so define here)
    gen byte multilateral = `is_multilateral'
    label define multilateral_lbl 0 "National" 1 "Multilateral", replace
    label values multilateral multilateral_lbl

    order id donor_name multilateral
end

*------------------------------------------------------------------------------
* A.2 File lists
*------------------------------------------------------------------------------
local multilateral_files ///
    adaptation-fund.csv ///
    african-development-bank.csv ///
    african-development-fund.csv ///
    arab-bank-for-economic-development-in-africa.csv ///
    arab-fund-afesd.csv ///
    asian-development-bank.csv ///
    asian-infrastructure-investment-bank.csv ///
    caribbean-development-bank.csv ///
    center-of-excellence-in-finance.csv ///
    central-emergency-response-fund.csv ///
    climate-investment-funds.csv ///
    council-of-europe-development-bank.csv ///
    development-bank-of-latin-america.csv ///
    european-bank-for-reconstruction-and-development.csv ///
    european-investment-bank-eib.csv ///
    food-and-agriculture-organisation.csv ///
    global-alliance-for-vaccines-and-immunization.csv ///
    global-environment-facility.csv ///
    global-fund.csv ///
    global-green-growth-institute.csv ///
    green-climate-fund.csv ///
    idb-invest.csv ///
    imf-concessional-trust-funds.csv ///
    inter-american-development-bank.csv ///
    international-atomic-energy-agency.csv ///
    international-bank-for-reconstruction-and-development.csv ///
    international-development-association.csv ///
    international-finance-corporation.csv ///
    international-fund-for-agricultural-development-ifad.csv ///
    international-labour-organisation.csv ///
    islamic-development-bank.csv ///
    joint-united-nations-programme-on-hiv-aids-unaids.csv ///
    montreal-protocol.csv ///
    nordic-development-fund.csv ///
    opec-fund-for-international-development.csv ///
    organization-for-security-and-co-operation-in-europe-osce.csv ///
    un-environment-programme-unep.csv ///
    un-peacebuilding-fund.csv ///
    united-nations-children-s-fund-unicef.csv ///
    united-nations-high-commissioner-for-refugees-unhcr.csv ///
    united-nations-population-fund-unfpa.csv ///
    united-nations-relief-and-works-agency-for-palestine-refugees-in-the-near-east-unrwa.csv ///
    world-food-programme-wfp.csv ///
    world-health-organisation-who.csv ///
    world-tourism-organisation-wto.csv

local national_files ///
    australia.csv austria.csv azerbaijan.csv belgium.csv bulgaria.csv ///
    canada.csv croatia.csv cyprus.csv czech-republic.csv denmark.csv ///
    eu-institutions-excl-eib.csv estonia.csv finland.csv france.csv ///
    germany.csv greece.csv hungary.csv iceland.csv ireland.csv israel.csv ///
    italy.csv japan.csv kazakhstan.csv korea.csv kuwait.csv latvia.csv ///
    liechtenstein.csv lithuania.csv luxembourg.csv malta.csv netherlands.csv ///
    new-zealand.csv norway.csv poland.csv portugal.csv romania.csv russia.csv ///
    saudi-arabia.csv slovak-republic.csv slovenia.csv spain.csv sweden.csv ///
    switzerland.csv taiwan.csv thailand.csv timor-leste.csv turkiye.csv ///
    united-arab-emirates.csv united-kingdom.csv united-states.csv

*------------------------------------------------------------------------------
* A.3 Append multilateral donors, then national (bilateral) donors
*------------------------------------------------------------------------------
tempfile oda
local first = 1

foreach f of local multilateral_files {
    display as text "Importing multilateral donor: `f'"
    import_oda_file `f' 1
    if `first' == 0 {
        append using `oda'
    }
    save `oda', replace
    local first = 0
}

foreach f of local national_files {
    display as text "Importing national donor: `f'"
    import_oda_file `f' 0
    append using `oda'
    save `oda', replace
}

use `oda', clear
save "$clean/all_donors.dta", replace

* Quick checks
tab multilateral
tab donor_name multilateral

*------------------------------------------------------------------------------
* A.4 Keep bilateral (national) donors only
*------------------------------------------------------------------------------
keep if multilateral == 0
save "$clean/bilateral_donors.dta", replace


*==============================================================================
* B. CLEAN BILATERAL DONOR NAMES
*==============================================================================
use "$clean/bilateral_donors.dta", clear

* Harmonise country names with the populism datasets
replace donor_name = "Czechia"   if donor_name == "Czech Republic"
replace donor_name = "Slovakia"  if donor_name == "Slovak Republic"
replace donor_name = "Turkey"    if inlist(donor_name, "Türkiye", "TÃ¼rkiye")

* Drop non-country observations
drop if donor_name == "EU Institutions (excl. EIB)"

save "$clean/bilateral_donors_f.dta", replace


*==============================================================================
* C. GLOBAL POPULISM DATABASE (GPD): LEADER-LEVEL POPULISM SCORE
*==============================================================================
import delimited "$raw/GPD_v2.1_20251120.csv", clear

rename country donor_name

* Mandate level (country x term): keep the president if there is one,
* otherwise keep the prime minister
bysort donor_name yearbegin yearend: egen has_pres = max(president)
keep if (has_pres == 1 & president == 1) | (has_pres == 0 & president == 0)
drop has_pres

* "current" mandates end in the last calendar year of the data
replace yearend = "2025" if yearend == "current"
destring yearend, replace

* One row per leader-term
bysort donor_name leader yearbegin yearend: keep if _n == 1

* Fix overlapping mandates: a new mandate starts the year after the previous one ends
sort donor_name yearbegin yearend
gen overlap = 0
by donor_name: replace overlap = 1 if _n > 1 & yearbegin <= yearend[_n-1]
by donor_name: replace yearbegin = yearend[_n-1] + 1 if overlap == 1 & yearbegin < yearend
drop overlap

rename totalaverage populism_score

* Expand to a country-year panel (one row per year of each mandate)
gen term_length = yearend - yearbegin + 1
expand term_length
bysort donor_name leader yearbegin: gen year = yearbegin + _n - 1

keep donor_name leader year yearbegin yearend populism_score term_length
order donor_name year
save "$clean/GPD_cleaned.dta", replace

* One observation per country-year (if two mandates overlap in a year, keep the first)
use "$clean/GPD_cleaned.dta", clear
describe donor_name year
bysort donor_name year: keep if _n == 1
replace donor_name = "United Kingdom" if donor_name == "UK"

isid donor_name year
save "$clean/GPD_cleaned_fin.dta", replace


*==============================================================================
* D. POPULIST VOTE SHARE (country x year)
*==============================================================================
import excel "$raw/populism_share.xlsx", sheet("Feuil1") firstrow clear

rename A country_code

* Columns B:CA hold one year each; the year is stored in the variable label
foreach var of varlist B-CA {
    local yr : variable label `var'
    capture confirm number `yr'
    if !_rc {
        rename `var' y`yr'
    }
}
destring y*, replace force

* Wide -> long
reshape long y, i(country_code) j(year)
rename y populism_share
destring populism_share, replace force

* Country codes -> country names (same spelling as the ODA data)
gen donor_name = ""
replace donor_name = "Australia"       if country_code == "AU"
replace donor_name = "Austria"         if country_code == "AT"
replace donor_name = "Belgium"         if country_code == "BE"
replace donor_name = "Bulgaria"        if country_code == "BG"
replace donor_name = "Canada"          if country_code == "CA"
replace donor_name = "Croatia"         if country_code == "HR"
replace donor_name = "Cyprus"          if country_code == "CY"
replace donor_name = "Czechia"         if country_code == "CZ"
replace donor_name = "Denmark"         if country_code == "DK"
replace donor_name = "Estonia"         if country_code == "EE"
replace donor_name = "Finland"         if country_code == "FI"
replace donor_name = "France"          if country_code == "FR"
replace donor_name = "Germany"         if country_code == "DE"
replace donor_name = "Greece"          if country_code == "EL"
replace donor_name = "Hungary"         if country_code == "HU"
replace donor_name = "Ireland"         if country_code == "IE"
replace donor_name = "Italy"           if country_code == "IT"
replace donor_name = "Japan"           if country_code == "JP"
replace donor_name = "Korea"           if country_code == "KR"
replace donor_name = "Latvia"          if country_code == "LV"
replace donor_name = "Lithuania"       if country_code == "LT"
replace donor_name = "Netherlands"     if country_code == "NL"
replace donor_name = "New Zealand"     if country_code == "NZ"
replace donor_name = "Norway"          if country_code == "NO"
replace donor_name = "Poland"          if country_code == "PL"
replace donor_name = "Portugal"        if country_code == "PT"
replace donor_name = "Romania"         if country_code == "RO"
replace donor_name = "Slovakia"        if country_code == "SK"
replace donor_name = "Slovenia"        if country_code == "SI"
replace donor_name = "Spain"           if country_code == "ES"
replace donor_name = "Sweden"          if country_code == "SE"
replace donor_name = "Switzerland"     if country_code == "CH"
replace donor_name = "Turkey"          if country_code == "TR"
replace donor_name = "United Kingdom"  if country_code == "UK"
replace donor_name = "United States"   if country_code == "US"

drop if missing(donor_name)
keep donor_name year populism_share
order donor_name year
sort donor_name year

isid donor_name year
save "$clean/populism_vote_share.dta", replace


*==============================================================================
* E. CONTEXT DATA (employment, manufacturing value added, trade with China)
*==============================================================================

* Employment (1995)
import excel "$raw/Employment_95.xlsx", sheet("Table") firstrow clear
rename Economicactivity donor_name
save "$clean/Employment_95.dta", replace

* Manufacturing value added (1995)
import excel "$raw/Manufacture_VA.xlsx", sheet("Table") firstrow clear
rename Country donor_name
save "$clean/Man_VA_95.dta", replace

* Trade with China
import delimited "$raw/China_total_trade.csv", clear
keep partnername year tradevaluein1000usd
rename partnername donor_name
rename tradevaluein1000usd ChinaExport
save "$clean/ChinaExport.dta", replace
