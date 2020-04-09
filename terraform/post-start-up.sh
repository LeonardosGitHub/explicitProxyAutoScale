#/bin/bash

LOG_FILE=/config/cloud/startup-script.log
MAX_COUNT=80

COUNT=1
until [ -f $LOG_FILE ]; do
    if [ $COUNT -eq $MAX_COUNT ]
    then
     echo "Unable to find file, exiting script"
     exit
    else
     echo "$LOG_FILE not found, current count: $COUNT, sleeping 5 seconds"
     sleep 5
     ((COUNT=COUNT+1))
    fi
done
echo "$LOG_FILE found, continuing..."

COUNT=1
while [ $COUNT -lt $MAX_COUNT ]; do
 if grep -q '!!!!! FINISHED' $LOG_FILE
 then
  while read -r line; do
   logger -t "STARTUP_SCRIPT" $line
   sleep 0.15
   echo "Writing line to syslog: $line"
  done < $LOG_FILE
  break
 else
  echo "!!!!! FINISHED not found in file, current count: $COUNT, sleeping 15 seconds"
  ((COUNT=COUNT+1))
  sleep 15
 fi
done

echo '!!!!!! Completed sending startup script to syslog which sends it to CloudWatch'


