#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function ShowCCNprocs()
	//The only purpose of this function is to be the reference point for opening this procedure window
	// from the menu bar.
	//=> leave this function at the top of the procedure window
	DisplayProcedure "ShowCCNprocs"
End

// Define constants
strconstant ksdfCCNmerged = "root:CCN:merged"
strconstant ksdfCCN = "root:CCN"

//*****************************************************
menu  "CCN-X00"
	
	"Show CCN procs"
	submenu "Load & Merge"
		"Load CCN Files", load_CCNX00_files()
		"Merge CCN files", MergeCCN_tseries()
		"Merge & Kill CCN files", MergeCCN_tseries(kill=1)
	end
	submenu "CCN-200"
		"Get times where %SS changed", CCN200_ChangeInSS()
		"Average periods of constant %SS", CCN200_AvgStablePeriods()
		"Batch fit f_act vs. %SS curves", CCN200_1Sigmoid_BatchFit()
	end
	submenu "CCN-200_B"
		"Get times where %SS changed", CCN200_ChangeInSS_B()
		"Average periods of constant %SS", CCN200_AvgStablePeriods_B()
		"Batch fit f_act vs. %SS curves", CCN200_1Sigmoid_BatchFit()
	end
	submenu "CCN-100"
		"Get times where %SS changed", CCN100_ChangeInSS()
		"Average periods of constant %SS", CCN100_AvgStablePeriods()
		"Batch fit f_act vs. %SS curves", CCN100_1Sigmoid_BatchFit()	
	end
end

//****************************************************************
// List of procedures
load_CCNX00_files()
CCNX00_Loader()
MergeCCN_tseries()
CCN200_ChangeInSS()
CCN200_AvgStablePeriods()
CCN200_1Sigmoid_BatchFit()
CCN200_GetIndicesForFits()
CCN100_ChangeInSS()
CCN100_AvgStablePeriods()
CCN100_1Sigmoid_BatchFit()
CCN100_GetIndicesForFits()
//

//****************************************************************
// Basic Data processing steps
// 1. Load data from one or more files (load_CCN200_files())
// 2. Merge data from loaded files into a single "merged" folder (MergeCCN_tseries())
// 3. Visually inspect the time series of collected data by making graphs of e.g. 
//	CCN_number_conc_A, CCN_number_conc_B vs TimeSecs
// 	T1_Read_A, T2_Read_A, T3_Read_A, T_inlet_A, T_OPC_A, T_Sample_A vs timesecs
//	image plots of the OPC droplet size distributions
// 4. Determine averages of CCN concentrations during stable periods
//	a. determine when the supersaturation was changed (CCN_ChangeInSS())
//	b. get averages (CCN_AvgStablePeriods())
// 5. Visually inspect the averages by graphing e.g.,
//	CCN_A vs TimeStart_A --> include standard deviations
//	CCN_B vs TimeStart_B --> include standard deviations
// 6. Fit a sigmoid to each activation curve (CCN vs. %SS) to determine the critical supersaturation
//	a. First graph CCN_A vs SS_A and CCN_B vs SS_B
//	b. Then run "CCN_1Sigmoid_BatchFit()"
// 7. Inspect Scrit output
//	a. Graph scrit_A vs Time_scrit_A and scrit_B vs Time_scrit_B
//


//************************************************************************************
function load_CCNX00_files()
	// to load a one or more CCN file
	// The user selects the files after the window pops up
	string extension = "csv"
	Variable refNum
	String message = "Select one or more CCN files"
	String file_list
	String fileFilters = "Data Files (*."+extension+"):."+extension+";"
	Open /D /R /MULT=1 /F=fileFilters /M=message refNum
	file_list = S_fileName
	if (strlen(file_list) == 0)
		print "==================================="
		print "No Data Files Chosen for Loading.  Aborting."
		print "==================================="
		Close/A
		setdatafolder root:
		abort
	endif
	Close/A
	file_list = replacestring("\r",file_list,";")
	file_list = sortlist(file_list,";",16)
	newdatafolder/o/s root:CCN	
	CCNX00_Loader(file_list)
	setdatafolder root:CCN
end

//*******************************************************************************
Function CCNX00_Loader(file_list)//,filenum,[loadDF])
	string file_list
	variable filenum
	string loadDF
	
	// Base folder
	string df_CCN = "root:CCN"
	string df_load
	
	killwaves/a/z // kills all waves in the folder that you are loading into.
	
	variable linenum_headers = 4 // starting from 0
	variable linenum_start = 6
	variable skiplines = 9
	variable nlines
	variable nWaves
	string OneLine
	string ListOfWaveNames
	
	variable i		// loop counter
	variable j		// loop counter
	variable k 	// loop counter
	variable nfiles = itemsinlist(file_list,";")
	variable ilist // the number of items in the file name string
	string file_full_path
	string full_path
	string file_name
	string DateStr
	
	linenum_start += skiplines
	
	for (i=0;i<nfiles;i+=1)
		file_full_path = stringfromlist(i,file_list)
		full_path = ParseFilePath(3, file_full_path, ":", 0, 0)
		full_path = ReplaceString(":"+ParseFilePath(3, file_full_path, ":", 0, 0)+".csv",file_full_path,"")
		file_name = ParseFilePath(0, file_full_path, ":", 1, 0)
		ilist = itemsinlist(file_name," ")
		DateStr = stringfromlist(ilist-1,file_name," ")
//		DateStr = stringfromlist(2,file_name," ")
		DateStr = ReplaceString(".csv",DateStr,"")
		df_load = df_CCN + ":x" + DateStr
		NewDataFolder/o/s $df_load
		KillWaves/A
		
		NewPath/C/Q/O DataPath full_path // for use when saving temp data
		
		// First get names of waves to be loaded
		LoadWave/Q/J/K=2/V={""," $",0,0}/L={0,0,0,0,1}/n=CCN file_full_path
		wave/t CCN0
		nlines = numpnts(CCN0) - linenum_start
		ListOfWaveNames = CCN0[linenum_headers]
		ListOfWaveNames = ReplaceString("  ",ListOfWaveNames,"")
		ListOfWaveNames = ReplaceString(" ",ListOfWaveNames,"_")
		ListOfWaveNames = ReplaceString(",_",ListOfWaveNames,",")
		ListOfWaveNames = ReplaceString("Time",ListOfWaveNames,"TimeW")
		ListOfWaveNames = ReplaceString("#",ListOfWaveNames,"x")
		ListOfWaveNames = ReplaceString("1st",ListOfWaveNames,"First")
		ListOfWaveNames = ReplaceString(".",ListOfWaveNames,"")
		ListOfWaveNames = ReplaceString(",",ListOfWaveNames,";C=1,N=")
		ListOfWaveNames = "C=1,F=6,N=" + ListOfWaveNames + ";" //+ "\""

		// Deal with the timewave separately
		variable dateInSecs
		dateInSecs = date2secs(str2num("20"+DateStr[0,1]),str2num(DateStr[2,3]),str2num(DateStr[4,5]))
		make/o/t/n=(nlines) CCNsave
		string TimeStr
		make/o/d/n=(nlines) TimeSecs
		setscale/p d, 0, 1, "dat" TimeSecs
		for(j=linenum_start;j<numpnts(CCN0);j+=1)
			OneLine = CCN0[j]
			OneLine = ReplaceString(" ",OneLine,"")
			OneLine = ReplaceString(",",OneLine,";")
			TimeStr = stringfromlist(0,OneLine,";")
			TimeSecs[j-linenum_start] = dateInSecs + str2num(stringfromlist(0,TimeStr,":"))*3600+str2num(stringfromlist(1,TimeStr,":"))*60+str2num(stringfromlist(2,TimeStr,":"))
		endfor
		// Now load the rest of the wave
		LoadWave/Q/J/W/B=ListOfWaveNames/A/L={linenum_headers,linenum_start,0,1,0} file_full_path
		KillWaves CCN0, CCNsave
	endfor
	setdatafolder $df_CCN
	
End

