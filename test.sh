#!/bin/bash
# About: This script lists the Triggers which are frequently generating the alert. This script will execut every hour on the replicating node.
# Author: Mohammed Zuber [MZN9]
###################################################

# Define variables
OUTPUT_FILE="/tmp/List_of_Busy_Triggers_count_is_more_than_120_for_last_one_hour.csv"
EMAIL_SUBJECT="List of Busy Triggers, count is more than 120 for last one hour"
THRESHOLD=0

#Check if the current node is Master or not. Query will run on the Replica node.
Replica=$(/usr/local/bin/patronictl -c /etc/patroni/patroni.yml list | grep -i "replica" | awk -F"| " '{print $2}')
Hostname=`hostname`

if [ $Replica == $Hostname ];then

# Execute SQL query and save the result in a file
psql -U "postgres" -d zabbix -c "
COPY (
SELECT
    e.objectid AS triggerid,
    t.description,
    h.name AS hostname,
    h_inv.contact,
    COUNT(DISTINCT e.eventid) AS event_count
FROM
    events e
JOIN
    functions f ON e.objectid = f.triggerid
JOIN
    items i ON f.itemid = i.itemid
JOIN
    hosts h ON i.hostid = h.hostid
JOIN
    triggers t ON e.objectid = t.triggerid
LEFT JOIN
    host_inventory h_inv ON h.hostid = h_inv.hostid
WHERE
    e.source = 0
    AND e.object = 0
    AND e.clock >= EXTRACT(EPOCH FROM (NOW() - INTERVAL '1 hour'))
GROUP BY
    e.objectid, t.description, h.name, h_inv.contact
HAVING
    COUNT(DISTINCT e.eventid) > $THRESHOLD
ORDER BY
    event_count DESC
) TO STDOUT WITH CSV HEADER
" > "$OUTPUT_FILE"

# Check if the output file is not empty and if it is not empty then send mail.
 if [ -s "$OUTPUT_FILE" ] &&  [ $(wc -l < "$OUTPUT_FILE") -gt 1 ]; then
    # Send email with attachment
echo -n "Hi All,

Please find the Report from Replica host `hostname`. List of Triggers which are frequently throwing alert along with hostname for your reference.

Best Regards,
IT Monitoring Apps

" | mail -s "$EMAIL_SUBJECT" -a "$OUTPUT_FILE" -S "From=IT Monitoring Apps <noreply@monitoring.3ds.com>" "mzn9@3ds.com"

fi

fi
