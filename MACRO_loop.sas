/* Compact */
/* LOOP OVER SEED */
DATA Seed_LIST; INPUT Seed 5.; DATALINES;
968
458
132
200
888
543
87
343
266
904
	;
RUN;

DATA Var_LIST; INPUT Variable $ 60.; DATALINES;
 
USE_GRP_3 PIF_DISC RADIUS_GRP_1 USDOT_INTRACTN_GRP_1  
 ;
RUN;


%MACRO loopOverSeeds();
    %LOCAL seedCount varCount iter1 iter2 Seed Var;

    PROC SQL noprint;
         SELECT count(*)
         INTO :seedCount
         FROM WORK.Seed_LIST;
    QUIT;

    PROC SQL noprint;
         SELECT count(*)
         INTO :varCount
         FROM WORK.Var_LIST;
    QUIT;
	
	%LET iter1=1;
		%DO %WHILE (&iter1.<= &seedCount.);
			DATA _NULL_;
				SET WORK.Seed_LIST (firstobs=&iter1. obs=&iter1.);
				CALL SYMPUT ("Seed",Seed);
			RUN;	
			
			%LET iter2=1;
				%DO %WHILE (&iter2.<= &varCount.);
				DATA _NULL_;
					SET WORK.Var_LIST (firstobs=&iter2. obs=&iter2.);
					CALL SYMPUT ("Var", STRIP(Variable)); 
				RUN;
					
				
				%LET iter2 = %eval(&iter2.+1);
			%END;

		%LET iter1=%eval(&iter1.+1);
	%END;
%MEND;

%loopOverSeeds()

/* FULL example */
/* Create Seed List */
DATA Seed_LIST; INPUT Seed 5.; DATALINES;
968
458
132
200
888
543
87
343
266
904
	;
RUN;

DATA Var_LIST; INPUT Variable $ 60.; DATALINES;
 
USE_GRP_3 PIF_DISC RADIUS_GRP_1 USDOT_INTRACTN_GRP_1  
 ;
RUN;

DATA OUTPUT.ASE_Step3; STOP; RUN;

/* LOOP OVER SEED */