//************************************************************************************
// Function to merge CCN data from different files into one folder/timeseries
// Merged t-series stored in "merged" folder
Function MergeCCN_tseries([kill])
	variable kill // set to 1 to kill waves

	if(paramisdefault(kill))
		kill = 0
	endif
	
	string df_CCN = "root:CCN:"
	setdatafolder $df_CCN
	string df_CCN_Merged = "root:CCN:Merged"
	if(datafolderexists(df_CCN_Merged)==0)
		newdatafolder $df_CCN_Merged
	endif
	
	variable ndf = countobjects(":",4)	//directories with files
	string datafolder_list,datafolder_str, file_name_str
	string wavenames
	string cdf
	//get datafolder list, check for "x" at begining due to start of file with number, sort alpha numerically
	datafolder_list = stringbykey("FOLDERS",DataFolderDir(1))
	//remove ("Merged") datafolder name from list
	if (stringmatch(datafolder_list,"*Merged*"))
		datafolder_list = RemoveFromList("Merged",datafolder_list,",")
		ndf -= 1
	endif
	//sort datafolders alpha numerically.  NOTE this will not sort mixed "x" directories with other directories well...
	datafolder_list = sortlist(datafolder_list,",",16)	

	setdatafolder df_CCN_merged
	variable i, j
	
	// get wave list from first data folder
	cdf = df_CCN + stringfromlist(0,datafolder_list,",")
	setdatafolder $cdf
	wavenames = wavelist("*",";","")
	setdatafolder $df_CCN

	string string4cat = ""
	for(j=0;j<itemsinlist(wavenames,";")-1;j+=1)
		string4cat = ""
		for(i=0;i<ndf;i+=1)
			string4cat += df_CCN + stringfromlist(i,datafolder_list,",") + ":" + stringfromlist(j,wavenames,";") + ";"
		endfor
		
		concatenate/o/np string4cat, $(df_CCN_merged + ":" + stringfromlist(j,wavenames,";"))
	endfor		
	
	if(kill==1)
		setdatafolder $df_CCN
		string string2kill = ""
		for(i=0;i<ndf;i+=1)
			string2kill = df_CCN + stringfromlist(i,datafolder_list,",") 
			killdatafolder $string2kill
		endfor
	endif
	setdatafolder $df_CCN_Merged
End


//**************************************************************************
// Determine the times when the supersaturation changed from one value to the next
Function CCN200_ChangeInSS()
	// assumes an increasing %SS scan, with a big step down at the end
	// the offset for settling is different for increasing versus decreasing changes in %SS

	setdatafolder root:CCN:merged
	wave TimeSecs
	wave DTA = Current_SS_A // the currently set supersaturation for channel A
	wave DTB = Current_SS_B // the currently set supersaturation for channel B
	variable npnts = numpnts(timesecs)
	
	make/o/d/n=(npnts) DTA_dif = nan, DTB_dif = nan
	// calculate the difference between subsequent points
	DTA_dif[0,npnts-2] = DTA - DTA[x+1]
	DTB_dif[0,npnts-2] = DTB - DTB[x+1]
	
	// Get Indices where a change occurred, either an increase or decrease
	Extract/Indx/O DTA_dif, IncreaseA_indx, DTA_dif < 0
	Extract/Indx/O DTA_dif, DecreaseA_indx, DTA_dif > 0
	Extract/Indx/O DTB_dif, IncreaseB_indx, DTB_dif < 0
	Extract/Indx/O DTB_dif, DecreaseB_indx, DTB_dif > 0
	
	// Get Times
	Extract/O TimeSecs, Time_IncreaseA, DTA_dif < 0
	Extract/O TimeSecs, Time_DecreaseA, DTA_dif > 0
	Extract/O TimeSecs, Time_IncreaseB, DTB_dif < 0
	Extract/O TimeSecs, Time_DecreaseB, DTB_dif > 0
	
	make/o/d/n=(numpnts(Time_increaseA)+numpnts(Time_DecreaseA)) Time_ChangeA, Time_UpDown_A, DTA_dif_exp
	make/o/d/n=(numpnts(Time_increaseB)+numpnts(Time_DecreaseB)) Time_ChangeB, Time_UpDown_B, DTB_dif_exp
	
	Time_ChangeA[0,numpnts(Time_increaseA)-1] = Time_IncreaseA[x]
	Time_ChangeA[numpnts(Time_increaseA),] = Time_DecreaseA[x-numpnts(Time_increaseA)]
	Time_UpDown_A[0,numpnts(Time_increaseA)-1] = 0
	Time_UpDown_A[numpnts(Time_increaseA),] = 1
	sort Time_ChangeA, Time_ChangeA, Time_UpDown_A // sort the times
	
	Time_ChangeB[0,numpnts(Time_increaseB)-1] = Time_IncreaseB[x]
	Time_UpDown_B[0,numpnts(Time_increaseB)-1] = 0
	Time_ChangeB[numpnts(Time_increaseB),] = Time_DecreaseB[x-numpnts(Time_increaseB)]
	Time_UpDown_B[numpnts(Time_increaseB),] = 1
	sort Time_ChangeB, Time_ChangeB, Time_UpDown_B // sort the times
	 
	// Adjust Start Times
	variable t_settling_up = 60 // seconds
	variable t_settling_down = 120
	variable t_scan = 240 // seconds
	variable t_minus = 10
	
	Wave Time_ChangeA, Time_ChangeB
	Duplicate/o Time_ChangeA TimeStart_A, TimeStop_A
	Duplicate/o Time_ChangeB TimeStart_B, TimeStop_B
	TimeStart_A = Time_UpDown_A==0 ? Time_ChangeA + t_settling_up : Time_ChangeA + t_settling_down
	TimeStart_B = Time_UpDown_B==0 ? Time_ChangeB + t_settling_up : Time_ChangeB + t_settling_down
	TimeStop_A[0,numpnts(TimeStart_A)-2] = Time_ChangeA[x+1] - t_minus
	TimeStop_A[numpnts(TimeStart_A)-1] = Time_ChangeA[numpnts(Timestart_A)-2] + t_scan
	TimeStop_B[0,numpnts(TimeStart_B)-2] = Time_ChangeB[x+1] - t_minus
	TimeStop_B[numpnts(TimeStart_B)-1] = Time_ChangeB[numpnts(Timestart_B)-2] + t_scan
	
	KillWaves/z DTA_Dif, DTB_dif, IncreaseA_indx, IncreaseB_indx, DecreaseA_indx, DecreaseB_indx
	KillWaves/z Time_ChangeA, Time_ChangeB, Time_increaseA, Time_decreaseA, Time_increaseB, Time_decreaseB
	
End

//**************************************************************************
// Determine the times when the supersaturation changed from one value to the next
Function CCN200_ChangeInSS_A()
	// assumes an increasing %SS scan, with a big step down at the end
	// the offset for settling is different for increasing versus decreasing changes in %SS

	setdatafolder root:CCN:merged
	wave TimeSecs
	wave DTA = Current_SS_A // the currently set supersaturation for channel A
	variable npnts = numpnts(timesecs)
	
	make/o/d/n=(npnts) DTA_dif = nan, DTB_dif = nan
	// calculate the difference between subsequent points
	DTA_dif[0,npnts-2] = DTA - DTA[x+1]
	
	// Get Indices where a change occurred, either an increase or decrease
	Extract/Indx/O DTA_dif, IncreaseA_indx, DTA_dif < 0
	Extract/Indx/O DTA_dif, DecreaseA_indx, DTA_dif > 0
	
	// Get Times
	Extract/O TimeSecs, Time_IncreaseA, DTA_dif < 0
	Extract/O TimeSecs, Time_DecreaseA, DTA_dif > 0
	
	make/o/d/n=(numpnts(Time_increaseA)+numpnts(Time_DecreaseA)) Time_ChangeA, Time_UpDown_A, DTA_dif_exp
	
	Time_ChangeA[0,numpnts(Time_increaseA)-1] = Time_IncreaseA[x]
	Time_ChangeA[numpnts(Time_increaseA),] = Time_DecreaseA[x-numpnts(Time_increaseA)]
	Time_UpDown_A[0,numpnts(Time_increaseA)-1] = 0
	Time_UpDown_A[numpnts(Time_increaseA),] = 1
	sort Time_ChangeA, Time_ChangeA, Time_UpDown_A // sort the times
	 
	// Adjust Start Times
	variable t_settling_up = 60 // seconds
	variable t_settling_down = 120
	variable t_scan = 240 // seconds
	variable t_minus = 10
	
	Wave Time_ChangeA, Time_ChangeB
	Duplicate/o Time_ChangeA TimeStart_A, TimeStop_A
	TimeStart_A = Time_UpDown_A==0 ? Time_ChangeA + t_settling_up : Time_ChangeA + t_settling_down
	TimeStop_A[0,numpnts(TimeStart_A)-2] = Time_ChangeA[x+1] - t_minus
	TimeStop_A[numpnts(TimeStart_A)-1] = Time_ChangeA[numpnts(Timestart_A)-2] + t_scan
	
	KillWaves/z DTA_Dif, DTB_dif, IncreaseA_indx, IncreaseB_indx, DecreaseA_indx, DecreaseB_indx
	KillWaves/z Time_ChangeA, Time_ChangeB, Time_increaseA, Time_decreaseA, Time_increaseB, Time_decreaseB
	
