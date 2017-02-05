#!/bin/bash

# ifName
# .1.3.6.1.2.1.31.1.1.1.1
# ifHCInOctets
# .1.3.6.1.2.1.31.1.1.1.6
# ifHCOutOctets
# .1.3.6.1.2.1.31.1.1.1.10
# ifHighSpeed
# .1.3.6.1.2.1.31.1.1.1.15
put_interface_metrics() {
  TMP_FILE=$(mktemp -p /dev/shm)

  IF_NAME=$(echo $1 | sed -e 's/"//g')
  IF_IN_OCTET=$2
  IF_OUT_OCTET=$3
  IF_SPEED=$4

  cat << EOS > ${TMP_FILE}
    [
      {
        "MetricName": "InOctetsCounter",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": "${IF_NAME}"
          }
        ],
        "Value": ${IF_IN_OCTET},
        "Unit": "Bytes"
      },
      {
        "MetricName": "OutOctetsCounter",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": "${IF_NAME}"
          }
        ],
        "Value": ${IF_OUT_OCTET},
        "Unit": "Bytes"
      },
      {
        "MetricName": "LinkSpeed",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": "${IF_NAME}"
          }
        ],
        "Value": ${IF_SPEED},
        "Unit": "Megabits"
      }
    ]
EOS
  aws cloudwatch put-metric-data --namespace "L2_Switch" --metric-data file://${TMP_FILE}
  rm ${TMP_FILE}
}

put_interface_statistics() {
  TMP_FILE=$(mktemp -p /dev/shm)

  IPADDR=$1
  IF_NAME=$(echo $2 | sed -e 's/"//g')

  IF_IN_THROUGHPUT=$(
      aws cloudwatch get-metric-statistics \
          --namespace "L2_Switch" \
          --metric-name "InOctetsCounter" \
          --dimensions Name=IPAddress,Value=${IPADDR} Name=PortName,Value=${IF_NAME} \
          --start-time $(date --iso-8601=seconds -d '15 minutes ago') \
          --end-time $(date --iso-8601=seconds) \
          --period 300 --statistics Maximum \
      | jq '.Datapoints | sort_by(.Timestamp)[-2:]' \
      | jq '( if 0 <= (.[1].Maximum - .[0].Maximum) then (.[1].Maximum - .[0].Maximum) else (18446744073709551615 - .[1].Maximum + .[0].Maximum) end ) / 300'
  )
  IF_OUT_THROUGHPUT=$(
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
  if [ "x${IF_IN_THROUGHPUT}" = "x" ] ; then
    IF_IN_THROUGHPUT=0
  fi
  if [ "x${IF_OUT_THROUGHPUT}" = "x" ] ; then
    IF_OUT_THROUGHPUT=0
  fi
  cat << EOS > ${TMP_FILE}
    [
      {
        "MetricName": "InThroughput",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": "${IF_NAME}"
          }
        ],
        "Value": ${IF_IN_THROUGHPUT},
        "Unit": "Bytes/Second"
      },
      {
        "MetricName": "OutThroughput",
        "Dimensions": [
          {
            "Name": "IPAddress",
            "Value": "${IPADDR}"
          },
          {
            "Name": "PortName",
            "Value": "${IF_NAME}"
          }
        ],
        "Value": ${IF_OUT_THROUGHPUT},
        "Unit": "Bytes/Second"
      }
    ]
EOS
  aws cloudwatch put-metric-data --namespace "L2_Switch" --metric-data file://${TMP_FILE}
  rm ${TMP_FILE}
}

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

  paste <(echo "${IF_NAME_LIST}") <(echo "${IN_OCTETS_LIST}") <(echo "${OUT_OCTETS_LIST}") <(echo "${IF_SPEED_LIST}") | while read LINE
  do
    put_interface_metrics ${LINE} &
  done
  wait
done

for IPADDR in ${IPADDR_LIST} ; do
  OID_IF_NAME=".1.3.6.1.2.1.31.1.1.1.1"

  IF_NAME_LIST=$(snmpbulkwalk -v2c -c${COMMUNITY_NAME} ${IPADDR} ${OID_IF_NAME} -Oqv)

  paste <(echo "${IF_NAME_LIST}") | while read LINE
  do
    put_interface_statistics ${IPADDR} ${LINE} &
  done
  wait
done
