import flopy
import numpy as np
import flopy.utils.binaryfile as bf
import pandas as pd

#this function is retained fro backward compatibility. use get_lst_incr_cum_py instead to get both cumulative and incremental
def get_lst_py(file):
  try:
    mf_list = flopy.utils.Mf6ListBudget(file)
    kstpkper = mf_list.get_kstpkper()
    if not kstpkper:
        raise ValueError("No data found as MF6 format")
  except Exception:
    mf_list = flopy.utils.MfListBudget(file)
    kstpkper = mf_list.get_kstpkper()
  
  kstpkper_df = pd.DataFrame(kstpkper)
  kstpkper_df.columns = ['kstp','kper']
  
  times = mf_list.get_times()
  times_df = pd.DataFrame(times)
  times_df.columns = ['totim']
 
  
  incrementaldf, cumulativedf = mf_list.get_dataframes()
  incrementaldf.reset_index(level=0, inplace=True)
  incrementaldf = pd.concat([kstpkper_df,times_df,incrementaldf],axis=1)
  incrementaldf.rename(columns={'index':'time'}, inplace=True)

  return(incrementaldf)
  
def get_lst_incr_cum_py(file):
  try:
    mf_list = flopy.utils.Mf6ListBudget(file)
    kstpkper = mf_list.get_kstpkper()
    if not kstpkper:
        raise ValueError("No data found as MF6 format")
  except Exception:
    mf_list = flopy.utils.MfListBudget(file)
    kstpkper = mf_list.get_kstpkper()
  
  kstpkper_df = pd.DataFrame(kstpkper)
  kstpkper_df.columns = ['kstp','kper']
  
  times = mf_list.get_times()
  times_df = pd.DataFrame(times)
  times_df.columns = ['totim']
 
  
  incrementaldf, cumulativedf = mf_list.get_dataframes()
  incrementaldf.reset_index(level=0, inplace=True)
  incrementaldf = pd.concat([kstpkper_df,times_df,incrementaldf],axis=1)
  incrementaldf.rename(columns={'index':'time'}, inplace=True)
  incrementaldf["type_incr_cum"] = "incr"
    
  cumulativedf.reset_index(level=0, inplace=True)
  cumulativedf = pd.concat([kstpkper_df,times_df,cumulativedf],axis=1)
  cumulativedf.rename(columns={'index':'time'}, inplace=True)
  cumulativedf["type_incr_cum"] = "cum"
    
  combineddf = pd.concat([incrementaldf,cumulativedf], ignore_index=True)

  return(combineddf)
  
def get_head(file,header = "HEADU"):
  hdobj = bf.HeadUFile(file,text = header)
  usgheads = hdobj.get_alldata()
  return(usgheads)
  
def get_head_times(file,header = "headu"):
  hdobj = bf.HeadUFile(file,text = header)
  kstpkper = hdobj.get_kstpkper()
  times = hdobj.get_times() 
  steps = hdobj.get_kstpkper()
  steps1 = np.array(steps)
  times = hdobj.get_times()
  times1 = np.array(times)
  combined = np.vstack((times1,steps1[:,0],steps1[:,1]))
  combined = np.transpose(combined)
  return(combined)
  
def get_con_str(file):
  ucnobj= bf.UcnFile(file)
  ucndata = ucnobj.get_alldata()
  return(ucndata)
  
def get_ucn_str_times(file):
  ucnobj = bf.UcnFile(file)
  kstpkper = ucnobj.get_kstpkper()
  times = ucnobj.get_times() 
  steps = ucnobj.get_kstpkper()
  steps1 = np.array(steps)
  times = ucnobj.get_times()
  times1 = np.array(times)
  combined = np.vstack((times1,steps1[:,0],steps1[:,1]))
  combined = np.transpose(combined)
  return(combined)