End

//**************************************************************************
// Determine the times when the supersaturation changed from one value to the next
Function CCN200_ChangeInSS_B()
	// assumes an increasing %SS scan, with a big step down at the end
	// the offset for settling is different for increasing versus decreasing changes in %SS

	setdatafolder root:CCN:merged
	wave TimeSecs
	wave DTB = Current_SS_B // the currently set supersaturation for channel B
	variable npnts = numpnts(timesecs)
	
	make/o/d/n=(npnts) DTA_dif = nan, DTB_dif = nan
	// calculate the difference between subsequent points
	DTB_dif[0,npnts-2] = DTB - DTB[x+1]
	
	// Get Indices where a change occurred, either an increase or decrease
	Extract/Indx/O DTB_dif, IncreaseB_indx, DTB_dif < 0
	Extract/Indx/O DTB_dif, DecreaseB_indx, DTB_dif > 0
	
	// Get Times
	Extract/O TimeSecs, Time_IncreaseB, DTB_dif < 0
	Extract/O TimeSecs, Time_DecreaseB, DTB_dif > 0
	
	make/o/d/n=(numpnts(Time_increaseB)+numpnts(Time_DecreaseB)) Time_ChangeB, Time_UpDown_B, DTB_dif_exp
	
	Time_ChangeB[0,numpnts(Time_increaseB)-1] = Time_IncreaseB[x]
	Time_UpDown_B[0,numpnts(Time_increaseB)-1] = 0
	Time_ChangeB[numpnts(Time_increaseB),] = Time_DecreaseB[x-numpnts(Time_increaseB)]
	Time_UpDown_B[numpnts(Time_increaseB),] = 1
	sort Time_ChangeB, Time_ChangeB, Time_UpDown_B // sort the times
	 
	// Adjust Start Times
	variable t_settling_up = 60 // seconds
	variable t_settling_down = 120
	variable t_scan = 240 // seconds
	variable t_minus = 10
	
	Wave Time_ChangeA, Time_ChangeB
	Duplicate/o Time_ChangeB TimeStart_B, TimeStop_B
	TimeStart_B = Time_UpDown_B==0 ? Time_ChangeB + t_settling_up : Time_ChangeB + t_settling_down
	TimeStop_B[0,numpnts(TimeStart_B)-2] = Time_ChangeB[x+1] - t_minus
	TimeStop_B[numpnts(TimeStart_B)-1] = Time_ChangeB[numpnts(Timestart_B)-2] + t_scan
	
	KillWaves/z DTA_Dif, DTB_dif, IncreaseA_indx, IncreaseB_indx, DecreaseA_indx, DecreaseB_indx
	KillWaves/z Time_ChangeA, Time_ChangeB, Time_increaseA, Time_decreaseA, Time_increaseB, Time_decreaseB
	
End

//**************************************************************************
// Determine the times when the supersaturation changed from one value to the next
Function CCN200_ChangeInSS_B2([t_avg])
	variable t_avg // time, in seconds, to average each constant condition
	// assumes an increasing %SS scan, with a big step down at the end
	// the offset for settling is different for increasing versus decreasing changes in %SS

	if(paramisdefault(t_avg))
		t_avg = 120 // seconds
	endif
	
	setdatafolder root:CCN:merged
	wave TimeSecs
	wave DTB = Current_SS_B // the currently set supersaturation for channel B
	variable npnts = numpnts(timesecs)
	
	make/o/d/n=(npnts) DTB_dif = nan
	// calculate the difference between subsequent points
	DTB_dif[0,npnts-2] = abs(DTB - DTB[x+1])
	
	// Get Times
	Extract/O TimeSecs, Time_ChangeB, DTB_dif != 0
	
	make/o/d/n=(numpnts(Time_ChangeB)) TimeStop_B, TimeStart_B
	TimeStop_B = Time_ChangeB
	maketimewave(TimeStop_B)
	TimeStart_B = TimeStop_B - t_avg
	
	KillWaves/z DTA_Dif, DTB_dif, IncreaseA_indx, IncreaseB_indx, DecreaseA_indx, DecreaseB_indx
	KillWaves/z Time_ChangeA, Time_ChangeB, Time_increaseA, Time_decreaseA, Time_increaseB, Time_decreaseB
	
End




//***********************************************************************************************
// Averages periods where the %SS is stable. Used for %SS scans
Function CCN200_AvgStablePeriods()

	setdatafolder root:CCN:merged

	string tstr = "TimeSecs"
	string tstartstr = "TimeStart"
	string tstopstr = "TimeStop"
	string std = "_std"
	string nave = "_nave"
	string wvs2avg = "CCN_Number_Conc;Current_SS;Delta_T;SS_Calc" // these will have an A or B appended
	string newnames = "CCN;SS;DeltaT;SS_Calc_avg" // these will have an A or B appended
	variable nwvs = itemsinlist(wvs2avg,";")
	variable i, j
	string todo
	
	for(i=0;i<nwvs;i+=1)
		// A --> relies on the 2015GeneralMacros.ipf
		todo = "AveragUsingStartStop(\"" + tstr + "\",\"" + stringfromlist(i,wvs2avg,";") + "_A\",\"" + stringfromlist(i,newnames,";") + "_A\",\""
		todo +=  stringfromlist(i,newnames,";") + "_A" + std + "\",\"" +  stringfromlist(i,newnames,";") +"_A" + nave + "\",\""
		todo += tstartstr + "_A\",\"" + tstopstr + "_A\")"
		print todo
		// B --> relies on the 2015GeneralMacros.ipf
		todo = "AveragUsingStartStop(\"" + tstr + "\",\"" + stringfromlist(i,wvs2avg,";") + "_B\",\"" + stringfromlist(i,newnames,";") + "_B\",\""
		todo +=  stringfromlist(i,newnames,";") + "_B" + std + "\",\"" +  stringfromlist(i,newnames,";") +"_B" + nave + "\",\""
		todo += tstartstr + "_B\",\"" + tstopstr + "_B\")"
		execute todo
	endfor
End

//***********************************************************************************************
// Averages periods where the %SS is stable. Used for %SS scans
Function CCN200_AvgStablePeriods_B()

	setdatafolder root:CCN:merged

	string tstr = "TimeSecs"
	string tstartstr = "TimeStart"
	string tstopstr = "TimeStop"
	string std = "_std"
	string nave = "_nave"
	string wvs2avg = "CCN_Number_Conc;Current_SS;Delta_T"//;SS_Calc" // these will have an A or B appended
	string newnames = "CCN;SS;DeltaT;SS_Calc_avg" // these will have an A or B appended
	variable nwvs = itemsinlist(wvs2avg,";")
	variable i, j
	string todo
	
	for(i=0;i<nwvs;i+=1)
		// B --> relies on the 2015GeneralMacros.ipf
		todo = "AveragUsingStartStop(\"" + tstr + "\",\"" + stringfromlist(i,wvs2avg,";") + "_B\",\"" + stringfromlist(i,newnames,";") + "_B\",\""
		todo +=  stringfromlist(i,newnames,";") + "_B" + std + "\",\"" +  stringfromlist(i,newnames,";") +"_B" + nave + "\",\""
		todo += tstartstr + "_B\",\"" + tstopstr + "_B\")"
		execute todo
	endfor
End



