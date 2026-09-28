sc config NetSetupSvc start= demand
sc config Netman start= demand
sc config netprofm start= demand
sc config NlaSvc start= auto
sc config NcbService start= demand
sc start Netman
sc start netprofm
sc start NlaSvc
sc start NetSetupSvc
sc start NcbService
sc config Wcmsvc start= auto
sc start Wcmsvc
sc config WlanSvc start= auto
sc start WlanSvc
sc config NativeWifiP start= demand
sc start NativeWifiP