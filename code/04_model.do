/*==============================================================================
 Project : Master's thesis - Populism in donor countries and bilateral ODA
 File    : 04_model.do
 Purpose : Baseline event-study (TWFE) of a populist shock on ODA:
           (1) treatment definition and event window, (2) global effect,
           (3) sectoral effects, (4) recipient-region effects.
 Inputs  : data/clean/Aid_populism_final.dta
 Outputs : data/clean/Aid_populism_es.dta       (event-study sample)
           output/est/es_*.ster                  (stored estimates)
           output/figures/es_*.png
           output/tables/table_es_*.tex
 Run     : after 03_analysis.do

 Event-time coding (shift = event_time + 5):
     shift  0  1  2  3 | 4 |  5  6  7  8  9 10
     t     -5 -4 -3 -2 |-1 |  0 +1 +2 +3 +4 +5
 Reference period: t = -1 (shift = 4).
==============================================================================*/

clear all
set more off
version 16

if "${root}" == "" {
    display as error "Globals not defined. Run 00_master.do first."
    exit 198
}

*==============================================================================
* A. HELPER PROGRAMS
*==============================================================================

* A.1 Estimate the event study for one outcome, store results, test pre-trends
capture program drop run_es
program define run_es
    syntax varname, TAG(name)

    reghdfe `varlist' i.event_time_shift, absorb(donor_id year) cluster(donor_id)
    estimates store es_`tag'
    estimates save "$est/es_`tag'", replace

    * H0: all pre-treatment coefficients (t = -5 ... -2) are jointly zero
    testparm i(0/3).event_time_shift
    local p : display %4.3f r(p)
    c_local pval_`tag' "`p'"
end

* A.2 Plot the event-study coefficients of one stored model
capture program drop plot_es
program define plot_es
    syntax anything(name=tag), PVAL(string) FILE(string) [TITLE(string)]

    coefplot es_`tag',                                          ///
        keep(*event_time_shift*) baselevels vertical            ///
        yline(0, lcolor(black) lpattern(dash))                  ///
        xline(5.5, lcolor(red) lpattern(dot))                   ///
        ciopts(recast(rcap) lwidth(medthin))                    ///
        xlabel(1 "-5" 2 "-4" 3 "-3" 4 "-2" 5 "-1 (ref)"         ///
               6 "0" 7 "1" 8 "2" 9 "3" 10 "4" 11 "5",           ///
               noticks labsize(small) angle(45))                ///
        xtitle("Years relative to populist shock", size(small)) ///
        ytitle("Effect on ln(ODA)", size(small))                ///
        note("Pre-trends p = `pval'", size(vsmall))             ///
        title("`title'", size(medsmall))                        ///
        legend(off) graphregion(color(white))                   ///
        name(g_`tag', replace)

    graph export "$figures/`file'.png", replace
end


*==============================================================================
* B. TREATMENT DEFINITION AND EVENT WINDOW
*==============================================================================
use "$clean/Aid_populism_final.dta", clear
sort donor_id year
xtset donor_id year

*------------------------------------------------------------------------------
* B.1 Absorbing treatment: populist vote share > 50%
*------------------------------------------------------------------------------
gen above = (populism_share > 50) if !missing(populism_share)

* Drop donors that leave treatment after entering it (treatment must be absorbing)
bysort donor_id (year): gen switch_out = (above[_n-1] == 1 & above == 0)
bysort donor_id: egen has_switch = max(switch_out)
tab has_switch
drop if has_switch == 1
drop switch_out has_switch

* treated = 1 if the donor ever crosses the threshold (0 = never-treated controls)
bysort donor_id: egen treated = max(above)
drop above

*------------------------------------------------------------------------------
* B.2 First treatment year (missing for never-treated donors)
*------------------------------------------------------------------------------
* NB: missing values count as "> 50" in Stata, hence the !missing() condition
gen temp = year if populism_share > 50 & !missing(populism_share)
bysort donor_id: egen first_treat = min(temp)
drop temp

tab first_treat if treated == 1      // > 1 cohort => staggered adoption

*------------------------------------------------------------------------------
* B.3 Event time and window [-5, +5]
*------------------------------------------------------------------------------
gen event_time = year - first_treat

* Keep treated donors inside the window and all never-treated donors
keep if (event_time >= -5 & event_time <= 5) | missing(first_treat)

gen event_time_shift = event_time + 5 if !missing(event_time)
fvset base 4 event_time_shift

* CHECK: never-treated donors have a missing event_time_shift. Stata drops
* observations with a missing factor variable, so they are NOT in the
* regressions below (the original comment assumed they were kept and absorbed
* by the fixed effects). To keep them as controls, add:
*       replace event_time_shift = 4 if missing(first_treat)

save "$clean/Aid_populism_es.dta", replace


*==============================================================================
* C. GLOBAL EVENT STUDY
*==============================================================================
run_es ln_oda, tag(global)
plot_es global, pval(`pval_global') file(es_global)


*==============================================================================
* D. SECTORAL EVENT STUDIES
*==============================================================================
local sectors social economic humanitarian governance agriculture environment

local lab_social        Social
local lab_economic      Economic
local lab_humanitarian  Humanitarian
local lab_governance    Governance
local lab_agriculture   Agriculture
local lab_environment   Environment

foreach s of local sectors {
    run_es ln_usd_disb_`s', tag(`s')
    plot_es `s', pval(`pval_`s'') file(es_sector_`s') title(`lab_`s'')
}