//******************************************************************************
// A subfunction for determining the indices of individual %SS ramps
// An alternative is to try to specify the start/stop times of scans by hand
Function CCN200_GetIndicesForFits([mindif])
	variable mindif // minimum number of points between subsequent indices
	
	if(paramisdefault(mindif))
		mindif = 5
	endif
	
	setdatafolder $ksdfCCNmerged
	variable A = 0
	variable B = 1
	
	variable npnts
	variable dif
	variable i = 0
	variable j = 0
		
	if(A==1)
		wave Time_UpDown_A
		
		extract/o/INDX Time_UpDown_A, Indx_Down_A, Time_UpDown_A == 1
		Duplicate/o Indx_Down_A Indx_Up_A
		
		Indx_Up_A[0,numpnts(Indx_Down_A)-2] = Indx_Down_A[x+1]-1
		Indx_Up_A[numpnts(indx_down_a)-1] = numpnts(Time_UpDown_A)
		npnts = numpnts(indx_up_A)
		
		do
			dif = Indx_Up_A[i] - Indx_Down_A[i]
			if(dif < mindif)
				DeletePoints i, 1, Indx_Down_A, Indx_Up_A
			else
				i += 1
			endif
			j += 1
		while(j < npnts)
			
	endif
	
	if(B==1)
		wave Time_UpDown_B
		extract/o/INDX Time_UpDown_B, Indx_Down_B, Time_UpDown_B == 1
		Duplicate/o Indx_Down_B, Indx_Up_B
		Indx_Up_B[0,numpnts(Indx_Down_B)-2] = Indx_Down_B[x+1]-1
		Indx_Up_B[numpnts(indx_down_B)-1] = numpnts(Time_UpDown_B)
	
		npnts = numpnts(indx_up_B)	
		i = 0
		j = 0
		do
			dif = Indx_Up_B[i] - Indx_Down_B[i]
			if(dif < mindif)
				DeletePoints i, 1, Indx_Down_B, Indx_Up_B
			else
				i += 1
			endif
			j += 1
		while(j < npnts)
	endif
End

//************************************************************************
// Batch fit activation curves to determine critical supersaturation
// This is setup to assume no contribution of q2's to the activation curve
Function CCN200_1Sigmoid_BatchFit()

	CCN200_ChangeInSS() // find points where SS values change and extract times
	CCN200_GetIndicesForFits(mindif=5) // get indices for fitting

	wave CCN_A, CCN_B
	wave CCN_A_std, CCN_B_std
	wave SS_A, SS_B
	wave TimeStart_A, TimeStart_B
	wave indx_up_A, indx_down_A
	wave indx_up_B, indx_down_B
	
	// Specify Initial Conditions and Constraints
	make/o/d/n=(4) W_coef = {0, 200, 0.15, 0.08} // base, max, xhalf, rate
	make/o/d/n=(4) W_coefref = W_Coef
	Make/O/T/N=5 T_Constraints
	T_Constraints[0] = {"K1 > 0","K2 > 0.05","K2 < 1","K3 > .01","K3 < .3"}
	
	variable nfits
	variable i, j
	
	// A
	nfits = numpnts(indx_up_A)
	make/o/d/n=(nfits,6) FitResults_A = nan
	make/o/d/n=(nfits) scrit_A = nan
	make/o/d/n=(nfits) Time_scrit_A
	wave FitResults = FitResults_A
	wave scrit = scrit_A
	wave TimeW = TIme_scrit_A
	note/k scrit "The critical supersaturation"
	setscale/p d, 0, 1, "dat" TimeW
	note/k TimeW "The midpoint time of the scrit determination"
	for(i=0;i<nfits;i+=1)
		W_coef = W_coefRef
		CurveFit/Q/H="1000"/NTHR=0 Sigmoid kwCWave=W_coef,  CCN_A[indx_down_A[i],indx_up_A[i]] /X=SS_A /W=CCN_A_std /I=1 /D /C=T_Constraints
		wave W_coef, W_sigma
		FitResults[i][0,3] = W_coef[q]
		FitResults[i][4] =W_sigma[2]
		FitResults[i][5] = V_chisq
		scrit[i] = W_coef[2]
		timew[i] = (TimeStart_A[indx_down_A[i]]+TimeStart_A[indx_up_A[i]])/2
	endfor
	// B
	nfits = numpnts(indx_up_B)
	make/o/d/n=(nfits,6) FitResults_B = nan // stores the fit results
	make/o/d/n=(nfits) scrit_B = nan // stores just the critical supersaturation
	make/o/d/n=(nfits) Time_scrit_B // the time wave associated with teh scrit values
	wave FitResults = FitResults_B
	wave scrit = scrit_B
	wave TimeW = Time_scrit_B
	setscale/p d, 0, 1, "dat" TimeW
	note/k scrit "The critical supersaturation"
	setscale/p d, 0, 1, "dat" TimeW
	note/k TimeW "The midpoint time of the scrit determination"
	for(i=0;i<nfits;i+=1)
		W_coef = W_coefRef
		CurveFit/Q/H="1000"/NTHR=0 Sigmoid kwCWave=W_coef,  CCN_B[indx_down_B[i],indx_up_B[i]] /X=SS_B /W=CCN_B_std /I=1 /D /C=T_Constraints
		wave W_coef, W_sigma
		FitResults[i][0,3] = W_coef[q]
		FitResults[i][4] =W_sigma[2]
		FitResults[i][5] = V_chisq
		scrit[i] = W_coef[2]
		timew[i] = (TimeStart_B[indx_down_B[i]]+TimeStart_B[indx_up_B[i]])/2
	endfor
	
//	KillWaves/z Time_UpDown_A, Time_UpDown_B, indx_up_A, indx_down_A, indx_up_B, indx_down_B
End

//**************************************************************************
////////////////////////////////////////////////////////////////
// Determine the times when the supersaturation changed from one value to the next
Function CCN100_ChangeInSS()//t_settling_up,t_settling_down,t_scan,t_minus)
	// assumes an increasing %SS scan, with a big step down at the end
	// the offset for settling is different for increasing versus decreasing changes in %SS

	setdatafolder root:CCN:merged
	wave TimeSecs
	wave DT = Current_SS // the currently set supersaturation for channel A
	variable npnts = numpnts(timesecs)
	
	// Adjust Start Times (these need to be adjusted for any given experiment!!!)
	// These would ideally be recoded to work as inputs
	variable t_settling_up = 60 // seconds
	variable t_settling_down = 120 // seconds
	variable t_scan = 240 // seconds
	variable t_minus = 10 // seconds

	make/o/d/n=(npnts) DT_dif = nan
	// calculate the difference between subsequent points
	DT_dif[0,npnts-2] = DT - DT[x+1]
	
	// Get Indices where a change occurred, either an increase or decrease
	Extract/Indx/O DT_dif, Increase_indx, DT_dif < 0
	Extract/Indx/O DT_dif, Decrease_indx, DT_dif > 0
	
	// Get Times
	Extract/O TimeSecs, Time_Increase, DT_dif < 0
	Extract/O TimeSecs, Time_Decrease, DT_dif > 0
	
	make/o/d/n=(numpnts(Time_increase)+numpnts(Time_Decrease)) Time_Change, Time_UpDown, DTA_dif_exp
	
	Time_Change[0,numpnts(Time_increase)-1] = Time_Increase[x]
	Time_Change[numpnts(Time_increase),] = Time_Decrease[x-numpnts(Time_increase)]
	Time_UpDown[0,numpnts(Time_increase)-1] = 0
	Time_UpDown[numpnts(Time_increase),] = 1
	sort Time_Change, Time_Change, Time_UpDown // sort the times
		
	Wave Time_Change
	Duplicate/o Time_Change TimeStart, TimeStop
	TimeStart = Time_UpDown==0 ? Time_Change + t_settling_up : Time_Change + t_settling_down
	TimeStop[0,numpnts(TimeStart)-2] = Time_Change[x+1] - t_minus
	TimeStop[numpnts(TimeStart)-1] = Time_Change[numpnts(Timestart)-2] + t_scan
	
	KillWaves/z DT_Dif, DTB_dif, Increase_indx, IncreaseB_indx, Decrease_indx, DecreaseB_indx
	KillWaves/z Time_Change, Time_ChangeB, Time_increase, Time_decrease, Time_increaseB, Time_decreaseB
	
End



//***********************************************************************************************
// Averages periods where the %SS is stable. Used for %SS scans
Function CCN100_AvgStablePeriods()

	setdatafolder root:CCN:merged

	string tstr = "TimeSecs"
	string tstartstr = "TimeStart"
	string tstopstr = "TimeStop"
	string std = "_std"
	string nave = "_nave"
	string wvs2avg = "CCN_Number_Conc;Current_SS;Delta_T" 
	string newnames = "CCN;SS;DeltaT"
	variable nwvs = itemsinlist(wvs2avg,";")
	variable i, j
	string todo
	
	for(i=0;i<nwvs;i+=1)
		// --> relies on the 2015GeneralMacros.ipf
		todo = "AveragUsingStartStop(\"" + tstr + "\",\"" + stringfromlist(i,wvs2avg,";") + "\",\"" + stringfromlist(i,newnames,";") + "\",\""
		todo +=  stringfromlist(i,newnames,";") + "" + std + "\",\"" +  stringfromlist(i,newnames,";") +"" + nave + "\",\""
		todo += tstartstr + "\",\"" + tstopstr + "\")"
		execute todo
	endfor
End

