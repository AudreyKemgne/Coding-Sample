/*==============================================================================
 Project : Master's thesis - Populism in donor countries and bilateral ODA
 File    : 02_construction.do
 Purpose : Build variables (sector, financing channel, recipient region),
           collapse to donor x year, merge with populism data and create
           the analysis-ready dataset.
 Inputs  : data/clean/bilateral_donors_f.dta
           data/clean/populism_vote_share.dta
           data/clean/GPD_cleaned_fin.dta
           data/clean/Man_VA_95.dta, ChinaExport.dta
 Outputs : data/clean/bilateral_agg.dta        (donor x year aid aggregates)
           data/clean/Aid_populism.dta         (aid + populist vote share)
           data/clean/Aid_populism_score.dta   (aid + GPD score)
           data/clean/aid_populism_matched.dta (aid + both populism measures)
           data/clean/Aid_populism1.dta, Aid_populism2.dta (with context data)
           data/clean/Aid_populism_final.dta   (analysis dataset, with ln outcomes)
 Run     : after 01_clean.do
==============================================================================*/

clear all
set more off
version 16

if "${root}" == "" {
    display as error "Globals not defined. Run 00_master.do first."
    exit 198
}

*------------------------------------------------------------------------------
* Helper: report the size of the sample in memory (observations, donors, years)
* Used after each key step so that the sample counts can be checked in the log.
*------------------------------------------------------------------------------
capture program drop report_sample
program define report_sample
    args label

    quietly count
    local nobs = r(N)

    tempvar tag
    quietly egen `tag' = tag(donor_name)
    quietly count if `tag' == 1
    local ndon = r(N)

    quietly summarize year
    local ymin = r(min)
    local ymax = r(max)

    display as text _n "{hline 70}"
    display as text "SAMPLE [`label']"
    display as text "  Observations: " as result `nobs'  ///
            as text " | Donors: "      as result `ndon'  ///
            as text " | Years: "       as result "`ymin'-`ymax'"
    display as text "{hline 70}"
end

*==============================================================================
* A. TRANSACTION-LEVEL VARIABLES
*==============================================================================
use "$clean/bilateral_donors_f.dta", clear

rename year_name year

* Starting point: transaction-level data (observations = transactions)
report_sample "bilateral ODA transactions, before aggregation"

keep donor_name donor_id recipient_name recipient_id year ///
     usd_commitment usd_disbursement ///
     grant_type_name lvl_0_sector_name

*------------------------------------------------------------------------------
* A.1 Sector dummies
*------------------------------------------------------------------------------
gen aid_social = inlist(lvl_0_sector_name, ///
    "Education", ///
    "Health", ///
    "Water Supply & Sanitation", ///
    "Population Policies/Programmes & Reproductive Health", ///
    "Other Social Infrastructure & Services")

gen aid_governance = inlist(lvl_0_sector_name, ///
    "Government & Civil Society", ///
    "Conflict, Peace & Security", ///
    "Reconstruction Relief & Rehabilitation")

gen aid_economic = inlist(lvl_0_sector_name, ///
    "Energy", ///
    "Transport & Storage", ///
    "Banking & Financial Services", ///
    "Business & Other Services", ///
    "Communications", ///
    "Industry, Mining, Construction", ///
    "Other Economic Infrastructure & Services")

gen aid_humanitarian = inlist(lvl_0_sector_name, ///
    "Emergency Response", ///
    "Development Food Assistance", ///
    "Disaster Prevention & Preparedness", ///
    "Other Humanitarian Aid", ///
    "Refugees in Donor Countries")

gen aid_agriculture  = (lvl_0_sector_name == "Agriculture, Forestry, Fishing")
gen aid_environment  = (lvl_0_sector_name == "General Environment Protection")

gen aid_other = inlist(lvl_0_sector_name, ///
    "General Budget Support", ///
    "Trade Policies & Regulations", ///
    "Other Multi-Sector / Cross-Cutting", ///
    "Other Production Sectors", ///
    "Other Commodity Assistance", ///
    "Action Relating to Debt", ///
    "Administrative Costs of Donors", ///
    "Unallocated / Unspecified", ///
    "Tourism")

*------------------------------------------------------------------------------
* A.2 Financing channel dummies
*------------------------------------------------------------------------------
gen channel_grant     = (grant_type_name == "ODA Grants")
gen channel_loan      = (grant_type_name == "ODA Loans")
gen channel_off_flows = (grant_type_name == "Other Official Flows (non Export Credit)")
gen channel_private   = inlist(grant_type_name, ///
    "Private Development Finance", "Equity Investment")

