#!/bin/bash
# ifName
# .1.3.6.1.2.1.31.1.1.1.1
# ifHCInOctets
# .1.3.6.1.2.1.31.1.1.1.6
# ifHCOutOctets
# .1.3.6.1.2.1.31.1.1.1.10
# ifHighSpeed
# .1.3.6.1.2.1.31.1.1.1.15

COMMUNITY_NAME="BERRYZNET"
IPADDR_LIST="192.168.1.11 192.168.1.12 192.168.1.13"

for IPADDR in ${IPADDR_LIST} ; do
  OID_IF_NAME=".1.3.6.1.2.1.31.1.1.1.1"
  OID_IF_HC_IN_OCTETS=".1.3.6.1.2.1.31.1.1.1.6"
  OID_IF_HC_OUT_OCTETS=".1.3.6.1.2.1.31.1.1.1.10"
  OID_IF_HIGH_SPEED=".1.3.6.1.2.1.31.1.1.1.15"

  IF_NAME_LIST=$(snmpbulkwalk -v2c -c${COMMUNITY_NAME} ${IPADDR} ${OID_IF_NAME} -Oqv)
  IN_OCTETS_LIST=$(snmpbulkwalk -v2c -c${COMMUNITY_NAME} ${IPADDR} ${OID_IF_HC_IN_OCTETS} -Oqv)
  OUT_OCTETS_LIST=$(snmpbulkwalk -v2c -c${COMMUNITY_NAME} ${IPADDR} ${OID_IF_HC_OUT_OCTETS} -Oqv)
  IF_SPEED_LIST=$(snmpbulkwalk -v2c -c${COMMUNITY_NAME} ${IPADDR} ${OID_IF_HIGH_SPEED} -Oqv)

  # Put ifHCInOctets
  echo "" > put-switch-metrics-raw.json
  paste <(echo "${IF_NAME_LIST}") <(echo "${IN_OCTETS_LIST}") | while read LINE
  do
    IF_NAME=$(echo ${LINE} | awk '{print $1}')
    IF_IN_OCTET=$(echo ${LINE} | awk '{print $2}')
    cat << EOS >> put-switch-metrics-raw.json
      {
        "MetricName": "InOctetsCounter",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": ${IF_NAME}
          }
        ],
        "Value": ${IF_IN_OCTET},
        "Unit": "Bytes"
      }
EOS
  done
  cat put-switch-metrics-raw.json | jq -s "." > put-switch-metrics.json
  aws cloudwatch put-metric-data --namespace "L2_Switch" --metric-data file://put-switch-metrics.json

  # Put ifHCOutOctets
  echo "" > put-switch-metrics-raw.json
  paste <(echo "${IF_NAME_LIST}") <(echo "${OUT_OCTETS_LIST}") | while read LINE
  do
    IF_NAME=$(echo ${LINE} | awk '{print $1}')
    IF_OUT_OCTET=$(echo ${LINE} | awk '{print $2}')
    cat << EOS >> put-switch-metrics-raw.json
      {
        "MetricName": "OutOctetsCounter",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": ${IF_NAME}
          }
        ],
        "Value": ${IF_OUT_OCTET},
        "Unit": "Bytes"
      }
EOS
  done
  cat put-switch-metrics-raw.json | jq -s "." > put-switch-metrics.json
  aws cloudwatch put-metric-data --namespace "L2_Switch" --metric-data file://put-switch-metrics.json

  # Put ifHighSpeed
  echo "" > put-switch-metrics-raw.json
  paste <(echo "${IF_NAME_LIST}") <(echo "${IF_SPEED_LIST}") | while read LINE
  do
    IF_NAME=$(echo ${LINE} | awk '{print $1}')
    IF_SPEED=$(echo ${LINE} | awk '{print $2}')
    cat << EOS >> put-switch-metrics-raw.json
      {
        "MetricName": "LinkSpeed",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": ${IF_NAME}
          }
        ],
        "Value": ${IF_SPEED},
        "Unit": "Megabits"
      }
EOS
  done
  cat put-switch-metrics-raw.json | jq -s "." > put-switch-metrics.json
  aws cloudwatch put-metric-data --namespace "L2_Switch" --metric-data file://put-switch-metrics.json

  # Put interface input throughput
  echo "" > put-switch-metrics-raw.json
  echo "${IF_NAME_LIST}" | while read LINE
  do
    IF_NAME=$(echo ${LINE} | awk '{print $1}')
    IF_IN_TROUGHPUT=$(
        aws cloudwatch get-metric-statistics \
            --namespace "L2_Switch" \
            --metric-name "InOctetsCounter" \
            --dimensions Name=IPAddress,Value=${IPADDR} Name=PortName,Value=${IF_NAME} \
            --start-time $(date --iso-8601=seconds -d '15 minutes ago') \
            --end-time $(date --iso-8601=seconds) \
            --period 300 --statistics Maximum \
        | jq '.Datapoints | sort_by(.Timestamp)[-2:]' \
        | jq '( if 0 <=(.[1].Maximum - .[0].Maximum) then (.[1].Maximum - .[0].Maximum) else (18446744073709551615 - .[1].Maximum + .[0].Maximum) end ) / 300'
    )
    cat << EOS >> put-switch-metrics-raw.json
      {
        "MetricName": "InThroughput",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": ${IF_NAME}
          }
        ],
        "Value": ${IF_IN_TROUGHPUT},
        "Unit": "Bytes/Second"
      }
EOS
  done
  cat put-switch-metrics-raw.json | jq -s "." > put-switch-metrics.json
  aws cloudwatch put-metric-data --namespace "L2_Switch" --metric-data file://put-switch-metrics.json

  # Put interface output throughput
  echo "" > put-switch-metrics-raw.json
  echo "${IF_NAME_LIST}" | while read LINE
  do
    IF_NAME=$(echo ${LINE} | awk '{print $1}')
    IF_OUT_TROUGHPUT=$(
        aws cloudwatch get-metric-statistics \
            --namespace "L2_Switch" \
            --metric-name "OutOctetsCounter" \
            --dimensions Name=IPAddress,Value=${IPADDR} Name=PortName,Value=${IF_NAME} \
            --start-time $(date --iso-8601=seconds -d '15 minutes ago') \
            --end-time $(date --iso-8601=seconds) \
            --period 300 --statistics Maximum \
        | jq '.Datapoints | sort_by(.Timestamp)[-2:]' \
        | jq '( if 0 <= (.[1].Maximum - .[0].Maximum) then (.[1].Maximum - .[0].Maximum) else (18446744073709551615 - .[1].Maximum + .[0].Maximum) end ) / 300'
    )
    cat << EOS >> put-switch-metrics-raw.json
      {
        "MetricName": "OutThroughput",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": ${IF_NAME}
          }
        ],
        "Value": ${IF_OUT_TROUGHPUT},
        "Unit": "Bytes/Second"
      }
EOS
  done
  cat put-switch-metrics-raw.json | jq -s "." > put-switch-metrics.json
  aws cloudwatch put-metric-data --namespace "L2_Switch" --metric-data file://put-switch-metrics.json

done

rm put-switch-metrics-raw.json
rm put-switch-metrics.json