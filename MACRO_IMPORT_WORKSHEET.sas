%MACRO 
READXLS1(VAR);
	PROC IMPORT OUT = &VAR. 
	DATAFILE = "xx.xls"
	DBMS=XLS REPLACE;
	SHEET = "&&VAR";
	GETNAMES = YES;
	MIXED = YES;
RUN;
%MEND;


%MACRO FMT_CREATOR(VAR); /*set up and name the macro*/
	%LET DS = %SYSFUNC(OPEN(&VAR,IS)); /*set macro variable ds to be the variable's factor sheet from excel, opened in input mode, read sequentially*/
	%DO I = 1 %TO %SYSFUNC(ATTRN(&DS,NVARS)); /*do from I = 1 to the number of variables in ds*/
		%LET DSVN&I = %SYSFUNC(VARNAME(&DS,&I)); /*set macro variable dsvn# to be the name of variable in position I from ds*/  
	%END;

	%DO i= 2 %TO %SYSFUNC(ATTRN(&DS,NVARS)); /*do from I=2 to the number of variables in ds*/
	DATA TEMP&I; /*create dataset temp#*/
		SET &VAR. END=LAST; /*set the factor sheet specified, end the loop at the last variable*/
		RETAIN FMTNAME "FMT_&&DSVN&I" TYPE 'C'; /*creates a format named fmt_dsvn# and makes it a character variable*/
		START = &DSVN1;
		LABEL = STRIP(&&DSVN&I); /*remove leading and trailing blanks from dsvn#*/
		OUTPUT;
	
		IF LAST THEN DO; 
		      HLO='O';
		      LABEL=.;
		      OUTPUT;
		END;
	RUN;
	PROC FORMAT LIBRARY=WORK CNTLIN=TEMP&I;RUN; /*save to the work library*/
	PROC DELETE DATA = WORK.TEMP&I; RUN;
	%END;
	%IF &DS > 0 %THEN 
	%LET rc = %SYSFUNC(CLOSE(&DS));
%MEND FMT_CREATOR;

