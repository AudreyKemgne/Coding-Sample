/*==============================================================================
 Project : Master's thesis - Populism in donor countries and bilateral ODA
 File    : 05_robustness.do
 Purpose : Robustness checks:
           (A) Callaway & Sant'Anna (2021) estimator vs TWFE,
           (B) sensitivity to the populism threshold (40%, 50%, 60%).
 Inputs  : data/clean/Aid_populism_es.dta      (event-study sample, from 04_model.do)
           data/clean/Aid_populism_final.dta   (full analysis dataset)
           output/est/es_global.ster           (TWFE estimates, from 04_model.do)
 Outputs : output/figures/cs_global.png, robustness_*.png, es_threshold_*.png
           output/tables/table_robustness_*.tex
 Run     : after 04_model.do
==============================================================================*/

clear all
set more off
version 16

if "${root}" == "" {
    display as error "Globals not defined. Run 00_master.do first."
    exit 198
}

*==============================================================================
* A. CALLAWAY & SANT'ANNA (2021)
*==============================================================================

*------------------------------------------------------------------------------
* A.1 Estimation (same sample as the baseline TWFE event study)
*------------------------------------------------------------------------------
use "$clean/Aid_populism_es.dta", clear
xtset donor_id year

* csdid requires first_treat = 0 for never-treated units
gen first_treat_cs = first_treat
replace first_treat_cs = 0 if missing(first_treat)

csdid ln_oda,                ///
    ivar(donor_id)           ///
    time(year)               ///
    gvar(first_treat_cs)     ///
    notyet long2 wboot rseed(12345)

* ATT by relative period, then overall ATT
estat event, estore(cs_global)
estat simple

*------------------------------------------------------------------------------
* A.2 Event-study plot (C&S only)
*------------------------------------------------------------------------------
coefplot cs_global,                                              ///
    keep(Tm* Tp*) vertical                                       ///
    yline(0, lcolor(black) lpattern(dash))                       ///
    ciopts(recast(rcap) lwidth(medthin))                         ///
    xtitle("Years relative to populist shock")                   ///
    ytitle("ATT: effect on ln(ODA)")                             ///
    title("Callaway & Sant'Anna (2021) - Global")                ///
    note("Comparison group: never-treated and not-yet-treated donors." ///
         "Wild bootstrap standard errors.", size(vsmall))        ///
    graphregion(color(white))                                    ///
    name(g_cs_global, replace)

graph export "$figures/cs_global.png", replace

*------------------------------------------------------------------------------
* A.3 TWFE vs C&S on the same graph
*     Coefficients are renamed to a common label (m5 ... m1, p0 ... p5).
*     CHECK: csdid names its event-time coefficients Tm# / Tp#; if your
*     version uses other names, adjust the right-hand side below.
*------------------------------------------------------------------------------
estimates use "$est/es_global"
estimates store es_global

local rn_twfe ""
local rn_cs   ""
local keepnm  ""
local coeflab ""

forvalues k = 0/10 {
    local t = `k' - 5
    local a = abs(`t')
    if `t' < 0 {
        local nm  "m`a'"
        local cs  "Tm`a'"
        local lab "-`a'"
    }
    else {
        local nm  "p`a'"
        local cs  "Tp`a'"
        local lab "`a'"
    }
    local rn_twfe `rn_twfe' `k'.event_time_shift = `nm'
    local rn_cs   `rn_cs'   `cs' = `nm'
    local keepnm  `keepnm'  `nm'
    local coeflab `coeflab' `nm' = "`lab'"
}