graph combine g_social g_economic g_humanitarian               ///
              g_governance g_agriculture g_environment,        ///
    rows(2) cols(3) imargin(tiny) graphregion(color(white))    ///
    name(g_panel_sectors, replace)
graph export "$figures/es_sectors_panel.png", width(3000) replace

*------------------------------------------------------------------------------
* Tables (LaTeX)
*------------------------------------------------------------------------------
local post_coefs 5.event_time_shift 6.event_time_shift 7.event_time_shift ///
                 8.event_time_shift 9.event_time_shift 10.event_time_shift

local all_coefs  0.event_time_shift 1.event_time_shift 2.event_time_shift ///
                 3.event_time_shift `post_coefs'

local coef_labels                                                    ///
    0.event_time_shift  "t = -5"  1.event_time_shift  "t = -4"       ///
    2.event_time_shift  "t = -3"  3.event_time_shift  "t = -2"       ///
    5.event_time_shift  "t = 0"   6.event_time_shift  "t = +1"       ///
    7.event_time_shift  "t = +2"  8.event_time_shift  "t = +3"       ///
    9.event_time_shift  "t = +4"  10.event_time_shift "t = +5"

* Post-treatment coefficients only
esttab es_social es_economic es_humanitarian es_governance es_agriculture es_environment ///
    using "$tables/table_es_sectors.tex",                                               ///
    keep(`post_coefs') coeflabels(`coef_labels')                                        ///
    mtitles("Social" "Economic" "Humanitarian" "Governance" "Agriculture" "Environment") ///
    title("Sectoral Event Studies --- Effect of Populist Shock on ln(ODA)")             ///
    se star(* 0.10 ** 0.05 *** 0.01) booktabs replace

* Pre- and post-treatment coefficients
esttab es_social es_economic es_humanitarian es_governance es_agriculture es_environment ///
    using "$tables/table_es_sectorsV2.tex",                                             ///
    keep(`all_coefs') coeflabels(`coef_labels')                                         ///
    refcat(0.event_time_shift "\textit{Pre-treatment}"                                  ///
           5.event_time_shift "\textit{Post-treatment}", nolabel)                       ///
    mtitles("Social" "Economic" "Humanitarian" "Governance" "Agriculture" "Environment") ///
    title("Sectoral Event Studies --- Effect of Populist Shock on ln(ODA)")             ///
    se star(* 0.10 ** 0.05 *** 0.01) booktabs replace


*==============================================================================
* E. RECIPIENT-REGION EVENT STUDIES
*==============================================================================
local regions ssa mena eca sa eap lac

local lab_ssa   Sub-Saharan Africa
local lab_mena  Middle East & North Africa
local lab_eca   Europe & Central Asia
local lab_sa    South Asia
local lab_eap   East Asia & Pacific
local lab_lac   Latin America & Caribbean

foreach r of local regions {
    run_es ln_usd_disb_`r', tag(`r')
    plot_es `r', pval(`pval_`r'') file(es_region_`r') title(`lab_`r'')
}

graph combine g_ssa g_mena g_eca g_sa g_eap g_lac,             ///
    rows(2) cols(3) imargin(tiny) graphregion(color(white))    ///
    name(g_panel_regions, replace)
graph export "$figures/es_regions_panel.png", width(3000) replace

*------------------------------------------------------------------------------
* Tables (LaTeX)
*------------------------------------------------------------------------------
local region_titles "SSA" "MENA" "ECA" "South Asia" "East Asia-Pacific" "Latin America-Caribbean"

esttab es_ssa es_mena es_eca es_sa es_eap es_lac                    ///
    using "$tables/table_es_regions.tex",                           ///
    keep(`post_coefs') coeflabels(`coef_labels')                    ///
    mtitles(`region_titles')                                        ///
    title("Regional Event Studies --- Effect of Populist Shock on ln(ODA)") ///
    se star(* 0.10 ** 0.05 *** 0.01) booktabs replace

esttab es_ssa es_mena es_eca es_sa es_eap es_lac                    ///
    using "$tables/table_es_regionsV2.tex",                         ///
    keep(`all_coefs') coeflabels(`coef_labels')                     ///
    refcat(0.event_time_shift "\textit{Pre-treatment}"              ///
           5.event_time_shift "\textit{Post-treatment}", nolabel)   ///
    mtitles(`region_titles')                                        ///
    title("Regional Event Studies --- Effect of Populist Shock on ln(ODA)") ///
    se star(* 0.10 ** 0.05 *** 0.01) booktabs replace