*------------------------------------------------------------------------------
* A.3 Recipient region (World Bank classification)
*     Both UTF-8 and mis-encoded spellings are listed (Côte d'Ivoire, Türkiye)
*------------------------------------------------------------------------------
local ssa ///
"Angola|Benin|Botswana|Burkina Faso|Burundi|Cabo Verde|Cameroon|Central African Republic|Chad|Comoros|Congo|Côte d'Ivoire|CÃ´te d'Ivoire|Democratic Republic of the Congo|Equatorial Guinea|Eritrea|Eswatini|Ethiopia|Gabon|Gambia|Ghana|Guinea|Guinea-Bissau|Kenya|Lesotho|Liberia|Madagascar|Malawi|Mali|Mauritania|Mauritius|Mayotte|Mozambique|Namibia|Niger|Nigeria|Rwanda|Saint Helena|Sao Tome and Principe|Senegal|Seychelles|Sierra Leone|Somalia|South Africa|South Sudan|Sudan|Tanzania|Togo|Uganda|Zambia|Zimbabwe"

local eca ///
"Albania|Armenia|Azerbaijan|Belarus|Bosnia and Herzegovina|Croatia|Georgia|Kazakhstan|Kosovo|Kyrgyzstan|Moldova|Montenegro|Republic of North Macedonia|Serbia|Slovenia|Türkiye|TÃ¼rkiye|Ukraine|Uzbekistan|Turkmenistan|Tajikistan"

local mena ///
"Algeria|Bahrain|Djibouti|Egypt|Iran|Iraq|Jordan|Lebanon|Libya|Malta|Morocco|Oman|Saudi Arabia|Syrian Arab Republic|Tunisia|West Bank and Gaza Strip|Yemen"

local sa ///
"Afghanistan|Bangladesh|Bhutan|India|Maldives|Nepal|Pakistan|Sri Lanka"

local eap ///
"Cambodia|China \(People's Republic of\)|Democratic People's Republic of Korea|Indonesia|Kiribati|Lao People's Democratic Republic|Malaysia|Marshall Islands|Micronesia|Mongolia|Myanmar|Nauru|Palau|Papua New Guinea|Philippines|Samoa|Solomon Islands|Thailand|Timor-Leste|Tonga|Tuvalu|Vanuatu|Viet Nam|Cook Islands|Fiji|Niue|Tokelau|Wallis and Futuna"

local lac ///
"Anguilla|Antigua and Barbuda|Argentina|Barbados|Belize|Bolivia|Brazil|Chile|Colombia|Costa Rica|Cuba|Dominica|Dominican Republic|Ecuador|El Salvador|Grenada|Guatemala|Guyana|Haiti|Honduras|Jamaica|Mexico|Montserrat|Nicaragua|Panama|Paraguay|Peru|Saint Kitts and Nevis|Saint Lucia|Saint Vincent and the Grenadines|Suriname|Trinidad and Tobago|Turks and Caicos Islands|Uruguay|Venezuela"

gen str15 wb_region = ""

foreach reg in SSA ECA MENA SA EAP LAC {
    local lreg = lower("`reg'")
    replace wb_region = "`reg'" if regexm(recipient_name, "^(``lreg'')$")
}

* Regional / unspecified recipients
replace wb_region = "Regional" if strpos(lower(recipient_name), "regional") > 0
replace wb_region = "Regional" if recipient_name == "Developing countries unspecified"
replace wb_region = "Regional" if recipient_name == "States Ex-Yugoslavia unspecified"

* Checks: unclassified recipients
tab wb_region, missing
count if missing(wb_region)
levelsof recipient_name if missing(wb_region), clean

* Recipient region dummies
gen rec_ssa      = (wb_region == "SSA")
gen rec_mena     = (wb_region == "MENA")
gen rec_eca      = (wb_region == "ECA")
gen rec_sa       = (wb_region == "SA")
gen rec_eap      = (wb_region == "EAP")
gen rec_lac      = (wb_region == "LAC")
gen rec_regional = (wb_region == "Regional")

* Each transaction belongs to at most one region
egen check_regions = rowtotal(rec_*)
assert check_regions <= 1
tab check_regions
drop check_regions

*------------------------------------------------------------------------------
* A.4 Amounts by sector, financing channel and recipient region
*------------------------------------------------------------------------------
local sectors  social governance economic humanitarian agriculture environment other
local channels grant loan off_flows private
local regions  ssa mena eca sa eap lac regional

foreach s of local sectors {
    gen usd_commit_`s' = usd_commitment  * aid_`s'
    gen usd_disb_`s'   = usd_disbursement * aid_`s'
}
foreach c of local channels {
    gen usd_commit_`c' = usd_commitment  * channel_`c'
    gen usd_disb_`c'   = usd_disbursement * channel_`c'
}
foreach r of local regions {
    gen usd_commit_`r' = usd_commitment  * rec_`r'
    gen usd_disb_`r'   = usd_disbursement * rec_`r'
}

*==============================================================================
* B. COLLAPSE TO DONOR x YEAR
*==============================================================================
local sumvars usd_commitment usd_disbursement
foreach g in `sectors' `channels' `regions' {
    local sumvars `sumvars' usd_commit_`g' usd_disb_`g'
}

collapse (sum) `sumvars', by(donor_name donor_id year)

* Shares of total commitments (0 when total commitments are 0)
foreach g in `sectors' `channels' `regions' {
    gen sh_commit_`g' = usd_commit_`g' / usd_commitment
    replace sh_commit_`g' = 0 if missing(sh_commit_`g')
}