coefplot                                                              ///
    (es_global, label("TWFE") rename(`rn_twfe')                       ///
        lcolor(navy) mcolor(navy))                                    ///
    (cs_global, label("Callaway & Sant'Anna") rename(`rn_cs')         ///
        lcolor(cranberry) mcolor(cranberry)),                         ///
    keep(`keepnm') order(`keepnm') coeflabels(`coeflab') baselevels   ///
    vertical                                                          ///
    yline(0, lcolor(black) lpattern(dash))                            ///
    ciopts(recast(rcap) lwidth(medthin))                              ///
    xtitle("Years relative to populist shock")                        ///
    ytitle("Effect on ln(ODA)")                                       ///
    title("Robustness: TWFE vs. Callaway & Sant'Anna (2021)")         ///
    legend(rows(1) position(6))                                       ///
    graphregion(color(white))                                         ///
    name(g_twfe_vs_cs, replace)

graph export "$figures/robustness_twfe_vs_cs.png", replace

*------------------------------------------------------------------------------
* A.4 Comparison table
*------------------------------------------------------------------------------
esttab es_global cs_global                                            ///
    using "$tables/table_robustness_cs.tex",                          ///
    mtitles("TWFE" "Callaway \& Sant'Anna")                           ///
    title("Robustness Check: TWFE vs. Callaway \& Sant'Anna (2021)")  ///
    note("TWFE: two-way fixed effects with donor and year fixed effects." ///
         "CS: Callaway \& Sant'Anna estimator, never-treated and not-yet-treated donors as controls." ///
         "Wild bootstrap standard errors in parentheses for CS estimates.") ///
    se star(* 0.10 ** 0.05 *** 0.01)                                  ///
    booktabs replace


*==============================================================================
* B. SENSITIVITY TO THE POPULISM THRESHOLD (40%, 50%, 60%)
*    Each threshold is rebuilt from the FULL analysis dataset (treatment,
*    switchers, first treatment year, window), so the samples are not
*    conditioned on the 50% baseline.
*==============================================================================
foreach thr in 40 50 60 {

    use "$clean/Aid_populism_final.dta", clear
    sort donor_id year
    xtset donor_id year

    * Absorbing treatment at this threshold; drop donors that leave treatment
    gen above = (populism_share > `thr') if !missing(populism_share)
    bysort donor_id (year): gen switch_out = (above[_n-1] == 1 & above == 0)
    bysort donor_id: egen has_switch = max(switch_out)
    drop if has_switch == 1
    drop above switch_out has_switch

    * First treatment year (missing values must be excluded explicitly)
    gen temp = year if populism_share > `thr' & !missing(populism_share)
    bysort donor_id: egen first_treat = min(temp)
    drop temp

    * Event time and window [-5, +5]
    gen event_time = year - first_treat
    keep if (event_time >= -5 & event_time <= 5) | missing(first_treat)

    gen et_shift = event_time + 5 if !missing(event_time)
    fvset base 4 et_shift

    * TWFE event study (same specification as the baseline)
    reghdfe ln_oda i.et_shift, absorb(donor_id year) cluster(donor_id)
    estimates store es_thr`thr'
    estimates save "$est/es_thr`thr'", replace

    testparm i(0/3).et_shift
    local pval_thr`thr' : display %4.3f r(p)

    * Individual graph
    coefplot es_thr`thr',                                             ///
        keep(*et_shift*) baselevels vertical                          ///
        yline(0, lcolor(black) lpattern(dash))                        ///
        xline(5.5, lcolor(red) lpattern(dot))                         ///
        ciopts(recast(rcap) lwidth(medthin))                          ///
        xlabel(1 "-5" 2 "-4" 3 "-3" 4 "-2" 5 "-1 (ref)"               ///
               6 "0" 7 "1" 8 "2" 9 "3" 10 "4" 11 "5",                 ///
               noticks labsize(small) angle(45))                      ///
        xtitle("Years relative to populist shock")                    ///
        ytitle("Effect on ln(ODA)")                                   ///
        note("Pre-trends p = `pval_thr`thr''", size(vsmall))          ///
        title("Threshold = `thr'%")                                   ///
        graphregion(color(white))                                     ///
        name(g_thr`thr', replace)

    graph export "$figures/es_threshold_`thr'.png", replace
}

*------------------------------------------------------------------------------
* B.1 Three thresholds on the same graph
*------------------------------------------------------------------------------
coefplot                                                              ///
    (es_thr40, label("Threshold = 40%")                               ///
        lcolor(forest_green) mcolor(forest_green))                    ///
    (es_thr50, label("Threshold = 50% (baseline)")                    ///
        lcolor(navy) mcolor(navy))                                    ///
    (es_thr60, label("Threshold = 60%")                               ///
        lcolor(cranberry) mcolor(cranberry)),                         ///
    keep(*et_shift*) baselevels vertical                              ///
    yline(0, lcolor(black) lpattern(dash))                            ///
    xline(5.5, lcolor(gs10) lpattern(dot))                            ///
    ciopts(recast(rcap) lwidth(medthin))                              ///
    xlabel(1 "-5" 2 "-4" 3 "-3" 4 "-2" 5 "-1 (ref)"                   ///
           6 "0" 7 "1" 8 "2" 9 "3" 10 "4" 11 "5",                     ///
           noticks labsize(small) angle(45))                          ///
    xtitle("Years relative to populist shock")                        ///
    ytitle("Effect on ln(ODA)")                                       ///
    title("Robustness: Sensitivity to Treatment Threshold")           ///
    note("Baseline specification uses a 50% threshold."               ///
         "Capped spikes denote 95% confidence intervals.", size(vsmall)) ///
    legend(rows(1) position(6))                                       ///
    graphregion(color(white))                                         ///
    name(g_thresholds_combined, replace)

graph export "$figures/robustness_thresholds_combined.png", replace

*------------------------------------------------------------------------------
* B.2 1 x 3 panel
*------------------------------------------------------------------------------
graph combine g_thr40 g_thr50 g_thr60,                                ///
    rows(1) cols(3) imargin(tiny) graphregion(color(white))           ///
    title("Robustness: Sensitivity to Treatment Threshold", size(medium)) ///
    name(g_panel_thresholds, replace)

graph export "$figures/robustness_thresholds_panel.png", width(3000) replace

*------------------------------------------------------------------------------
* B.3 Comparison table
*------------------------------------------------------------------------------
esttab es_thr40 es_thr50 es_thr60                                     ///
    using "$tables/table_robustness_thresholds.tex",                  ///
    keep(0.et_shift 1.et_shift 2.et_shift 3.et_shift                  ///
         5.et_shift 6.et_shift 7.et_shift 8.et_shift 9.et_shift 10.et_shift) ///
    coeflabels(                                                       ///
        0.et_shift "t = -5"  1.et_shift "t = -4"                      ///
        2.et_shift "t = -3"  3.et_shift "t = -2"                      ///
        5.et_shift "t = 0"   6.et_shift "t = +1"                      ///
        7.et_shift "t = +2"  8.et_shift "t = +3"                      ///
        9.et_shift "t = +4"  10.et_shift "t = +5")                    ///
    refcat(0.et_shift "\textit{Pre-treatment}"                        ///
           5.et_shift "\textit{Post-treatment}", nolabel)             ///
    mtitles("Threshold 40\%" "Threshold 50\% (baseline)" "Threshold 60\%") ///
    title("Robustness Check: Sensitivity to Treatment Threshold")     ///
    note("All specifications include donor and year fixed effects."   ///
         "Standard errors clustered at the donor level."              ///
         "Reference period: t = -1.")                                 ///
    se star(* 0.10 ** 0.05 *** 0.01)                                  ///
    booktabs replace
