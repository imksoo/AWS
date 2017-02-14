def lambda_handler(event, context):
    import datetime
    import boto3

    client = boto3.client('cloudwatch')

    now_time = datetime.datetime.utcnow()
    start_time = now_time - datetime.timedelta(minutes=5)
    end_time = now_time

    for switch_name in ["192.168.1.11", "192.168.1.12", "192.168.1.13"]:
        for port_name in ["port1", "port2", "port3", "port4", "port5", "port6", "port7", "port8", "port9"]:
            try:
                in_metrics = client.get_metric_statistics(
                    Namespace='L2_Switch',
                    MetricName='InOctetsCounter',
                    Period=60,
                    StartTime=start_time,
                    EndTime=end_time,
                    Statistics=['Maximum'],
                    Dimensions=[
                        {
                            'Name': 'IPAddress',
                            'Value': switch_name
                        },
                        {
                            'Name': 'PortName',
                            'Value': port_name
                        }
                    ]
                )
                in_sorted_metrics = sorted(in_metrics['Datapoints'], key=lambda m: m['Timestamp'])
                in_last1 = in_sorted_metrics[-1]
                in_last2 = in_sorted_metrics[-2]

                in_octets = in_last1['Maximum'] - in_last2['Maximum']
                if in_octets < 0:
                    in_octets = 18446744073709551615 - in_octets

                in_throughput = in_octets / (in_last1['Timestamp'] - in_last2['Timestamp']).total_seconds()

                out_metrics = client.get_metric_statistics(
                    Namespace='L2_Switch',
                    MetricName='OutOctetsCounter',
                    Period=60,
                    StartTime=start_time,
                    EndTime=end_time,
                    Statistics=['Maximum'],
                    Dimensions=[
                        {
                            'Name': 'IPAddress',
                            'Value': switch_name
                        },
                        {
                            'Name': 'PortName',
                            'Value': port_name
                        }
                    ]
                )
                out_sorted_metrics = sorted(out_metrics['Datapoints'], key=lambda m: m['Timestamp'])
                out_last1 = out_sorted_metrics[-1]
                out_last2 = out_sorted_metrics[-2]

                out_octets = out_last1['Maximum'] - out_last2['Maximum']
                if out_octets < 0:
                    out_octets = 18446744073709551615 - out_octets

                out_throughput = out_octets / (out_last1['Timestamp'] - out_last2['Timestamp']).total_seconds()

                client.put_metric_data(
                    Namespace='L2_Switch',
                    MetricData=[
                        {
                            'MetricName': 'InThroughput',
                            'Dimensions': [
                                {
                                    'Name': 'IPAddress',
                                    'Value': switch_name
                                },
                                {
                                    'Name': 'PortName',
                                    'Value': port_name
                                }
                            ],
                            'Timestamp': in_last1['Timestamp'],
                            'Value': in_throughput,
                            'Unit': 'Bytes/Second'
                        },
                        {
                            'MetricName': 'OutThroughput',
                            'Dimensions': [
                                {
                                    'Name': 'IPAddress',
                                    'Value': switch_name
                                },
                                {
                                    'Name': 'PortName',
                                    'Value': port_name
                                }
                            ],
                            'Timestamp': out_last1['Timestamp'],
                            'Value': out_throughput,
                            'Unit': 'Bytes/Second'
                        }
                    ]
                )

            except:
                continue