isid donor_name year
report_sample "after collapse to donor x year (all donor-years with ODA data)"
save "$clean/bilateral_agg.dta", replace


*==============================================================================
* C. MERGE WITH POPULISM DATA
*==============================================================================

*------------------------------------------------------------------------------
* C.1 Aid + populist vote share
*------------------------------------------------------------------------------
use "$clean/bilateral_agg.dta", clear
order donor_name year

duplicates report donor_name year
merge 1:1 donor_name year using "$clean/populism_vote_share.dta"
tab _merge

* Which donors lose observations at this merge? (useful to reconcile sample sizes)
quietly levelsof donor_name if _merge == 1, local(no_populism_data) clean
display as text _n "Donors with at least one ODA donor-year lacking vote-share data:"
display as result `"`no_populism_data'"'

keep if _merge == 3
drop _merge

* Populist dummies at three vote-share thresholds (in %)
foreach t in 50 40 25 {
    gen populist_`t' = (populism_share >= `t') if !missing(populism_share)
}
report_sample "aid + populist vote share (Aid_populism.dta)"
save "$clean/Aid_populism.dta", replace

*------------------------------------------------------------------------------
* C.2 Aid + GPD populism score
*------------------------------------------------------------------------------
use "$clean/bilateral_agg.dta", clear
order donor_name year

merge 1:1 donor_name year using "$clean/GPD_cleaned_fin.dta"
tab _merge
keep if _merge == 3
drop _merge

gen populist_1  = (populism_score >= 1.0) if !missing(populism_score)
gen populist_05 = (populism_score >= 0.5) if !missing(populism_score)
gen populist_06 = (populism_score >= 0.6) if !missing(populism_score)
report_sample "aid + GPD populism score (Aid_populism_score.dta)"
save "$clean/Aid_populism_score.dta", replace

*------------------------------------------------------------------------------
* C.3 Aid + both populism measures
*------------------------------------------------------------------------------
use "$clean/Aid_populism.dta", clear
order donor_name year

merge 1:1 donor_name year using "$clean/GPD_cleaned_fin.dta"
tab _merge
keep if _merge == 3
drop _merge

gen populist_1  = (populism_score >= 1.0) if !missing(populism_score)
gen populist_05 = (populism_score >= 0.5) if !missing(populism_score)
gen populist_06 = (populism_score >= 0.6) if !missing(populism_score)
report_sample "aid + vote share + GPD score (aid_populism_matched.dta)"
save "$clean/aid_populism_matched.dta", replace


*==============================================================================
* D. MERGE WITH CONTEXT DATA (manufacturing VA 1995, trade with China)
*==============================================================================
use "$clean/Aid_populism.dta", clear

merge m:1 donor_name using "$clean/Man_VA_95.dta"
tab _merge
keep if _merge == 3
drop _merge
save "$clean/Aid_populism1.dta", replace

* CHECK: the original code merged on -year- only (m:1 year), which requires
* ChinaExport to be unique by year. Here we merge on donor_name and year.
use "$clean/Aid_populism1.dta", clear

merge m:1 donor_name year using "$clean/ChinaExport.dta"
tab _merge
keep if _merge == 3
drop _merge
save "$clean/Aid_populism2.dta", replace


*==============================================================================
* E. ANALYSIS DATASET: OUTCOME VARIABLES (log of 1 + disbursements)
*==============================================================================
use "$clean/Aid_populism.dta", clear

sort donor_id year
xtset donor_id year

gen ln_oda = log(usd_disbursement + 1)

foreach v in social economic humanitarian governance agriculture environment ///
             grant loan ssa mena eca sa eap lac regional {
    gen ln_usd_disb_`v' = log(usd_disb_`v' + 1)
}

*------------------------------------------------------------------------------
* Final sample check
* Thesis (Section 3.1): 422 donor-year observations, 28 donors, 2002-2021
*------------------------------------------------------------------------------
report_sample "FINAL analysis dataset (Aid_populism_final.dta)"

display as text "Expected from thesis: 422 observations, 28 donors, 2002-2021"
display as text "Observations per donor (compare with Appendix Table 7):"
tab donor_name

save "$clean/Aid_populism_final.dta", replace