//******************************************************************************
// A subfunction for determining the indices of individual %SS ramps
// An alternative is to try to specify the start/stop times of scans by hand
Function CCN100_GetIndicesForFits([mindif])
	variable mindif // minimum number of points between subsequent indices
	
	if(paramisdefault(mindif))
		mindif = 5
	endif
	
	setdatafolder $ksdfCCNmerged
	wave Time_UpDown
	
	extract/o/INDX Time_UpDown, Indx_Down, Time_UpDown == 1
	
	Duplicate/o Indx_Down Indx_Up
	
	Indx_Up[0,numpnts(Indx_Down)-2] = Indx_Down[x+1]-1
	Indx_Up[numpnts(indx_down)-1] = numpnts(Time_UpDown)
	
	variable npnts = numpnts(indx_up)
	variable dif
	variable i = 0
	variable j = 0
	do
		dif = Indx_Up[i] - Indx_Down[i]
		if(dif < mindif)
			DeletePoints i, 1, Indx_Down, Indx_Up
		else
			i += 1
		endif
		j += 1
	while(j < npnts)

End

//************************************************************************
// Batch fit activation curves to determine critical supersaturation
// This is setup to assume no contribution of q2's to the activation curve
Function CCN100_1Sigmoid_BatchFit()

	CCN100_ChangeInSS() // find points where SS values change and extract times
	CCN100_GetIndicesForFits(mindif=5) // get indices for fitting

	wave CCN
	wave CCN_std
	wave SS
	wave TimeStart
	wave indx_up, indx_down
	
	// Specify Initial Conditions and Constraints
	make/o/d/n=(4) W_coef = {0, 200, 0.15, 0.08} // base, max, xhalf, rate
	make/o/d/n=(4) W_coefref = W_Coef
	Make/O/T/N=5 T_Constraints
	T_Constraints[0] = {"K1 > 0","K2 > 0.05","K2 < 1","K3 > .01","K3 < .3"}
	
	variable nfits
	variable i, j
	
	nfits = numpnts(indx_up)
	make/o/d/n=(nfits,6) FitResults = nan
	make/o/d/n=(nfits) scrit = nan
	make/o/d/n=(nfits) Time_scrit
	wave FitResults = FitResults
	wave scrit = scrit
	wave TimeW = TIme_scrit
	note/k scrit "The critical supersaturation"
	setscale/p d, 0, 1, "dat" TimeW
	note/k TimeW "The midpoint time of the scrit determination"
	for(i=0;i<nfits;i+=1)
		W_coef = W_coefRef
		CurveFit/Q/H="1000"/NTHR=0 Sigmoid kwCWave=W_coef,  CCN[indx_down[i],indx_up[i]] /X=SS /W=CCN_std /I=1 /D /C=T_Constraints
		wave W_coef, W_sigma
		FitResults[i][0,3] = W_coef[q]
		FitResults[i][4] =W_sigma[2]
		FitResults[i][5] = V_chisq
		scrit[i] = W_coef[2]
		timew[i] = (TimeStart[indx_down[i]]+TimeStart[indx_up[i]])/2
	endfor
	
//	KillWaves/z Time_UpDown_A, Time_UpDown_B, indx_up_A, indx_down_A, indx_up_B, indx_down_B
End

//*********************************************
Function CCN_MakeOPCmatrices()

	setdatafolder $ksdfCCNmerged
	wave timesecs // a reference to get the points, and to expand for _im waves
	variable nbins = 19 // perhaps make this general
	string binstr
	string BinNameRef = "Bin_"
	variable i, j
	
	make/o/d/n=(numpnts(timesecs),nbins) DropSize_A=nan, DropSize_B=nan
	Duplicate/o TimeSecs, TimeSecs_Im
	redimension/n=(numpnts(TimeSecs)+1) TimeSecs_im
	TimeSecs_im[numpnts(timesecs)] = TimeSecs_im[numpnts(timesecs)-1] + (TimeSecs_im[numpnts(timesecs)-1] - TimeSecs_im[numpnts(timesecs)-2])
	
	for(i=0;i<nbins;i+=1)
		binstr = BinNameRef + num2istr(i+1) + "_A"
		wave binwave = $binstr
		DropSize_A[][i] = binwave[p]
		binstr = BinNameRef + num2istr(i+1) + "_B"
		wave binwave = $binstr
		DropSize_B[][i] = binwave[p]
	endfor
	
End

//**************************************************************************
////////////////////////////////////////////////////////////////
// Determine the times when the supersaturation changed from one value to the next
Function CCN_GetChangeInDp()
	// assumes an increasing %SS scan, with a big step down at the end
	// the offset for settling is different for increasing versus decreasing changes in %SS

	setdatafolder root:CPC:merged
	wave TimeSecs
	wave Dp = Diameter // the currently set supersaturation for channel A
	variable npnts = numpnts(timesecs)
//	Duplicate/o Dpm, Dp
//	Dp = floor(Dpm)
	make/o/d/n=(npnts) Dp_dif = nan
	// calculate the difference between subsequent points
	Dp_dif[0,npnts-2] = Dp - Dp[x+1]
	
	// Get Indices where a change occurred, either an increase or decrease
	Extract/Indx/O Dp_dif, IncreaseDp_indx, Dp_Dif < -1
	Extract/Indx/O Dp_dif, DecreaseDp_indx, Dp_Dif > 1
	
	// Get Times
	Extract/O TimeSecs, Time_IncreaseDp, Dp_dif < -1
	Extract/O TimeSecs, Time_DecreaseDp, Dp_dif > 1
	
	make/o/d/n=(numpnts(Time_increaseDp)+numpnts(Time_DecreaseDp)) Time_ChangeDp, Time_UpDown_Dp, Dp_dif_exp
	
	Time_ChangeDp[0,numpnts(Time_increaseDp)-1] = Time_IncreaseDp[x]
	Time_ChangeDp[numpnts(Time_increaseDp),] = Time_DecreaseDp[x-numpnts(Time_increaseDp)]
	Time_UpDown_Dp[0,numpnts(Time_increaseDp)-1] = 0
	Time_UpDown_Dp[numpnts(Time_increaseDp),] = 1
	sort Time_ChangeDp, Time_ChangeDp, Time_UpDown_Dp // sort the times
	
	// Adjust Start Times
	variable t_settling_up = 00 // seconds
	variable t_settling_down = 0//120
	variable t_scan = 0//240 // seconds
	variable t_minus = 0//10
	
	Wave Time_ChangeDp
	Duplicate/o Time_ChangeDp TimeStart_Dp, TimeStop_Dp
	TimeStart_Dp = Time_UpDown_Dp==0 ? Time_ChangeDp + t_settling_up : Time_ChangeDp + t_settling_down
	TimeStop_Dp[0,numpnts(TimeStart_Dp)-2] = Time_ChangeDp[x+1] - t_minus
	TimeStop_Dp[numpnts(TimeStart_Dp)-1] = Time_ChangeDp[numpnts(Timestart_Dp)-2] + t_scan
	
	KillWaves/z Dp_Dif,  IncreaseDp_indx, DecreaseDp_indx
	KillWaves/z Time_ChangeDp, Time_increase, Time_decrease  
	
End

function CCN200_RecalcSSfromDT()
// This is important to account for non-linearities at low DeltaT/SS
// Determined for ChannelB between 07/06/22 and 07/09/22
// Channel A not determined, as it's not working currently

	cd root:CCN:merged
	
	variable split_DeltaT
	//ChannelA
	wave SS = Current_SS_A
	wave DeltaT = Delta_T_A
	make/o/n=(numpnts(SS))/d SS_calc_A
	wave SS_calc = SS_Calc_A
	make/o/d/n=(2) FitCoefs = {-0.10192,0.068419} // this is based on the current calibration
	SS_calc = FitCoefs[0]+FitCoefs[1]*DeltaT
	// ChannelB
	Split_DeltaT = 5.7 // the deltaT at which you switch from non-linear (below) to a linear (above) function
	wave SS = Current_SS_B
	wave DeltaT = Delta_T_B
	make/o/n=(numpnts(SS))/d SS_calc_B
	wave SS_calc = SS_calc_B
	Make/o/d FitCoefs={0,0.0643,-0.045926,0.0156,-0.0016703,4.9986e-05}
	SS_calc = FitCoefs[0]+FitCoefs[1]*DeltaT+FitCoefs[2]*DeltaT^2+FitCoefs[3]*DeltaT^3+FitCoefs[4]*DeltaT^4+FitCoefs[5]*DeltaT^5
  	Make/o/d FitCoefs={-0.036708,0.060499}
  	SS_calc = DeltaT > Split_DeltaT ?  FitCoefs[0]+FitCoefs[1]*DeltaT : SS_calc
	
