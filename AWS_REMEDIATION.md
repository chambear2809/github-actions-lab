# AWS Remediation Notes

## Current Read-Only Findings

The Smart Agent lab resources were observed in `us-east-1` under
`vpc-02ce435bce6cf9069`.

Notable drift from the documented private-only design:

- Several Smart Agent Linux targets have public IPv4 addresses.
- The `smartagent-demo` security group includes inbound `443` from
  `0.0.0.0/0`.
- Linux Smart Agent targets also have the
  `Cisco_Known_Address_Ranges_3389` security group attached, which is RDP
  oriented and not needed for Linux SSH deployment.
- The VPC route table has an internet gateway route. That is compatible with
  public subnets, but targets do not need public reachability for this workflow.

The two observed EKS clusters are unrelated to this repository's Smart Agent
GitHub Actions workflow and should be handled separately.

## Recommended Sequence

1. Confirm the self-hosted runner can reach all target private IPs and GitHub
   over HTTPS without using target public IPs.
2. Create a dedicated runner security group and target security group:
   - runner egress: HTTPS to GitHub/AppDynamics as required, SSH to target SG.
   - target ingress: SSH only from runner SG.
   - target egress: AppDynamics controller endpoints and package/update
     repositories as required.
3. Remove public IPv4 assignment from target instances after confirming private
   SSH works.
4. Remove `443` from `0.0.0.0/0` on `smartagent-demo` unless a documented
   inbound service requires it.
5. Detach `Cisco_Known_Address_Ranges_3389` from Linux Smart Agent targets.
6. Prefer Session Manager or a bastion for admin access instead of direct public
   SSH/RDP rules.

## Verification Commands

Run these read-only checks after any AWS changes:

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --filters Name=vpc-id,Values=vpc-02ce435bce6cf9069 \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,SecurityGroups:SecurityGroups[].GroupName}' \
  --output table

aws ec2 describe-security-groups \
  --region us-east-1 \
  --group-names smartagent-demo \
  --query 'SecurityGroups[0].IpPermissions[].{Protocol:IpProtocol,From:FromPort,To:ToPort,Cidrs:IpRanges[].CidrIp,SourceGroups:UserIdGroupPairs[].GroupId,PrefixLists:PrefixListIds[].PrefixListId}' \
  --output table
```

Do not apply destructive network changes while a deployment run is active.