%MACRO loopOverSeeds();
    %LOCAL seedCount varCount iter1 iter2 Seed Var;

    PROC SQL noprint;
         SELECT count(*)
         INTO :seedCount
         FROM WORK.Seed_LIST;
    QUIT;

    PROC SQL noprint;
         SELECT count(*)
         INTO :varCount
         FROM WORK.Var_LIST;
    QUIT;
	
	%LET iter1=1;
		%DO %WHILE (&iter1.<= &seedCount.);
			DATA _NULL_;
				SET WORK.Seed_LIST (firstobs=&iter1. obs=&iter1.);
				CALL SYMPUT ("Seed",Seed);
			RUN;
			
			DATA PRESTEP3; SET OUTPUT.PRESTEP3;
				call streaminit(&Seed.);  rand = rand('uniform');
				If rand > 0.3 then SAMPLE = "Train"; Else SAMPLE = "Test";
			RUN;
			
			DATA OUTPUT.FINAL_OUTPUT; SET PRESTEP3  
				(KEEP = rownumber SAMPLE PP BIPD_ECY WHERE = (SAMPLE = 'Test'));
			RUN;
			
			/* Create RB_PP and ASE output file */
			
			PROC SUMMARY DATA = OUTPUT.FINAL_OUTPUT NOPRINT NWAY;
				VAR PP;
				WEIGHT BIPD_ECY;
				OUTPUT OUT= MEAN_PP (DROP=_TYPE_ _FREQ_)
				MEAN(PP) = MEAN_PP;
			RUN;
			
			DATA _null_; SET MEAN_PP;
				IF _N_ =1 THEN DO; CALL SYMPUTX ('MEAN',MEAN_PP);
				END; STOP;
			RUN;

			DATA OUTPUT.FINAL_OUTPUT;
				SET OUTPUT.FINAL_OUTPUT;
				MEAN_PP = &MEAN.;
				IF MEAN_PP = 0 THEN RB_PP = 0; ELSE RB_PP = (PP/MEAN_PP)*100;
				SE_PP = ((100 - RB_PP)**2); /* BASE SE */
			RUN;
			
			PROC SUMMARY DATA = OUTPUT.FINAL_OUTPUT NOPRINT NWAY;
				VAR SE_PP;
				WEIGHT BIPD_ECY;
				OUTPUT OUT= ASE_PP (DROP=_TYPE_ _FREQ_)
				MEAN(SE_PP) = ASE;
			RUN;
						
			DATA ASE_PP;
				SET ASE_PP;
				LENGTH Variable $ 20. Seed 5.;
				Variable = "PP";
				Seed = &Seed.;
			RUN;

			DATA OUTPUT.ASE_Step3; SET OUTPUT.ASE_Step3 ASE_PP; RUN;
			
			/* MODEL */
			
			%LET iter2=1;
				%DO %WHILE (&iter2.<= &varCount.);
				DATA _NULL_;
					SET WORK.Var_LIST (firstobs=&iter2. obs=&iter2.);
					CALL SYMPUT ("Var", STRIP(Variable)); 
				RUN;
				
				/* STEP 3*/
				%LET Initial	= OUTPUT.Step3_InitEst;
				%LET DATA		= PRESTEP3;
				%LET Dependent 	= ADJ_PP2;
				%LET Weight 	= ADJ_ECY2;
				%LET OUTPUT 	= OUTPUT.PRED_PP_STEP3;
				%LET Predict 	= Pred_PP_STEP3;
				%LET Result 	= OUTPUT.STEP3;
				%LET Parameter	= OUTPUT.PARAM_STEP3;
				%LET Paracsv	= Parameter_S3_&Seed..csv;
				%LET Next		= OUTPUT.PRESTEP4;
				%LET ADJ_PP		= ADJ_PP3;
				%LET ADJ_ECY	= ADJ_ECY3;
				
				%LET CLASS_VAR_STEP3 = 	&Var.
										BMT2
										BMT_NO_LIV_CR_GRP_BUSTIER_UW_ROW
										BMT_NO_LIV
										OWN_OP_FR
										OWN_OP_FR_BMT
										OOS_DRVR_POL_LVL (REF = 'Y')
										OOS_BMT_NO_LIV
										PREF_TRUCK (REF = 'BACON')
										PREF_TRUCK_INT (REF = 'BACON');

				%LET MDL_VAR_STEP3 =  	&Var.
										BMT_NO_LIV_CR_GRP_BUSTIER_UW_ROW 
										BMT2|PTS_GRP00
										BMT2|PTS_GRP01
										BMT2|PTS_GRP02
										BMT2|PTS_GRP03
										BMT2|PTS_GRP04
										BMT2|PTS_GRP_GE5
										OWN_OP_FR
										OWN_OP_FR_BMT
										OOS_DRVR_POL_LVL 
										OOS_BMT_NO_LIV
										PREF_TRUCK_INT;
										
				ods OUTPUT ParameterEstimates = &Initial.;

					PROC HPGENSELECT DATA= &DATA. MAXTIME=345600 MAXIT=3000 MAXFUNC=3000 TECHNIQUE=NRRIDG;
					CLASS  /MISSING;
					MODEL &Dependent. = / Distribution=Tweedie Link=Log CL;
					WEIGHT &Weight.;
					Partition ROLE=SAMPLE (Test="Test" Train="Train");
					PERFORMANCE NTHREADS = 80;
				RUN;

				ods listing;
										
				DATA _null_;
					SET &Initial.;
					IF 	Parameter="Dispersion" then call symputx("D", Estimate);
					IF 	Parameter="Power" then call symputx("P", Estimate);
				RUN; 
					
				ods csvall file = "&TXT_LOCATION\&Paracsv";
				ods OUTPUT ParameterEstimates = &Parameter.;

				proc hpgenselect DATA= &DATA. MAXTIME=345600 MAXIT=3000 MAXFUNC=3000 TECHNIQUE=NRRIDG GCONV=0.0001 ABSFCONV=0.0001 outest;
					class  &CLASS_VAR_Step3./MISSING;
					ID rownumber;
					model &Dependent. = &MDL_VAR_Step3. / Distribution=Tweedie (P=&P.) Link=Log InitialPhi= &D. CL ;
					weight &WEIGHT.;
					Partition ROLE=SAMPLE (Test="Test" Train="Train");
					Output out = &OUTPUT. Predicted=&Predict.;
					PERFORMANCE NTHREADS = 80;
				Run;

				ods listing;
				ods csvall close;

				PROC SORT DATA = &OUTPUT.; BY rownumber; Run;
				PROC SORT DATA = &DATA.; BY rownumber; Run;

				DATA &Result.; MERGE &DATA. &OUTPUT.; RUN;

				/* Summary */
				DATA &Next.;
					SET &Result. ( where = (POL_RENW_IND = 'Y'));
					&ADJ_PP. = &Dependent./&Predict.;
					&ADJ_ECY. = &WEIGHT.*(&Predict.)**(2-&P.);
				RUN;			

				/* STEP 4*/
				%LET Initial	= OUTPUT.Step4_InitEst;
				%LET DATA		= OUTPUT.PRESTEP4;
				%LET Dependent 	= ADJ_PP3;
				%LET Weight 	= ADJ_ECY3;
				%LET OUTPUT 	= OUTPUT.PRED_PP_STEP4;
				%LET Predict 	= Pred_PP_STEP4;
				%LET Result 	= OUTPUT.STEP4;
				%LET Parameter	= OUTPUT.PARAM_STEP4;
				%LET Paracsv	= Parameter_S4_&Seed..csv;
				%LET Next		= OUTPUT.PRESTEP5;
				%LET ADJ_PP		= ADJ_PP4;
				%LET ADJ_ECY	= ADJ_ECY4;
				
				%LET CLASS_VAR_STEP4 =  pla_cnt_grp (REF='0')
										PLA_CNT_GRP_PUC_GRP_FLEET (REF = '0||1');

				%LET MDL_VAR_STEP4 =	pla_cnt_grp
										PLA_CNT_GRP_PUC_GRP_FLEET;
										
				ods OUTPUT ParameterEstimates = &Initial.;

					PROC HPGENSELECT DATA= &DATA. MAXTIME=345600 MAXIT=3000 MAXFUNC=3000 TECHNIQUE=NRRIDG;
					CLASS  /MISSING;
					MODEL &Dependent. = / Distribution=Tweedie Link=Log CL;
					WEIGHT &Weight.;
					Partition ROLE=SAMPLE (Test="Test" Train="Train");
					PERFORMANCE NTHREADS = 80;
				RUN;

				ods listing;
				
				DATA _null_;
					SET &Initial.;
					IF 	Parameter="Dispersion" then call symputx("D", Estimate);
					IF 	Parameter="Power" then call symputx("P", Estimate);
				RUN; 
				
				ods csvall file = "&TXT_LOCATION\&Paracsv";
				ods OUTPUT ParameterEstimates = &Parameter.;

				proc hpgenselect DATA= &DATA. MAXTIME=345600 MAXIT=3000 MAXFUNC=3000 TECHNIQUE=NRRIDG GCONV=0.0001 ABSFCONV=0.0001 outest;
					class  &CLASS_VAR_Step4./MISSING;
					ID rownumber;
					model &Dependent. = &MDL_VAR_Step4. / Distribution=Tweedie (P=&P.) Link=Log InitialPhi= &D. CL ;
					weight &WEIGHT.;
					Partition ROLE=SAMPLE (Test="Test" Train="Train");
					Output out = &OUTPUT. Predicted=&Predict.;
					PERFORMANCE NTHREADS = 80;
				Run;

				ods listing;
				ods csvall close;

				PROC SORT DATA = &OUTPUT.; BY rownumber; Run;
				PROC SORT DATA = &DATA.; BY rownumber; Run;

				DATA &Result.; MERGE &DATA. &OUTPUT.; RUN;

				PROC SQL;
					Create Table OUTPUT.capp_79b_output_&iter2. AS
					Select A.*, 
					CASE WHEN B.PRED_PP_STEP4 IS NULL THEN 1 ELSE B.PRED_PP_STEP4 END AS PRED_PP_STEP4
					FROM OUTPUT.STEP3 AS A
					LEFT JOIN OUTPUT.STEP4 AS B
					ON A.ROWNUMBER = B.ROWNUMBER;
				QUIT;
				
				DATA OUTPUT.capp_79b_output_&iter2.;
					SET OUTPUT.capp_79b_output_&iter2.;
					Pred_&iter2. = Pred_PP_STEP1*Pred_PP_STEP2*Pred_PP_STEP3*Pred_PP_STEP4;
				RUN;
				
				PROC SORT DATA = OUTPUT.FINAL_OUTPUT; BY rownumber; RUN;
				PROC SORT DATA = OUTPUT.capp_79b_output_&iter2.; BY rownumber; RUN;
				
				DATA OUTPUT.FINAL_OUTPUT; 
					MERGE OUTPUT.FINAL_OUTPUT 
						  OUTPUT.capp_79b_output_&iter2. (KEEP = Pred_&iter2. SAMPLE WHERE = (SAMPLE = 'Test')); 
				RUN;
				
				/* SE CALCULATION */
				
				PROC SUMMARY DATA = OUTPUT.FINAL_OUTPUT NOPRINT NWAY;
					VAR Pred_&iter2.;
					WEIGHT BIPD_ECY;
					OUTPUT OUT= MEAN_&iter2. (DROP=_TYPE_ _FREQ_)
					MEAN(Pred_&iter2.) = MEAN_Pred_&iter2.;
				RUN;
				
				DATA _NULL_; SET MEAN_&iter2.;
					IF _N_ = 1 THEN DO; CALL SYMPUTX ('MEAN', MEAN_Pred_&iter2.);
					END; STOP;
				RUN;

				DATA OUTPUT.FINAL_OUTPUT;
					SET OUTPUT.FINAL_OUTPUT;
					MEAN_Pred_&iter2. = &MEAN.;
					IF MEAN_Pred_&iter2. = 0 THEN RB_Pred_&iter2. = 0;
					   ELSE RB_Pred_&iter2. = (Pred_&iter2./MEAN_Pred_&iter2.)*100;
					SE_Pred_&iter2. = ((RB_PP - RB_Pred_&iter2.)**2);
				RUN;
				
				/* Return ASE */
				PROC SUMMARY DATA = OUTPUT.FINAL_OUTPUT NOPRINT NWAY;	
					VAR SE_Pred_&iter2.;
					WEIGHT BIPD_ECY;
					OUTPUT OUT= ASE_&iter2. (DROP=_TYPE_ _FREQ_)
					MEAN(SE_Pred_&iter2.) = ASE;
				RUN;
				
				DATA ASE_&iter2.;
					SET ASE_&iter2.;
					LENGTH Variable $ 20. Seed 5.;
					Variable = "&Var.";
					Seed = &Seed.;
				RUN;

				DATA OUTPUT.ASE_Step3;
					SET OUTPUT.ASE_Step3 ASE_&iter2.;
				RUN;				
				
				/* Delete unnecessary record */				
				PROC DELETE DATA = MEAN_&iter2.; RUN;
				PROC DELETE DATA = ASE_&iter2.;  RUN;
				PROC DELETE DATA = OUTPUT.capp_79b_output_&iter2.; RUN;
				
				%LET iter2 = %eval(&iter2.+1);
			%END;
			
		/*Delete unnecessary record*/ 
			
		PROC DELETE DATA = OUTPUT.Step3_InitEst; RUN;
		PROC DELETE DATA = OUTPUT.PRED_PP_STEP3; RUN;
		PROC DELETE DATA = OUTPUT.STEP3; 		 RUN;			
		PROC DELETE DATA = OUTPUT.PARAM_STEP3; 	 RUN;
				
		PROC DELETE DATA = OUTPUT.Step4_InitEst; RUN;
		PROC DELETE DATA = OUTPUT.prestep4; 	 RUN;
		PROC DELETE DATA = OUTPUT.PRED_PP_STEP4; RUN;
		PROC DELETE DATA = OUTPUT.STEP4; 		 RUN;
		PROC DELETE DATA = OUTPUT.PARAM_STEP4; 	 RUN;
		
		PROC DELETE DATA = OUTPUT.FINAL_OUTPUT;  RUN;
		PROC DELETE DATA = 		  MEAN_PP; 		 RUN;
		PROC DELETE DATA = 		  ASE_PP;		 RUN;
		
		%LET iter1=%eval(&iter1.+1);
	%END;
%MEND;

%loopOverSeeds()