End

//***************************************************
// This is important to account for non-linearities at low DeltaT/SS
// Determined for ChannelB between 07/06/22 and 07/09/22
// This is a non-linear relationship
function CCN200_RecalcSSfromDTB_single(deltaT)
	variable deltaT
	cd root:CCN:merged
	
	variable split_DeltaT = 5.7
	variable SS_calc_var
	
	if(deltaT >= split_DeltaT)
		Make/o/d/FREE FitCoefs={-0.036708,0.060499} 
		SS_calc_var = FitCoefs[0]+FitCoefs[1]*DeltaT
	else
		Make/o/d/FREE FitCoefs={0,0.0643,-0.045926,0.0156,-0.0016703,4.9986e-05}
		SS_calc_var = FitCoefs[0]+FitCoefs[1]*DeltaT+FitCoefs[2]*DeltaT^2+FitCoefs[3]*DeltaT^3+FitCoefs[4]*DeltaT^4+FitCoefs[5]*DeltaT^5
	endif
	return SS_calc_var	
End

//****************************************************************************************************
function Kohler(DpDry)
	variable DpDry // in nm

	variable surfaceTension = 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.0584	// kg/mol 
	variable density_solute = 2160 // kg/m^3
	variable ShapeFactor = 1.08
	// choose your ion
	string what = "AS"
	if(stringmatch(what,"NaCl"))
		MW_solute = 0.0584	// kg/mol 
		density_solute = 2160 // kg/m^3
		ShapeFactor = 1.08
	elseif(stringmatch(what,"AS"))
		MW_solute = 0.0584	// kg/mol 
		density_solute = 2160 // kg/m^3
		ShapeFactor = 1.03
	else
		// use set values
	endif	
	
	variable Nions = 2
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	VolumeRatio = Volume_H2O/Volume_solute
	Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(V_max)
End

//*****************************************************************
// Calculate Kohler curve based on MW, density, and # of ions for ammonium sulfate
// Assumption of full solubility
function Kohler_AS(DpDry)
	variable DpDry // in nm

	DpDry /= 1.03 // shape factor
	
	variable surfaceTension = 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.13214 // 0.0584	// kg/mol // AS = 0.13214; NaCl = 0.0584
	variable density_solute = 1770 // 2160 // kg/m^3 // AS = 1770; NaCl = 2160
	variable Nions = 3 // AS = 3, NaCl = 2
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot, DpRatio
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS_kohler
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	DpRatio = DpWet/DpDry
	VolumeRatio = Volume_H2O/Volume_solute
	Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS_kohler = (RelativeHumidity-1)*100
	wavestats/q SS_kohler
	
	Killwaves/z 	Volume_H2O, DpWet, Volume_tot, DpRatio, VolumeRatio, Activity, Kelvin, RelativeHumidity, SS_kohler
	return(V_max)
End

//****************************************************************************************************
// Calculate Kohler curve based on MW, density, and # of ions for sodium chloride
// Assumption of full solubilityfunction Kohler_NaCl(DpDry)
Function Kohler_Nacl(DpDry)
	variable DpDry // in nm

	DpDry /= 1.09 // shape factor
	variable surfaceTension = 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.0584	// kg/mol // AS = 0.13214; NaCl = 0.0584
	variable density_solute = 2160 // kg/m^3 // AS = 1770; NaCl = 2160
	variable Nions = 2 // AS = 3, NaCl = 2
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot, DpRatio
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	DpRatio = DpWet/DpDry
	VolumeRatio = Volume_H2O/Volume_solute
	Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(V_max)
End

