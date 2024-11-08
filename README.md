## Table of Contents
  <ol>
    <li>
      <a href="#solution-overview">Solution Overview</a>
      <ul>
        <li><a href="#design-principles">Design Principles</a></li>
        <ul>
            <li><a href="#resiliency">Resiliency</a></li>
            <li><a href="#scalability">Scalability</a></li>
            <li><a href="#security">Security</a></li>
        </ul>
        <li><a href="#architecture">Architecture</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
        <li><a href="#implemented-architecture">Implemented Architecture</a></li>
        <li><a href="#usage">Usage</a></li>
      </ul>
    </li>
  </ol>

# Solution Overview

An idempotent, asynchronous solution that maximises performance and scalability at minimal cost; without comprimising on security.

### Assumptions

1. The API request is coming from a client application that received the data from the customers bank via some Open Banking API, and then transformed it into the payload that is sent to the API described in this project.

## Design Principles

The solution embodies the following design principles:

### Resiliency

A robust system is required to prevent the loss of customer data. Given the highly regulated nature of the financal industry, resilience is even more important.

The use of serverless infrastucture shifts much of the responsibility for avaliablity and resilence to AWS. This is generally positive for small business which do not have the capacity to manage vast fleets of servers hosting their applications.

Enforcing idempotency throughout the system makes it predictable and easier to maintain a baseline profile of how it should behave. Choosing an idempotent PUT method for the API endpoint dictates how the system fulfilling the request should be designed. Using the PutItem DynamoDB operation to store records contributes to this.

SQS queues can be used to facilitate the delivery of messages between the API Gateway and Lambda. They also catch messages that can't be processed by Lamdba, pushing them into a SQS Dead-letter queue to be manually or programmatically triaged, in turn preventing the loss of data.

This document does not describe a multi-region architecture, or a disaster recovery plan, however the infrastructure could easily be deployed to run concurrently or in an emergency.

### Scalability

A scalable system should be able to rapidly scale-up and down to handle fluctuations in traffic, as well as stand up to increased regular traffic in the future without the need of a rewrite.

The API Gateway can be integrated with an SQS queue instead of directly to Lambda function, meaning requests can be fulfilled asynchronously. The use of a SQS queue also enables requests to be handled more efficiently. Messages are processed in batches, each batch being concurrently proccessed by a Lambda function. The number of Lambda functions scales based on the number of batches available.

Another area in which scaling is important is when writing to DynamoDB. It is cost effective to provision a certain number of WCUs for a table based on how many writes are expected a second. This can be difficult to predict as there will be spikes at different times of the day. This is where Application Auto Scaling comes in can be used. It allows DynamoDB to scale its provisioned WCUs up or down based on how much it is currently being utilised.

### Security

In a high compliance environment, it is vital that security is thought about throughout the design process, and that it is implemented in multiple ways; a defense-in-depth strategy.

Authorization should occur at the front door (in this case the API Gateway). This ensures no resources are wasted fulfilling a request that ultimately would be rejected. Using authorization controls who has access to the API and who can introduce new data into the system. Request validation should also occur in the API Gateway, which will enforce the structure and thus quality of system data.

To protect the system from common web exploits such as XSS or SQL injection, the API Gateway should be integrated with Amazon WAF. This, authorization, and API throttling limits, occupy the frontline in the defense-in-depth strategy.

All services should be encrypted at rest and in transit.

Lastly, all AWS services should only be granted the minimum amount of permissions needed to fulfil its purpose - the principle of least privilage.

## Architecture

The following section describes the architecture of the solution and how the body of an API request ends up in DynamoDB.

![Target architecture of the Payment API](/media/async-payment-api-target.drawio.png)

### 1. Client Application

A user signs in to their account. The application authenticates the user by calling Amazon Cognito with their account credentials. This returns a JWT with their authorization claims.

The user then proceeds to submit a payment. The application makes a PUT request to the /submit endpoint of the payment API with their payment details and the Authorization header set to the JWT bearer token.

### 2. Amazon Cognito

Amazon Cognito receives an authentication request. It then finds an identity in the User Pool with matching credentials and returns a JWT token containing the identities authorization claims.

A Cognito User Pool receives a request from the API Gateway to validate a JWT token. It validates the JWT and allows it.

### 3. API Gateway - payment

