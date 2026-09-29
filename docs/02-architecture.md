# AWS Infrastructure Architecture

## Overview

This document describes the planned AWS network architecture for the
AWS DevOps Infrastructure Lab.

The infrastructure will be deployed in:

- AWS Region: US East (Ohio)
- Region code: us-east-2

The project originally considered us-east-1, but us-east-2 was selected
because of the region availability restrictions of the AWS Free Plan
account used for this lab.

## Network Architecture

The environment will use a dedicated VPC with the following CIDR block:

| Resource | CIDR |
|---|---|
| VPC | 10.20.0.0/16 |
| Public Subnet A | 10.20.1.0/24 |
| Public Subnet B | 10.20.2.0/24 |
| Private Subnet A | 10.20.11.0/24 |
| Private Subnet B | 10.20.12.0/24 |

The subnets will be distributed across two Availability Zones.

## Public Layer

The public subnets will have a route to an Internet Gateway.

The initial application server (EC2) will be deployed in Public Subnet A.

During the initial phase, the EC2 instance may use a public IPv4 address
for controlled administrative and application access.

SSH access will only be used temporarily. AWS Systems Manager Session
Manager will later become the preferred administration method.

## Private Layer

The private subnets will not have direct inbound access from the Internet.

Amazon RDS for PostgreSQL will use a DB subnet group containing:

- Private Subnet A
- Private Subnet B

The database will have public access disabled.

PostgreSQL port 5432 will only accept traffic from the application
security group.

## Internet Connectivity

An Internet Gateway will provide Internet connectivity to the public
subnets.

A NAT Gateway will NOT be deployed during the initial architecture
because it can introduce additional costs.

Private resources will therefore remain isolated unless outbound
connectivity is explicitly added later.

## Planned Compute and Database

### EC2

Initial candidate:

- Instance type: t3.micro
- Operating system: Debian, if eligible
- Location: Public Subnet A
- Administration: SSH initially, then AWS Systems Manager

The final instance configuration will be confirmed in the AWS Console
before deployment.

### RDS

Initial candidate:

- Engine: PostgreSQL
- Instance class: db.t4g.micro
- Deployment: Single-AZ
- Public access: No
- Network: Private Subnet A + Private Subnet B

The final database configuration will also be confirmed before deployment.

## Security Model

Network access will be controlled using Security Groups.

Planned security groups:

- App Security Group
- Database Security Group

The database security group will allow PostgreSQL traffic on TCP port
5432 only from the App Security Group.

Administrative access will follow the principle of least privilege.

## High-Level Traffic Flow

Internet
    |
Internet Gateway
    |
Public Subnet A
    |
EC2 Application Server
    |
    | TCP 5432
    |
Private Subnets
    |
Amazon RDS PostgreSQL

## Cost Strategy

The architecture is designed to minimize unnecessary AWS costs.

The initial environment will:

- Avoid NAT Gateway
- Use Free Plan eligible resources when available
- Keep RDS private
- Use a single EC2 instance initially
- Use Single-AZ RDS
- Validate service eligibility before resource creation
- Destroy resources when they are no longer required

## Current Status

Architecture planned and documented.

No VPC, subnet, EC2 instance, or RDS database has been created yet.