//*****************************************************************
// Calculate Kohler curve based on MW, density, for some generic organic molecule
// Assumption of full solubilityfunction Kohler_Org(DpDry)
Function Kohler_Org(DpDry)
	variable DpDry // in nm

	DpDry /= 1.0 // shape factor
	
	variable ST_H2O = 72e-3 // J/m^2 = dynes/cm divided by 1000 ,value for water
	variable ST_org = 25e-3 // J/m2
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.250 // 0.0584	// kg/mol // AS = 0.13214; NaCl = 0.0584
	variable density_solute = 1100 // 2160 // kg/m^3 // AS = 1770; NaCl = 2160
	variable Nions = 1 // AS = 3, NaCl = 2
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot, DpRatio
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	make/o/d/n=(npnts) ST_wv
	
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	DpRatio = DpWet/DpDry
	VolumeRatio = Volume_H2O/Volume_solute
	Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))

	ST_wv = ST_H2O*(Volume_H2O/Volume_Tot) + ST_Org*((Volume_Tot-Volume_H2O)/Volume_Tot)

	Kelvin = exp((4*ST_wv*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(V_max)
End

//*****************************************************************
// Calculate Kohler curve based on MW, density, for some binary organic system
// containing an insoluble part that goes to the surface, and a soluble part
// Assumption of full solubilityfunction Kohler_Org(DpDry)
Function Kohler_Org_Binary(DpDry)
	variable DpDry // in nm

	DpDry /= 1.0 // shape factor
	
	variable surfaceTension = 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.250 // 0.0584	// kg/mol // AS = 0.13214; NaCl = 0.0584
	variable density_solute = 1100 // 2160 // kg/m^3 // AS = 1770; NaCl = 2160
	variable Nions = 1 // AS = 3, NaCl = 2
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot, DpRatio
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	DpRatio = DpWet/DpDry
	VolumeRatio = Volume_H2O/Volume_solute
	Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(V_max)
End

//************************************************************************

function Kohler_SurfacePartitioning(DpDry,fSurface,ST)
	variable DpDry // in nm
	variable fSurface
	variable ST
	
	variable surfaceTension = ST*1e-3//72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute =    0.160	//0.0584 kg/mol
	variable density_solute =    1280 //1770 kg/m^3
	variable Nions = 1//2
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	VolumeRatio = Volume_H2O/Volume_solute
//	Activity = 1/(1+((1-fSurface)*Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	Activity = 1/(1+((1-fSurface)*Volume_solute*Nions*density_solute/MW_solute)*(MW_H2O/(Volume_H2O*density_H2O)))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
End

//***************************************************************
function Kohler_SP_Binary(DpDry,fSurface,ST,VF_C1)
	variable DpDry // in nm
	variable fSurface
	variable ST
	variable vf_C1 //= 0.9 // volume fraction of the not-salt component
	
	variable surfaceTension = ST*1e-3//72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	
	variable MW_C1 =    0.160	//0.0584 kg/mol
	variable density_C1 =    1280 //1770 kg/m^3
	variable Nions_C1 = 1//2
	variable Volume_C1 = vf_C1*(pi/6)*(DpDry*1e-9)^3 // m^3/particle
	
	variable MW_C2 = 0.0584 // salt
	variable density_C2 = 2160 // salt
	variable Nions_C2 = 2 // salt
	variable Volume_C2 = (1-vf_C1)*(pi/6)*(DpDry*1e-9)^3
	
	variable volume_solute = Volume_C1+Volume_C2
	
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	VolumeRatio = Volume_H2O/Volume_solute
//	Activity = 1/(1+((1-fSurface)*Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	Activity = 1/(1+(((1-fSurface)*Volume_C1*Nions_C1*density_C1/MW_C1)+(Volume_C2*Nions_C2*density_C2/MW_C2))*(MW_H2O/(Volume_H2O*density_H2O)))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(V_max)
End

//***************************************************************
function Kohler_SP_Binary2(DpDry,fSurface,ST,VF_C1)
	variable DpDry // in nm
	variable fSurface
	variable ST
	variable vf_C1 //= 0.9 // volume fraction of the not-salt component
	
	variable surfaceTension = ST*1e-3//72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	
	variable MW_C1 =    0.160	//0.0584 kg/mol
	variable density_C1 =    1280 //1770 kg/m^3
	variable Nions_C1 = 1//2
	variable Volume_C1 = vf_C1*(pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable Volume_C1_Surf = Volume_C1 * fsurface // m3/particle
	variable Molecules_C1 = (6.022e23*density_C1 * Volume_C1)/MW_C1 // molec/particle
	variable Molecules_C1_surf = Molecules_C1 * fsurface // molec/particle at the surface
	
	variable MW_C2 =  0.0584 // salt
	variable density_C2 =   2160 // salt
	variable Nions_C2 =  2 // salt
	variable Volume_C2 = (1-vf_C1)*(pi/6)*(DpDry*1e-9)^3
	variable Molecules_C2 = (6.022e23*density_C2*Volume_C2)/MW_C2
//	variable MW_solute = 0.13214 // 0.0584	// kg/mol // AS = 0.13214; NaCl = 0.0584
//	variable density_solute = 1770 // 2160 // kg/m^3 // AS = 1770; NaCl = 2160
//	variable Nions = 3 // AS = 3, NaCl = 2
	
		
	variable volume_solute = Volume_C1+Volume_C2
	
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot, DpRatio, SurfaceArea, delta, VF_C1_bulk, VF_C1_surf, VF_C2
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity, ST_wv_coat, ST_wv_tot, ST_wv_core
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	DpRatio = DpWet/DpDry
	VolumeRatio = Volume_H2O/Volume_solute
	SurfaceArea = 4*pi*(DpWet*1e-9)^2 // m2
	delta = 1e9*Volume_C1_surf/SurfaceArea // nm
	
	VF_C2 = Volume_H2O/Volume_Tot
	VF_C1_bulk = (Volume_Tot-Volume_H2O)*(1-fsurface)/Volume_Tot
	VF_C1_surf = (Volume_Tot-Volume_H2O)*(fsurface)/Volume_Tot
	
	ST_wv_core = 0.072*(Volume_H2O/Volume_Tot) + 0.025*((Volume_Tot-Volume_H2O)*(1-fsurface)/Volume_Tot)
	ST_wv_tot = delta > 0.3 ? 0.025 : VF_C1_surf*0.025 + (VF_C2 + VF_C1_Bulk)*ST_wv_Core
	
//	Activity = 1/(1+((1-fSurface)*Volume_solute*Nions*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	Activity = 1/(1+(((1-fSurface)*Volume_C1*Nions_C1*density_C1/MW_C1)+(Volume_C2*Nions_C2*density_C2/MW_C2))*(MW_H2O/(Volume_H2O*density_H2O)))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*ST_wv_tot*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(V_max)
End

//***************************************************************
Function GetCritSat_saltfrac()

	make/o/d/n=40 OrgFrac = 1-0.025*x
	make/o/d/n=40 CritSS_orgFrac = nan
	make/o/d/n=(40) Kappa_orgFrac = nan
	make/o/d/n=(40) ST_orgFrac = nan
	ST_orgFrac = 72-15*log(-(orgfrac-1)/1)^2
	wavestats/q st_orgfrac
	ST_orgFrac[0] = ST_orgFrac[1]
//	ST_orgFrac = 72
	
	variable i
	for(i=0;i<40;i+=1)
		CritSS_orgFrac[i] = kohler_sp_binary(100,1,ST_orgFrac[i],OrgFrac[i])
		Kappa_orgFrac[i] = GetKappaFromCritSS(100,72,CritSS_orgFrac[i])
	endfor
		
End

//***************************************************************
Function GetKappa_ST()

	make/o/d/n=20 ST_wave = 72-2*x
	make/o/d/n=(20,19) Kappa_ST = nan
	make/o/d/n=(19) OrgFrac_ST = 0.95 - 0.05*x
	variable current_critSS
	
	variable i,j
	for(i=0;i<20;i+=1)
		for(j=0;j<19;j+=1)
			current_critSS = kohler_sp_binary(100,1.2,ST_wave[i],OrgFrac_ST[j])
			Kappa_ST[i][j] = GetKappaFromCritSS(100,72,current_critSS)
		endfor
	endfor	
End

//***************************************************************
Function GraphKappa_ST()
	
	wave kappa_st
	wave st_wave
	
	variable i
	for(i=0;i<19;i+=1)
		appendtograph kappa_st[][i] vs st_wave
	endfor

End

//***************************************************************
Function GetKappaFromCritSS(DpDry,ST,critSS)
	variable DpDry,ST, critSS
	
	variable kappa
	kappa = 1.6
	variable step = 0.001
	variable counter = 0
	
	do
		kappa -= step
		if(kappa < 0)
			kappa = 0
			break
		endif
		KohlerKappa(DpDry,kappa,ST)
		wave SS
		wavestats/q SS
		counter += 1
	while(V_max < critSS)
	return(kappa)
End

//***************************************************************
function Kohler_SurfacePart_Soluble(DpDry,fSurface,ST)
	variable DpDry // in nm
	variable fSurface
	variable ST
	
	variable surfaceTension = ST*1e-3//72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute =    0.0584// 0.160	// kg/mol
	variable density_solute =    1770 //1280 //kg/m^3
	variable Nions = 2 // 1
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	variable aexp
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS, SoluteConcentration
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	
	SoluteConcentration = (Volume_solute*density_solute/MW_solute)/(Volume_H2O*1000) // mol/L
	variable MaxSolubility = 10 // mol/L
	SoluteConcentration = SoluteConcentration > MaxSolubility ? MaxSolubility : SoluteConcentration
	
	VolumeRatio = Volume_H2O/Volume_solute
//	Activity = 1/(1+((1-fSurface)*Nions*Volume_solute*density_solute*MW_H2O)/(Volume_H2O*density_H2O*MW_solute))
	Activity = 1/(1+((1-fSurface)*Nions*(SoluteConcentration*1000*Volume_H2O)*MW_H2O)/(Volume_H2O*density_H2O))
	aexp = (4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O)
//	print aexp
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return V_max
End

//***************************************************************
function KohlerKappa(DpDry,kappa,ST)
	variable DpDry // in nm
	variable Kappa
	variable ST

	variable surfaceTension = ST*1e-3 // 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.132	// kg/mol
	variable density_solute = 1500 // kg/m^3
	variable Nions = 2
	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot, DpRatio
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	DpRatio = DpWet/DpDry
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
	Volume_H2O = Volume_tot - Volume_solute
	VolumeRatio = Volume_H2O/Volume_solute
	//Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_solute)/(Volume_H2O*density_H2O*MW_H2O))
	Activity = (DpWet^3-DpDry^3)/(DpWet^3-DpDry^3*(1-kappa))
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(V_max) // scrit
//	return(DpWet[V_maxloc])
End

//***************************************************************
// Function to calculate a Kohler Curve for a binary system, defined by Kappa values
// Based on specified diameters
function KohlerKappaBinary(DpCore,DpCoat,KappaCore,KappaCoat,ST)
	variable DpCore // in nm
	variable DpCoat
	variable KappaCore
	variable KappaCoat
	variable ST

	variable surfaceTension = ST*1e-3 // 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.132	// kg/mol
	variable density_solute = 1500 // kg/m^3
	variable Nions = 2
//	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	
	variable frac_core = DpCore^3/(DpCoat^3)
	print "Core volume fraction = " + num2str(frac_core)
	variable Kappa = kappacore*frac_core + kappacoat*(1-frac_core)
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpCoat + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
//	Volume_H2O = Volume_tot - Volume_solute
//	VolumeRatio = Volume_H2O/Volume_solute
	//Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_solute)/(Volume_H2O*density_H2O*MW_H2O))
	Activity = (DpWet^3-DpCoat^3)/(DpWet^3-DpCoat^3*(1-kappa))
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
//	return(Dpwet[V_maxloc])
	return(SS[V_maxloc])
End

//***************************************************************
// Function to calculate a Kohler Curve for a binary system, defined by Kappa values
// Based on specified volume fraction diameters
function KohlerKappaBinary_VF(DpDry,Frac_Core,KappaCore,KappaCoat,ST)
	variable DpDry // in nm
	variable Frac_Core
	variable KappaCore
	variable KappaCoat
	variable ST

	variable surfaceTension = ST*1e-3 // 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.132	// kg/mol
	variable density_solute = 1500 // kg/m^3
	variable Nions = 2
//	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	
//	variable frac_core = DpCore^3/(DpCoat^3)
//	print frac_core
	variable Kappa = kappacore*frac_core + kappacoat*(1-frac_core)
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpDry + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
//	Volume_H2O = Volume_tot - Volume_solute
//	VolumeRatio = Volume_H2O/Volume_solute
	//Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_solute)/(Volume_H2O*density_H2O*MW_H2O))
	Activity = (DpWet^3-DpDry^3)/(DpWet^3-DpDry^3*(1-kappa))
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
//	return(Dpwet[V_maxloc])
	return(SS[V_maxloc])
End

//***************************************************************
function KohlerKappaBinary_SS(DpCore,DpCoat,KappaCore,KappaCoat,ST,RHval)
	variable DpCore // in nm
	variable DpCoat
	variable KappaCore
	variable KappaCoat
	variable ST
	variable RHval

	variable surfaceTension = ST*1e-3 // 72e-3 // J/m^2 = dynes/cm divided by 1000
	variable MW_H2O = 0.018	// kg/mol
	variable IdealGas = 8.314	// J/mol.K
	variable kb = 1.381e-23	// J/molecule.K
	variable Temperature = 298			// K
	variable density_H2O = 1000	// kg/m^3
	
	variable MW_solute = 0.132	// kg/mol
	variable density_solute = 1500 // kg/m^3
	variable Nions = 2
//	variable Volume_solute = (pi/6)*(DpDry*1e-9)^3 // m^3/particle
	
	variable frac_core = DpCore^3/(DpCoat^3)
//	print frac_core
	variable Kappa = kappacore*frac_core + kappacoat*(1-frac_core)
	
	variable npnts = 1000
	make/o/d/n=(npnts) Volume_H2O, DpWet, Volume_tot
	make/o/d/n=(npnts) VolumeRatio, Activity, Kelvin, RelativeHumidity
	make/o/d/n=(npnts) SS
	DpWet = DpCoat + 1.01^(x)
	Volume_tot = (pi/6)*(DpWet*1e-9)^3
//	Volume_H2O = Volume_tot - Volume_solute
//	VolumeRatio = Volume_H2O/Volume_solute
	//Activity = 1/(1+(Volume_solute*Nions*density_solute*MW_solute)/(Volume_H2O*density_H2O*MW_H2O))
	Activity = (DpWet^3-DpCoat^3)/(DpWet^3-DpCoat^3*(1-kappa))
	Kelvin = exp((4*surfacetension*MW_H2O)/(IdealGas*Temperature*density_H2O*DpWet*1e-9))
	RelativeHumidity = Activity*Kelvin
	SS = (RelativeHumidity-1)*100
	wavestats/q SS
	return(Dpwet[V_maxloc])
End

//***************************************************************
Function KohlerBySize()

	variable minDp = 10
	variable stepDp = 20
	variable nsteps = 25
	variable DpCurrent
	variable i
	
	variable display_YN = 1
	
	for(i=0;i<nsteps;i+=1)
		DpCurrent = minDp+i*stepDp
		Kohler(DpCurrent)
		wave SS, DpWet
		Duplicate/o SS $("SS_"+num2str(DpCurrent)+"nm")
		Duplicate/o DpWet $("DpWet_"+num2str(DpCurrent)+"nm")
	endfor
	
	if(display_YN == 1)
		display
		string ystr,xstr
		for(i=0;i<nsteps;i+=1)
			DpCurrent = minDp+i*stepDp
			wave SS = $("SS_"+num2str(DpCurrent)+"nm")
			wave DpWet = $("DpWet_"+num2str(DpCurrent)+"nm")
			appendtograph SS vs DpWet
		endfor
	endif
end

//***************************************************************
Function KohlerFindCriticalSize(kappa,ss_target)
	variable kappa
	variable ss_target
	
	variable maxiters = 1600
	variable startDp = 5
	variable stepDp = 0.1
	variable DpCurrent = startDp
	variable maxSS
	variable keepgoing = 1
	variable iters = 0
	
	do
		DpCurrent += stepDp*1.005^iters
		KohlerKappa(DpCurrent,Kappa,72)
		wave SS	
		wavestats/q SS
		maxSS = V_max
		if(maxSS < ss_target)
			keepgoing = 0
		else
			iters += 1
		endif
	while(keepgoing == 1 && iters < maxiters)
	
	if(iters >= maxiters)
		DpCurrent = 0
	endif
	
	return DpCurrent	// this is the crtical diameter
End

//***************************************************************
Function KohlerCriticalSizeRun(ss_target)
	variable ss_target
	
	variable kappa_start = 0.005
	variable kappa_step = 0.005
	variable nsteps = 260
	make/o/d/n=(nsteps) KappaWave, DpCriticalWave
	KappaWave = kappa_start + x*kappa_step
	variable i
	variable DpCrit
	
	for(i=0;i<nsteps;i+=1)
		DpCrit = KohlerFindCriticalSize(kappawave[i],ss_target)
		DpCriticalWave[i] = DpCrit
	endfor
	
	note/k DpCriticalWave "For %SS = " + num2str(ss_target)
	duplicate/o dpcriticalwave dNdlogDp
	dndlogdp = (1000/(log(1.7)*sqrt(2*pi)))*exp(-(log(DpCriticalWave)-log(100))^2/(2*(log(1.7))^2))
	wavestats/q dndlogdp
	dndlogdp/=V_max
End	

//***************************************************************
Function KohlerCriticalSizeRunSS(Kappa)
	variable kappa
	
	variable ss_start = 0.01
	variable ss_step = 0.01
	variable nsteps = 500
	make/o/d/n=(nsteps) SSwave, DpCriticalWave
	SSwave = SS_start + x*ss_step
	variable i
	variable DpCrit
	
//	for(i=0;i<nsteps;i+=1)
//		DpCrit = KohlerFindCriticalSize(kappa,SSwave)
//		DpCriticalWave[i] = DpCrit
//	endfor
	DpCriticalWave = KohlerFindCriticalSize(kappa,SSwave)
End	

//***************************************************************
Function GrowthCurves(DpStart,Kappa1,Kappa2,SS_target)
	// calculate the critical supersaturation as a function of mixing for a 2-component system
	variable DpStart // nm
	variable Kappa1 // kappa of component 1
	variable Kappa2 // kappa of component 2
	variable ss_target
	
	if(datafolderexists("root:GrowthCurves")==0)
		newdatafolder root:growthcurves
	endif
	setdatafolder root:growthcurves
	
	variable DpStep = 0.1 // nm

	variable maxSize = 500
	variable nsteps = 200//round((maxSize-DpStart)/DpStep)
	make/o/d/n=(nsteps) DpTot = DpStart + DpStep*1.045^x//DpStep*x
	make/o/d/n=(nsteps) Dpcrit, SScrit
	make/o/d/n=(nsteps) VolFrac1
	make/o/d/n=(nsteps) KappaAve
	variable i
	
	for(i=0;i<nsteps;i+=1)
		VolFrac1[i] = 1-(DpTot[i]^3 - DpStart^3)/DpTot[i]^3
		KappaAve[i] = VolFrac1[i]*Kappa1 + (1-VolFrac1[i])*Kappa2
		DpCrit[i] = KohlerFindCriticalSize(kappaave[i],ss_target)
		KohlerKappa(DpTot[i],KappaAve[i],72)
		wave SS
		wavestats/q SS
		SScrit[i] = V_max
	endfor

end


//***************************************************************
function Coagulation()

	variable i, j
	
	variable kappa_big = 0
	variable Dp_big = 40
	
	variable nsize = 100
	variable nkappa = 103
	make/o/d/n=(nsize) Dp_small
	Dp_small = 10+2*x^1.03
	make/o/d/n=(nsize+1) Dp_small_im
	Dp_small_im = 10+2*x^1.03
	make/o/d/n=(nkappa) Kappa_small
	Kappa_small = 0+x*0.01
	make/o/d/n=(nkappa+1) Kappa_small_im
	Kappa_small_im = 0+x*0.01
	make/o/d/n=(nsize) Dp_coag
	Dp_coag = (Dp_big^(3)+Dp_small^(3))^(1/3)
	
	make/o/d/n=(nsize,nkappa) Kappa_matrix
	make/o/d/n=(nsize,nkappa) Kappa_matrix_small
	
	for(i=0;i<nsize;i+=1)
		for(j=0;j<nkappa;j+=1)
		
			Kappa_matrix[i][j] =(Kappa_small[j]*(Dp_small[i]^3)+Dp_big*Kappa_big^3)/Dp_coag[i]^3
			kappa_matrix_small[i][j] = Kappa_small[j]	
		endfor
	endfor
	
	wave Kappa_matrix
	wave Dp_tot = Dp_coag
	variable nrows = dimsize(kappa_matrix,0)
	variable ncols = dimsize(kappa_matrix,1)
	make/o/d/n=(nrows,ncols) SScrit_matrix, SScrit_matrix_small
	
	for(i=0;i<nrows;i+=1)
		for(j=0;j<ncols;j+=1)
			KohlerKappa(Dp_Tot[i],Kappa_matrix[i][j],72)
			wave SS
			wavestats/q SS
			SScrit_matrix[i][j] = V_max
			
			KohlerKappa(Dp_small[i],Kappa_matrix_small[i][j],72)
			wave SS
			wavestats/q SS
			SScrit_matrix_small[i][j] = V_max
		endfor
	endfor
end

