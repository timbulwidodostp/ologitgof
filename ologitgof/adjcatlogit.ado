/* Adjacent-category logistic regression model */
program adjcatlogit, eclass properties(or swml mi)
	version 13

	if !replay() {
		syntax varlist(min=1 numeric fv) [if] [in] [, level(cilevel) or listconstraints]

		marksample touse

		local cmdline "adjcatlogit `0'"				/* Command as typed */
		local title "Adjacent-category logistic regression"
		tokenize `varlist'
		local depvar `1' 							/* Dependent variable */
		macro shift
		local indepvars `*'							/* Independent variables */
		quietly levelsof `depvar' if `touse', local(catlist)	/* List of category values */
		local c = wordcount("`catlist'")			/* Number of category values */
		
		/* Matrix of category values */
		tempname cat
		matrix `cat' = J(1, `c', 0)
		tokenize `catlist'
		forvalues i = 1/`c' {
			matrix `cat'[1, `i'] = `$_`i''
		}
		local lowestcat = `cat'[1, 1]		/* Value of the lowest category */

		
		/* ------------------------------------------------------------------------ */
		/* Fit adjacent-category model via a constrained multinomial logistic model */
		/* ------------------------------------------------------------------------ */

		/* Fit a constant-only model (to get the log likelihood) */
		/* (no need for constraints in this model) */
		quietly mlogit `depvar' if `touse', baseoutcome(`lowestcat') level(`level')
		local ll_0 = e(ll)		/* Log likelihood */
		local df_0 = e(df_m)	/* Degrees of freedom */
		
		/* Expand any factor variables (to correctly define the constraints) */
		local constraintsvarlist ""
		foreach indepvar in `indepvars' {
			fvexpand `indepvar' if `touse'
			if "`r(fvops)'" == "true" {
				local factorvarlist = r(varlist)
				local constraintsvarlist = "`constraintsvarlist' `factorvarlist'"
			}
			else {
				local constraintsvarlist = "`constraintsvarlist' `indepvar'"
			}
		}
		
		/* Define constraints (but not for base level factor variables) */
		foreach variable in `constraintsvarlist' {
			if regexm("`variable'", "[0-9]+b\.") == 1 continue
			forvalues i = 3/`c' {
				constraint free
				local constraint = r(free)
				if "`constraints'" == "" {
					local constraints "`constraint'"
				}
				else {
					local constraints "`constraints', `constraint'"
				}
				local iminus1 = `i' - 1
				constraint `constraint' [`i']`variable' = `iminus1'*[2]`variable'
			}
		}
		
		/* Fit the full model */
		capture: mlogit `depvar' `indepvars' if `touse', baseoutcome(`lowestcat') /*
			*/ level(`level') constraints(`constraints')
		if _rc == 412 {
			disp in red "This probably happened because you tried to fit a model with a redundant"
			disp in red "independent variable or an interaction term with zero observations for one"
			disp in red "of the combinations of levels" _newline
			error _rc
		}
		else if _rc ~= 0 {
			error _rc
		}

		local nobs = e(N)		/* Number of observations */
		local ll = e(ll)		/* Log likelihood */
		local df_m = e(df_m)	/* Model degrees of freedom */

		/* Calculate the likelihood ratio test and pseudo R2 */
		local chi2 = -2*(`ll_0' - `ll')
		local df = `df_m' - `df_0'
		local p = chiprob(`df', `chi2')
		local r2_p = 1 - `ll'/`ll_0'

		/* Create the beta vector (b) and covariance matrix (V) */
		tempname b_full V_full b V b_logit2 V_logit2
		matrix `b_full' = e(b)
		matrix `V_full' = e(V)
		local numcoeffs = colsof(`b_full')/`c'
		matrix `b' = J(1, `numcoeffs' + `c' - 2, 0)
		matrix `V' = J(`numcoeffs' + `c' - 2, `numcoeffs' + `c' - 2, 0)
		matrix `b_logit2' = `b_full'[1, `numcoeffs'+1..2*`numcoeffs']
		matrix `b'[1, 1] = `b_logit2'
		matrix `V_logit2' = `V_full'[`numcoeffs'+1..2*`numcoeffs', `numcoeffs'+1..2*`numcoeffs']
		matrix `V'[1, 1] = `V_logit2'		
		forvalues i = 3/`c' {
			tempname bvalue`i' Vvalue`i'
			scalar `bvalue`i'' = `b_full'[1, `i'*`numcoeffs'] - `b_full'[1, (`i'-1)*`numcoeffs']
			matrix `b'[1, `numcoeffs' + `i' - 2] = `bvalue`i''
			scalar `Vvalue`i'' = `V_full'[`i'*`numcoeffs', `i'*`numcoeffs'] - /*
				*/ `V_full'[(`i'-1)*`numcoeffs', (`i'-1)*`numcoeffs']
			matrix `V'[`numcoeffs' + `i' - 2, `numcoeffs' + `i' - 2] = `Vvalue`i''
		}
		
		/* Get the row and column names from the mlogit estimation */
		local colnames: colnames `b_logit2'
		tokenize `colnames'
		local numcoeffsminus1 = `numcoeffs' - 1
		forvalues i = 1/`numcoeffsminus1' {
			local coeffnames = "`coeffnames' `depvar':`$_`i''"
		}
		local cminus1 = `c' - 1
		forvalues i = 1/`cminus1' {
			local coeffnames = "`coeffnames' _anc:cons`i'"
		}
		matrix colnames `b' = `coeffnames'
		matrix colnames `V' = `coeffnames'
		matrix rownames `V' = `coeffnames'
		
		/* Post the beta vector and covariance matrix */
		ereturn post `b' `V', obs(`nobs') depname(`depvar') esample(`touse')
		
		/* Save additional results in e() */
		ereturn scalar k_cat = `c'
		ereturn scalar k_exp = `c' - 1		/* Number of ancillary parameters */
		ereturn scalar ll = `ll'
		ereturn scalar ll_0 = `ll_0'
		ereturn scalar df_m = `df_m'
		ereturn scalar df_0 = `df_0'
		ereturn scalar chi2 = `chi2'
		ereturn scalar p = `p'
		ereturn scalar r2_p = `r2_p'
		ereturn local cmdline `cmdline'
		ereturn local title `title'
		ereturn local chi2type "LR"
		ereturn local predict adjcatlogit_p
		ereturn local constraints `constraints'
		ereturn matrix cat = `cat'
		ereturn local cmd "adjcatlogit"
	}

	
	/* Replay */
	else {
		syntax [, level(cilevel) or listconstraints]

		/* Need these for the reporting below */
		local depvar = e(depvar)
		local nobs = e(N)
		local touse = e(sample)
		local c = e(k_cat)
		local ll = e(ll)
		local df = e(df_m) - e(df_0)
		local chi2 = e(chi2)
		local p = e(p)
		local r2_p = e(r2_p)
		local title = e(title)
		local constraints = e(constraints)
		quietly levelsof `depvar' if e(sample), local(catlist)
	}

	if "`e(cmd)'" ~= "adjcatlogit" error 301
	if "`or'" ~= "" local `or' "Odds Ratio"
	
	/* List constraints if option is given */
	if "`listconstraints'" ~= "" {
		disp _newline "Constraints used with mlogit: "
		constraint list `constraints'
	}

	/* Report results including a regression table */
	disp _newline "`title'" _continue
	disp _col(56) "Number of obs = " %7.0g `nobs'
	disp _col(56) "LR chi2(" %2.0f `df' ")   = " %7.2f `chi2'
	disp _col(56) "Prob < chi2   = " %7.4f `p'
	disp "Log likelihood = " %10.5f `ll' _continue
	disp _col(56) "Pseudo R2     = " %7.4f `r2_p' _newline
	ereturn display, eform(`or') noemptycells level(`level')

end
