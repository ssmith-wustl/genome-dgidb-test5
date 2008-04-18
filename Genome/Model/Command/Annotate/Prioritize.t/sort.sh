#!/gsc/bin/bash
input=$1
echo $input

awk '{FS=",";if($8==0 && $9>0 ) print}' $input | sort -t',' -nrk 7,7 -k 9,9|awk '{FS=",";if($7>=4 && $9>=10 && !($23==1 && $9==0 && $16>0) && !($23==0 && $9==0 && $16==0)) {print  > "old_prioritize.1";} else {print  > "old_prioritize.2";} }'  