The API Gateway receives a PUT request to the /submit endpoint of the payment API. The request's Authorization token is validated using the identity provider that the token was issued by, in this case Cognito.

Given a successful authorization, it then proceeds to validate the parameters and request body defined in its' OA schema.

After the request has been validated, a integration mapping template is used to transform and send it to a SQS Queue. Once the SQS queue confirms it has received the message with a 200 code, the API Gateway returns a 200 response to the client.

> The integration with SQS decouples the API Gateway from the processing of the request. This asychronous behaviour allows for supreme roundtrip performance and scalability, however a secondary endpoint will be needed if the user requires feedback on the progress of their submission.

> To protect the system from common web exploits such as XSS or SQL injection, the API Gateway is integrated with Amazon WAF. This, authorization, and API throttling limits, provide the frontline in the defense-in-depth strategy employed by this system.

> All requests made to the API Gateway generate logs that are stored in CloudWatch.

### 4. SQS Standard Queue - submit-payment-queue

The submit-payment-queue receives the message from the /submit API integration and responds with a 200 and the message details. The message body is a json string of the API requests' body. The message remains in the queue for 20 seconds before being processed with other messages in a batch by a Lambda function.

> SQS standard queues do not guarentee that messages are not duplicated! It is important to make sure that duplicate payments do not end up in DynamoDB. This can be countered by enforcing idempotency in the Lambda function when it writes to DynamoDB.

> Messages that have been received more than 3 times (failed processing and made visible again) are sent to the dead letter queue. This queue retains messages for a long period of time, awaiting intervention.

### 5. Lambda - submit-payments

The submit-payments Lambda function is invoked with an event that contains a batch of messages to be processed. The Lambda function interatively writes the message body of each record into the PaymentsTable using the PutItem command.

If a write operation fails for a message, it remains in the queue to be processed again, while the successful messages are removed from the queue.

### 6. DynamoDB - PaymentsTable

The message is stored in the table as a document, with each json property being used as an attribute. DynamoDB only required properties are the primary and sort key. The request body was already validated by the API Gateway, and isn't modified anywhere along the way.

The PaymentsTable uses a composite key, of paymentId + userId. The paymentId is unqiue, so it is perfect for use as a hash key, whereas userId is great to use as a sort key as it will often be used to group items in queries.

The table uses application auto scaling to ensure that there is enough write provision avaliable at in times of high traffic. This is also necessary to support many concurrent Lambda functions writing to the table at the same time.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Getting Started

### Prerequisites

Aside from Node.js, you'll need to install the following tools to deploy this solution.

- [Install terraform](https://developer.hashicorp.com/terraform/install)
- [Install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions) and [set up](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html) the AWS CLI

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/github_username/repo_name.git
   ```
2. Install npm packages
   ```sh
   npm install
   ```
3. Run the npm script to transcribe the TypeScript source code to JavaScript (using esbuild).
   ```sh
   npm run build
   ```
4. Change into the `infra` directory
   ```sh
   cd infra
   ```
5. Initialise the Terraform backend
   ```sh
   terraform init
   ```
6. Deploy the Terraform infrastructure.
   ```sh
   terraform apply
   ```
7. Take note of the two variables terraform output: `api_url` & `api_key`.

### Implemented Architecture

The architectural diagram below illustrates the infrastructure that is described by these terraform templates.

![Implemented architecture of the Payment API](/media/async-payment-api.drawio.png)

As you can see, only a subset of the full design has been implemented due to time constraints. Nonetheless, it is still a fully functional e2e system, minus the authentication. See below for guidance on usage.

## Usage

You can test the API from the OpenApi schema, `payment-api-schema.yaml`, using the VSCode extension: [Swagger Viewer](https://marketplace.visualstudio.com/items?itemName=Arjun.swagger-viewer).

Replace the URL in the `servers` block with the one terraform output (`api_url`). You'll need the `api_key` to authenticate.

```yml
servers:
  - url: "https://example.com"
```

Terraform uses this schema to generate API resources, so beware of making changes!

### AWS SAM CLI + Terraform
I did plan on trying to locally test the terraform templates with the AWS SAM CLI as described [here](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-terraform-support.html), but I ran out of time. 

<p align="right">(<a href="#readme-top">back to top</a>)</p>
