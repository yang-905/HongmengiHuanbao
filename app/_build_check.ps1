$env:JAVA_HOME = 'D:\anzhi\DevEco Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Set-Location 'C:\Users\111\Desktop\carbon-master\app'
node 'D:\anzhi\DevEco Studio\tools\hvigor\bin\hvigorw.js' assembleHap --no-daemon 2>&1 | Select-Object -Last 25
