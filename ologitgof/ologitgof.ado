/* Goodness-of-fit tests for ordinal logistic regression */
program ologitgof, rclass
	version 13

	/* Deal with arguments and options */
	syntax [varlist(numeric default=none)] [if] [in] [,group(integer 10) all outsample /*
		*/ osvar(string) groupvar(string) patternvar(string) tableHL tablePR]

	marksample touse

	if `group' < 2 {
		disp as error "The number of groups must be at least 2"
		error 498
	}
	if `group' < 6 {
		disp as error "Warning: at least 6 groups is recommended"
	}
	if "`all'" ~= "" & ("`if'" ~= "" | "`in'" ~= "") {
		disp as error "all option not allowed with if or in"
		error 198
	}

	/* Determine last estimation command (and regression model) */ 
	local ecmd = e(cmd)
	if "`ecmd'" == "ologit" local model "proportional odds"
	else if "`ecmd'" == "adjcatlogit" local model "adjacent-category"
	else if "`ecmd'" == "ccrlogit" local model "constrained continuation-ratio"
	else error 321
	
	local numgroups = `group'					/* group will be used as a variable name later */
	local cmdline = rtrim("ologitgof `0'")		/* Command as typed */
	local numcatvars = wordcount("`varlist'")	/* Number of categorical variables */
	if `numcatvars' == 0 {
		disp as error "Warning: to calculate the Pulkstenis-Robinson tests, the categorical covariates"
		disp as error "from the estimation command need to be specified as varlist using the syntax:"
		disp as error "ologitgof [varlist] [if] [in], options"
	}
	
	/* Use all observations in the dataset */
	if "`all'" == "all" {
		quietly replace `touse' = 1
	}
	/* Use the estimation sample */
	else if "`if'" == "" & "`in'" == "" {
		quietly replace `touse' = 0
		quietly replace `touse' = 1 if e(sample)
	}

	/* Use some information from the estimation */
	local depvar = e(depvar)			/* The dependent variable */
	local ecmdline = e(cmdline)			/* The estimation command as typed */
	local c = e(k_cat)					/* The number of response levels */
	tempname cat
	matrix `cat' = e(cat)				/* Matrix containing the response levels */
	
	/* Calculate estimated probabilities and the ordinal score = p1 + 2*p2 + 3*p3 + ... */
	/* (All tests) */
	tempvar ordinalscore
	quietly gen `ordinalscore' = 0 if `touse'
	forvalues i = 1/`c' {
		local y = `cat'[1, `i']
		tempvar p`y'
		quietly predict `p`y'' if `touse', outcome(`y')		
		quietly replace `ordinalscore' = `ordinalscore' + `y'*`p`y'' if `touse'
	}
	quietly replace `ordinalscore' = round(`ordinalscore', 0.0000001) if `touse'

	/* Sort according to the ordinal score and create numgroups groups */
	/* (HL and Lipsitz tests) */
	quietly summarize `ordinalscore' if `touse'
	local N = r(N)					/* The total number of observations */
	local maxOS = r(max)			/* The maximum ordinal score (used in the HL-table) */
	tempvar sortedvar group id
	quietly gen `sortedvar' = _n	/* Need this to resort the data later */
	sort `ordinalscore' `depvar'
	quietly gen `id' = .
	local N_all = _N
	local i = 0
	forvalues j = 1/`N_all' {
		if `touse'[`j'] local i = `i' + 1
		quietly replace `id' = `i' if `touse' & _n == `j'
	}	
	quietly gen `group' = .
	forvalues i = 1/`numgroups' {
		local index0 = 1 + ceil((`i'-1)*`N'/`numgroups')
		local index1 = ceil(`i'*`N'/`numgroups')
		quietly replace `group' = `i' if `id' >= `index0' & `id' <= `index1'
	}
	sort `sortedvar'	/* Resort the data */


	/* =============================== */
	/* ==== Specifics for HL test ==== */
	/* =============================== */
	
	/* The number of observations in each group */
	/* (HL test) */
	forvalues g = 1/`numgroups' {
		tempname n`g'
		quietly egen `n`g'' = total(`group' == `g') if `touse'
	}

	/* Create temporary dummy variables to identify group- and response- */
	/* specific observed and estimated frequencies */
	/* (HL test) */
	forvalues g = 1/`numgroups' {
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			tempvar O`g'_`y' E`g'_`y'
			quietly gen `O`g'_`y'' = 1 if `touse' & `group' == `g' & `depvar' == `y'
			quietly gen `E`g'_`y'' = `p`y'' if `touse'& `group' == `g'		
		}
	}

	/* Sum the observed and estimated frequencies in each group for each response level */
	/* (HL test) */
	forvalues g = 1/`numgroups' {
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			tempname Obs`g'_`y' Est`g'_`y'
			quietly egen `Obs`g'_`y'' = total(`O`g'_`y'') if `touse'	
			quietly egen `Est`g'_`y'' = total(`E`g'_`y'') if `touse'
		}
	}

	/* Calculate test statistic, degrees of freedom, and P-value */
	/* (HL test) */
	local chi2_HL = 0
	forvalues g = 1/`numgroups' {	
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			local chi2_HL = `chi2_HL' + ((`Obs`g'_`y'' - `Est`g'_`y'')^2)/`Est`g'_`y''
		}
	}
	if "`outsample'" == "outsample" local df_HL = `numgroups'*(`c' - 1) + (`c' - 2)
	else local df_HL = (`numgroups' - 2)*(`c' - 1) + (`c' - 2)
	local prob_HL = chi2tail(`df_HL', `chi2_HL')
	
	
	/* ================================ */
	/* ==== Specifics for PR tests ==== */
	/* ================================ */
	
	/* Create a temporary indicator variable for covariate patterns */
	/* (PR tests) */
	if `numcatvars' == 0 {
		local numpatterns = 0
	}
	else {
		tempvar pattern
		capture: label drop covpatternlabel
		quietly egen `pattern' = group(`varlist') if `touse', label lname(covpatternlabel)
		quietly levelsof `pattern', local(patterns)
		local numpatterns = wordcount("`patterns'")
	}
	
	/* Split each covariate pattern in two based on the median ordinal score  */
	/* Create temporary dummy variables to identify pattern- and response- */
	/* specific observed and expected frequencies */	
	/* (PR tests) */
	forvalues g = 1/`numpatterns' {
		quietly sum `ordinalscore' if `touse' & `pattern' == `g', detail
		local median = round(r(p50), 0.0000001)
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			tempvar O`g'_`y'_1 E`g'_`y'_1 O`g'_`y'_2 E`g'_`y'_2
			quietly gen `O`g'_`y'_1' = 1 if `touse' & `pattern' == `g' & `depvar' == `y' & /*
				*/ round(`ordinalscore', 0.0000001) <= round(`median', 0.0000001)
			quietly gen `E`g'_`y'_1' = `p`y'' if `touse' & `pattern' == `g' & /*
				*/ round(`ordinalscore', 0.0000001) <= round(`median', 0.0000001)
			quietly gen `O`g'_`y'_2' = 1 if `touse' & `pattern' == `g' & `depvar' == `y' & /*
				*/ `ordinalscore' > `median'
			quietly gen `E`g'_`y'_2' = `p`y'' if `touse' & `pattern' == `g' & /*
				*/ `ordinalscore' > `median'
		}
		
		/* The number of observations in each covariate pattern */
		tempname n`g'_1 n`g'_2
		quietly egen `n`g'_1' = total(`pattern' == `g' & `ordinalscore' <= `median') if `touse'
		quietly egen `n`g'_2' = total(`pattern' == `g' & `ordinalscore' > `median') if `touse'
	}
	
	/* Sum the observed and estimated frequencies in each pattern for each response level */
	/* (PR tests) */
	forvalues g = 1/`numpatterns' {
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			tempname Obs`g'_`y'_1 Est`g'_`y'_1 Obs`g'_`y'_2 Est`g'_`y'_2
			quietly egen `Obs`g'_`y'_1' = total(`O`g'_`y'_1') if `touse'		
			quietly egen `Est`g'_`y'_1' = total(`E`g'_`y'_1') if `touse'
			quietly egen `Obs`g'_`y'_2' = total(`O`g'_`y'_2') if `touse'
			quietly egen `Est`g'_`y'_2' = total(`E`g'_`y'_2') if `touse'
		}
	}
	
	/* Calculate the Pearson chi-square statistic */
	/* (PR tests) */
	local chi2_PR = 0
	forvalues g = 1/`numpatterns' {	
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			local chi2_PR = `chi2_PR' + ((`Obs`g'_`y'_1' - `Est`g'_`y'_1')^2)/`Est`g'_`y'_1'
			local chi2_PR = `chi2_PR' + ((`Obs`g'_`y'_2' - `Est`g'_`y'_2')^2)/`Est`g'_`y'_2'
		}
	}

	/* Calculate the deviance statistic (D2) */
	/* If some observed cells are zero, add nothing */
	/* (PR tests) */
	local D2 = 0
	forvalues g = 1/`numpatterns' {	
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			if (`Obs`g'_`y'_1' > 0) {
				local D2 = `D2' + `Obs`g'_`y'_1'*log(`Obs`g'_`y'_1'/`Est`g'_`y'_1')
			}
			if (`Obs`g'_`y'_2' > 0) {
				local D2 = `D2' + `Obs`g'_`y'_2'*log(`Obs`g'_`y'_2'/`Est`g'_`y'_2')
			}
		}
	}
	local D2 = 2*`D2'
	
	/* Degrees of freedom and P-values */
	/* (PR tests) */
	if `numcatvars' == 0 {
		local chi2_PR = "."
		local D2 = "."
		local df_PR = "."
		local prob_chi2 = "."
		local prob_D2 = "."
	}
	else {
		local df_PR = (2*`numpatterns' - 1)*(`c' - 1) - `numcatvars' - 1
		local prob_chi2 = chi2tail(`df_PR', `chi2_PR')
		local prob_D2 = chi2tail(`df_PR', `D2')
	}


	/* ==================================== */
	/* ==== Specifics for Lipsitz test ==== */
	/* ==================================== */

	/* Store the estimation results */
	/* (Lipsitz test) */
	estimates store A

	/* Fit new model that includes the group indicator variables */
	/* (Lipsitz test) */
	local cmd: list ecmdline - ecmd
	local cmd: list cmd - depvar
	local cmd = "`ecmd' `depvar' i.`group' `cmd'"
	quietly `cmd'
	estimates store B
	quietly estimates restore A
	capture: quietly lrtest A B
	if _rc == 498 {
		disp as error "Warning: the Lipsitz test could not be calculated because the samples for"
		disp as error "the two models (with and without group indicator variables) differ"
	}
	local df_L = r(df)
	local chi2_L = r(chi2)
	local prob_L = r(p)

	/* Remove the esample variables created by the estimates store commands */
	/* (Lipsitz test) */
	capture: drop _est_A _est_B
	

	/* ============================ */
	/* ==== Report the results ==== */
	/* ============================ */

	/* Display title */
	local title = "Goodness-of-fit tests for ordinal logistic regression models"
	disp as text _newline "`title'" _newline

	/* Display contingency table if the tableHL option is given */
	/* (HL test) */
	_pctile `ordinalscore', nquantiles(`numgroups')
	if "`tableHL'" == "tableHL" {
		local firstcat = 1
		local lastcat = min(`c', 3)
		local numcatintable = `lastcat' - `firstcat' + 1
		local keepdrawingtable = 1

		disp as text "Table: observed and estimated frequencies for the HL test"

		while `keepdrawingtable' == 1 {

			disp "{c TLC}{hline 6}" _continue
			if `firstcat' == 1 {
				disp "{c TT}{hline 13}" _continue
			}
			disp _dup(`numcatintable') "{c TT}{hline 14}" _continue
			if `c' == `lastcat' {
				disp "{c TT}{hline 7}" _continue
			}
			disp "{c TRC}"

			disp "{c |}Group " _continue
			if `firstcat' == 1 {
				disp "{c |}Ordinal score" _continue
			}
		
			forvalues i = `firstcat'/`lastcat' {
				local y = `cat'[1, `i']
				disp "{c |}{center 7:Obs_`y'}"  "{center 7:Est_`y'}" _continue
			}
			if `c' == `lastcat' {
				disp "{c |} {center 6:Total}{c |}"
			}
			else {
				disp "{c |}"
			}
			
			disp "{c LT}{hline 6}" _continue
			if `firstcat' == 1 {
				disp "{c +}{hline 13}" _continue
			}
			disp _dup(`numcatintable') "{c +}{hline 14}" _continue
			if `c' == `lastcat' {
				disp "{c +}{hline 7}" _continue
			}
			disp "{c RT}" _continue
			
			forvalues g = 1/`numgroups' {
				if mod(`g'-1, 5) == 0 & `g' > 1 {
					if `firstcat' == 1 {
						disp _newline "{c LT}{hline 6}{c +}{hline 13}" /*
							*/ _dup(`numcatintable') "{c +}{hline 14}" _continue
					}
					else {
						disp _newline "{c LT}{hline 6}" /*
							*/ _dup(`numcatintable') "{c +}{hline 14}" _continue
					}
					if `c' == `lastcat' {
						disp "{c +}{hline 7}{c RT}" _continue
					}
					else {
						disp "{c RT}" _continue
					}
				}
				if `firstcat' == 1 {
					if `g' < `numgroups' {
						disp _newline "{c |}" %5.0g `g' " {c |} " %9.4f r(r`g') "  " _continue
					}
					else {
						disp _newline "{c |}" %5.0g `g' " {c |} " %9.4f `maxOS' "  " _continue
					}
				}
				else {
					disp _newline "{c |}" %5.0g `g' _continue
				}

				forvalues i = `firstcat'/`lastcat' {
					local y = `cat'[1, `i']
					disp " {c |}" %6.0g `Obs`g'_`y'' %7.2f `Est`g'_`y'' _continue
				}
				disp " {c |}" _continue
				if `c' == `lastcat' {
					disp %6.0g `n`g'' " {c |}" _continue
				}
			}
			
			if `firstcat' == 1 {
				disp _newline "{c BLC}{hline 6}{c BT}{hline 13}" /*
					*/ _dup(`numcatintable') "{c BT}{hline 14}" _continue
			}
			else {
				disp _newline "{c BLC}{hline 6}" /*
					*/ _dup(`numcatintable') "{c BT}{hline 14}" _continue
			}

			if `c' == `lastcat' {
				disp "{c BT}{hline 7}{c BRC}"
			}
			else {
				disp "{c BRC}"
			}
			
			if `c' == `lastcat' {
				local keepdrawingtable = 0
			}
			else {
				local firstcat = `lastcat' + 1
				local lastcat = min(`c', `lastcat' + 3)
				local numcatintable = `lastcat' - `firstcat' + 1
			}
		}
	}
	
	
	/* Create two matrices: "HLtable" contains the entire contingency table */
	/* "HLtableOE" contains only the observed and estimated frequencies */
	/* (HL test) */
	tempname HLtable HLtableOE
	matrix `HLtable' = J(`numgroups', 2*`c' + 3, 0)
	matrix `HLtableOE' = J(`numgroups', 2*`c', 0)
	forvalues g = 1/`numgroups' {
		matrix `HLtable'[`g', 1] = `g'
		matrix `HLtable'[`g', 2] = r(r`g')
		if `g' == `numgroups' {
			matrix `HLtable'[`g', 2] = `maxOS'
		}
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			local O = `Obs`g'_`y''
			local E = `Est`g'_`y''
			matrix `HLtable'[`g', 2+2*`i'-1] = `O'
			matrix `HLtable'[`g', 2+2*`i'] = `E'
			matrix `HLtableOE'[`g', 2*`i'-1] = `O'
			matrix `HLtableOE'[`g', 2*`i'] = `E'
		}
		local ng = `n`g''
		matrix `HLtable'[`g', 3+2*`c'] = `ng'
	}
	
	
	/* Display contingency table if the tablePR option is given */
	/* (PR tests) */
	if "`tablePR'" == "tablePR" {

		if "`tableHL'" == "tableHL" {
			disp ""
		}
		
		local firstcat = 1
		local lastcat = min(`c', 3)
		local numcatintable = `lastcat' - `firstcat' + 1
		local keepdrawingtable = 1	
	
		disp as text "Table: observed and estimated frequencies for the PR tests"

		while `keepdrawingtable' == 1 {
			disp "{c TLC}{hline 18}" _dup(`numcatintable') "{c TT}{hline 14}" _continue
	
			if `c' == `lastcat' {
				disp "{c TT}{hline 7}" _continue
			}
			disp "{c TRC}"
			
			disp "{c |}Covariate pattern " _continue
			forvalues i = `firstcat'/`lastcat' {
				local y = `cat'[1, `i']
				disp "{c |}{center 7:Obs_`y'}"  "{center 7:Est_`y'}" _continue
			}
			if `c' == `lastcat' {
				disp "{c |} {center 6:Total}" _continue
			}
			disp "{c |}" _continue
		
			forvalues g = 1/`numpatterns' {
				disp _newline "{c LT}{hline 18}" _dup(`numcatintable') "{c +}{hline 14}" _continue
				if `c' == `lastcat' {
					disp "{c +}{hline 7}" _continue
				}
				disp "{c RT}" _continue

				disp _newline "{c |}" %4.0g `g' " <= median OS" _continue
				forvalues i = `firstcat'/`lastcat' {
					local y = `cat'[1, `i']
					disp " {c |}" %6.0g `Obs`g'_`y'_1' %7.2f `Est`g'_`y'_1' _continue
				}
				if `c' == `lastcat' {
					disp " {c |}" %6.0g `n`g'_1' _continue
				}
				disp " {c |}" _continue

				disp _newline "{c |}" %4.0g `g'  " > median OS " _continue
				forvalues i = `firstcat'/`lastcat' {
					local y = `cat'[1, `i']
					disp " {c |}" %6.0g `Obs`g'_`y'_2' %7.2f `Est`g'_`y'_2' _continue
				}
				if `c' == `lastcat' {
					disp " {c |}" %6.0g `n`g'_2' _continue
				}
				disp " {c |}" _continue
			}
			disp _newline "{c BLC}{hline 18}" _dup(`numcatintable') "{c BT}{hline 14}" _continue
			if `c' == `lastcat' {
				disp "{c BT}{hline 7}" _continue
			}
			disp "{c BRC}"

			if `c' == `lastcat' {
				local keepdrawingtable = 0
			}
			else {
				local firstcat = `lastcat' + 1
				local lastcat = min(`c', `lastcat' + 3)
				local numcatintable = `lastcat' - `firstcat' + 1
			}
		}

		disp "OS = ordinal score"
		label list covpatternlabel
		disp ""
	}

	
	/* Create a matrix containing the contingency table */
	/* (PR tests) */
	tempname PRtable
	if `numcatvars' == 0 {
		matrix `PRtable' = J(1, 2*`c', 0)
	}
	else {
		matrix `PRtable' = J(2*`numpatterns', 2*`c' + 1, 0)
	}
	forvalues g = 1/`numpatterns' {
		forvalues i = 1/`c' {
			local y = `cat'[1, `i']
			local O = `Obs`g'_`y'_1'
			local E = `Est`g'_`y'_1'
			matrix `PRtable'[2*`g'-1, 2*`i'-1] = `O'
			matrix `PRtable'[2*`g'-1, 2*`i'] = `E'
			local O = `Obs`g'_`y'_2'
			local E = `Est`g'_`y'_2'
			matrix `PRtable'[2*`g', 2*`i'-1] = `O'
			matrix `PRtable'[2*`g', 2*`i'] = `E'
		}
		local ng = `n`g'_1'
		matrix `PRtable'[2*`g'-1, 1+2*`c'] = `ng'
		local ng = `n`g'_2'
		matrix `PRtable'[2*`g', 1+2*`c'] = `ng'
	}	
	
	/* Display table of test results */
	disp as text "Model: `model' (`ecmd')"
	disp "Dependent variable: `depvar' = [" _continue
	forvalues i = 1/`c' {
		local value = `cat'[1, `i']
		disp `i' _continue
		if `i' < `c' disp ", " _continue
	}
	disp "]" _newline
	disp "Number of observations = `N'"

	if "`outsample'" == "outsample" local outsamplemark "*"
	local space = 4 - length("`outsamplemark'")
	disp "{hline 62}"
	disp _dup(15) " " %12s "Number of"
	disp %-15s "Tests" %15s "groups/patterns" %12s "Statistic" %8s "df" %12s "P-value"
	disp "{hline 62}"
	disp %-15s "Ordinal HL" %9.0g `numgroups' _dup(9) " " %8.3f `chi2_HL' "   " %6.0g `df_HL' "`outsamplemark'" _dup(`space') " " %8.4f `prob_HL'
	disp %-15s "PR(chi2)" %9.0g `numpatterns' _dup(9) " " %8.3f `chi2_PR' "   " %6.0g `df_PR' "    " %8.4f `prob_chi2'
	disp %-15s "PR(deviance)" %9.0g `numpatterns' _dup(9) " " %8.3f `D2' "   " %6.0g `df_PR' "    " %8.4f `prob_D2'
	disp %-15s "Lipsitz" %9.0g `numgroups' _dup(9) " " %8.3f `chi2_L' "   " %6.0g `df_L' "    " %8.4f `prob_L'
	disp "{hline 62}"
	disp "(HL = Hosmer-Lemeshow; PR = Pulkstenis-Robinson)"
	if "`outsample'" == "outsample" disp "*Adjusted for samples outside the estimation sample"

	/* Return results in r() */
	return scalar N = `N'
	return scalar k_cat = `c'
	return scalar g = `numgroups'
	return scalar numpatterns = `numpatterns'

	return scalar chi2_HL = `chi2_HL'
	return scalar df_HL = `df_HL'
	return scalar P_HL = `prob_HL'

	return scalar chi2_PR = `chi2_PR'
	return scalar D2 = `D2'
	return scalar df_PR = `df_PR'
	return scalar P_chi2 = `prob_chi2'
	return scalar P_D2 = `prob_D2'
	
	return scalar chi2_L = `chi2_L'
	return scalar df_L = `df_L'
	return scalar P_L = `prob_L'
	
	return local ecmd = "`ecmd'"
	return local title = "`title'"
	return local cmd = "ologitgof"
	return local cmdline = "`cmdline'"

	return matrix cat = `cat'
	return matrix HLtable = `HLtable'
	return matrix HLtableOE = `HLtableOE'
	return matrix PRtable = `PRtable'
	
	/* Create a variable containing the ordinal scores if the osvar option is given */
	if "`osvar'" ~= "" quietly gen `osvar' = `ordinalscore' if `touse'
	
	/* Create a group variable if the groupvar option is given */
	if "`groupvar'" ~= "" quietly gen `groupvar' = `group' if `touse'
	
	/* Create a variable containing the covariate patterns if the patternvar option is given */
	if "`patternvar'" ~= "" quietly gen `patternvar' = `pattern' if `touse'
	
end
