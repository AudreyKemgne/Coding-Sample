/*==============================================================================
 Project : Master's thesis - Populism in donor countries and bilateral ODA
 File    : 03_analysis.do
 Purpose : Descriptive statistics.
 Inputs  : data/clean/Aid_populism_final.dta
 Outputs : output/tables/table1_descriptives.tex
 Run     : after 02_construction.do
==============================================================================*/

clear all
set more off
version 16

if "${root}" == "" {
    display as error "Globals not defined. Run 00_master.do first."
    exit 198
}

* CHECK: the original header said "Aid_populism2.dta" but the code loaded
* Aid_populism.dta. The latter (donor x year panel with ln outcomes) is used here.
use "$clean/Aid_populism_final.dta", clear
xtset donor_id year

*------------------------------------------------------------------------------
* Variable groups
*------------------------------------------------------------------------------
local outcome  ln_oda
local populism populism_share populist_50 populist_25
local regions  ln_usd_disb_ssa ln_usd_disb_mena ln_usd_disb_eca ln_usd_disb_sa ///
               ln_usd_disb_eap ln_usd_disb_lac ln_usd_disb_regional
local sectors  ln_usd_disb_social ln_usd_disb_economic ln_usd_disb_humanitarian ///
               ln_usd_disb_governance ln_usd_disb_agriculture ln_usd_disb_environment
local channels ln_usd_disb_grant ln_usd_disb_loan

*------------------------------------------------------------------------------
* Table 1: summary statistics
*------------------------------------------------------------------------------
estpost summarize `outcome' `populism' `regions' `sectors' `channels', detail quietly

esttab using "$tables/table1_descriptives.tex",                                  ///
    cells("mean(fmt(%9.3f)) sd(fmt(%9.3f)) min(fmt(%9.3f)) p50(fmt(%9.3f)) max(fmt(%9.3f)) count(fmt(%9.0f))") ///
    collabels("Mean" "Std. dev." "Min" "Median" "Max" "Obs.")                   ///
    label noobs nonumber                                                          ///
    title("Descriptive Statistics")                                               ///
    booktabs replace
