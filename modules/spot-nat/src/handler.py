import logging
import boto3
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2_client = boto3.client("ec2")
asg_client = boto3.client('autoscaling')

def route_to_nat_gateway(route_table_ids, nat_gateway_id):
    for table_id in route_table_ids:
        new_route_table = {
            "DestinationCidrBlock": "0.0.0.0/0",
            "NatGatewayId": nat_gateway_id,
            "RouteTableId": table_id
        }
        logger.info("Replacing existing route %s for route table %s", table_id, new_route_table)
        ec2_client.replace_route(**new_route_table)

def route_to_nat_instance(route_table_ids, instance_id):
    for table_id in route_table_ids:
        new_route_table = {
            "DestinationCidrBlock": "0.0.0.0/0",
            "InstanceId": instance_id,
            "RouteTableId": table_id
        }
        logger.info("Replacing existing route %s for route table %s", table_id, new_route_table)
        ec2_client.replace_route(**new_route_table)

def route_tables_associated_with(instance_id):
    filters = [
        {
            'Name': 'route.instance-id',
            'Values': [instance_id]
        }
    ]
    route_tables = ec2_client.describe_route_tables(Filters=filters)['RouteTables']
    table_ids = []
    for table in route_tables:
        table_ids.append(table['RouteTableId'])
    return table_ids

def detach_instance(instance_id, asg_name):
    asg_client.detach_instances(
        InstanceIds=[
            instance_id,
        ],
        AutoScalingGroupName=asg_name,
        ShouldDecrementDesiredCapacity=False
    )
    
def find_tag(key, tags):
    for tag in tags:
        if tag["Key"] == key:
            return tag["Value"]
    raise Exception("Can not find any tag of " + key)   

def table_ids_from_tags(tags):
    return json.loads(find_tag("yacc:nat:instance:route:tables", tags))

def public_ip_from_tags(tags):
    return find_tag("yacc:nat:instance:route:eip", tags)

def nat_gw_from_tags(tags):
    return find_tag("yacc:nat:instance:route:nat:gw", tags)

def asg_name_from_tags(tags):
    return find_tag("yacc:nat:instance:asg:name", tags)

def is_nat_instance(tags):
    for tag in tags:
        if tag["Key"] == "yacc:nat:instance" and 'owned' in tag["Value"]:
            return True
    return False

def associate_eip(public_ip, instance_id):
    ec2_client.associate_address(
        InstanceId=instance_id,
        PublicIp=public_ip
    )

def instance_tags(instance_id):
    return ec2_client.describe_instances(InstanceIds=[instance_id])["Reservations"][0]["Instances"][0]["Tags"]

def is_spot_termination(event):
    return "instance-action" in event["detail"]

def fallback_to_nat_gateway(instance_id, tags):
    route_table_ids = route_tables_associated_with(instance_id)
    nat_gateway_id = nat_gw_from_tags(tags)
    route_to_nat_gateway(route_table_ids, nat_gateway_id)

def lambda_handler(event, context):
    instance_id = event["detail"]["instance-id"]
    tags = instance_tags(instance_id)

    if not is_nat_instance(tags):
        logger.info('Instance not a NAT instance:  Skipping')
        return {'statusCode' : 204, 'body' : 'Instance not a NAT instance, or state is pending :  Skipping'}
    
    if is_spot_termination(event):
        logger.info('Received spot termination :  Updating NAT configuration')
        fallback_to_nat_gateway(instance_id, tags)
        asg_name = asg_name_from_tags(tags)
        detach_instance(instance_id, asg_name) 
        return {'statusCode' : 200, 'body' : 'NAT configuration updated'}
    
    state = event["detail"]["state"]
    if state in ["stopping", "stopped", "shutting-down", "terminated"]:
        logger.info('Instance is shutting down :  Updating NAT configuration')
        fallback_to_nat_gateway(instance_id, tags)
    elif state in ["running"]:
        logger.info('Instance is in running status :  Updating NAT configuration')
        route_table_ids = table_ids_from_tags(tags)
        public_ip = public_ip_from_tags(tags)
        associate_eip(public_ip, instance_id)
        route_to_nat_instance(route_table_ids, instance_id)
    else:
        logger.info('Instance is status is ' + state + ' :  No configuration update made')
    return {'statusCode' : 200, 'body' : 'NAT event complete'}
