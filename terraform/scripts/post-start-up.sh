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
  echo "!!!!!! Modifying and sending log file, $LOG_FILE, to Telemetry streaming which will then send to Cloudwatch"
  echo ""
  awk '{print NR "startup_script=\""$0"\","}' $LOG_FILE | nc 127.0.0.1 6514
  break
 else
  echo "!!!!! FINISHED not found in file, current count: $COUNT, sleeping 15 seconds"
  ((COUNT=COUNT+1))
  sleep 15
 fi
done

echo '!!!!!! Completed sending startup script to syslog which sends it to CloudWatch'
