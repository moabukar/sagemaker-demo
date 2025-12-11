"""
Demo script to run training and deployment from CLI
Run after Terraform apply
"""
import argparse
import boto3
import json
import time
import pandas as pd
import numpy as np
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split

def get_sagemaker_client(region):
    return boto3.client('sagemaker', region_name=region)

def get_s3_client(region):
    return boto3.client('s3', region_name=region)

def generate_dataset():
    """Generate synthetic classification dataset"""
    print("Generating dataset...")
    X, y = make_classification(
        n_samples=1000,
        n_features=20,
        n_informative=15,
        n_redundant=5,
        random_state=42
    )
    
    df = pd.DataFrame(X, columns=[f'feature_{i}' for i in range(20)])
    df['target'] = y
    
    train_df, test_df = train_test_split(df, test_size=0.2, random_state=42)
    
    return train_df, test_df

def upload_data(bucket, prefix, train_df, test_df):
    """Upload data to S3"""
    print(f"Uploading data to s3://{bucket}/{prefix}/...")
    s3 = boto3.client('s3')
    
    # Save locally
    train_df.to_csv('/tmp/train.csv', index=False)
    test_df.to_csv('/tmp/test.csv', index=False)
    
    # Upload
    s3.upload_file('/tmp/train.csv', bucket, f'{prefix}/data/train.csv')
    s3.upload_file('/tmp/test.csv', bucket, f'{prefix}/data/test.csv')
    
    train_uri = f's3://{bucket}/{prefix}/data/train.csv'
    test_uri = f's3://{bucket}/{prefix}/data/test.csv'
    
    print(f"Training data: {train_uri}")
    print(f"Test data: {test_uri}")
    
    return train_uri, test_uri

def create_training_job(sm_client, job_name, role_arn, bucket, train_uri, hyperparameters):
    """Create SageMaker training job"""
    print(f"\nCreating training job: {job_name}")
    
    # Get built-in SKLearn image URI
    region = sm_client.meta.region_name
    account_mapping = {
        'us-east-1': '683313688378',
        'us-east-2': '257758044811',
        'us-west-2': '246618743249',
        'eu-west-1': '685385470294',
        'eu-west-2': '644912444149',
        'eu-central-1': '492215442770',
    }
    account = account_mapping.get(region, '683313688378')
    image_uri = f'{account}.dkr.ecr.{region}.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3'
    
    response = sm_client.create_training_job(
        TrainingJobName=job_name,
        RoleArn=role_arn,
        AlgorithmSpecification={
            'TrainingImage': image_uri,
            'TrainingInputMode': 'File'
        },
        InputDataConfig=[{
            'ChannelName': 'train',
            'DataSource': {
                'S3DataSource': {
                    'S3DataType': 'S3Prefix',
                    'S3Uri': train_uri.rsplit('/', 1)[0],  # Directory containing train.csv
                    'S3DataDistributionType': 'FullyReplicated'
                }
            }
        }],
        OutputDataConfig={
            'S3OutputPath': f's3://{bucket}/output'
        },
        ResourceConfig={
            'InstanceType': 'ml.m5.large',
            'InstanceCount': 1,
            'VolumeSizeInGB': 10
        },
        StoppingCondition={
            'MaxRuntimeInSeconds': 3600
        },
        HyperParameters={
            'sagemaker_program': 'train.py',
            'sagemaker_submit_directory': f's3://{bucket}/scripts',
            **{k: str(v) for k, v in hyperparameters.items()}
        }
    )
    
    print(f"Training job ARN: {response['TrainingJobArn']}")
    return job_name

def wait_for_training_job(sm_client, job_name):
    """Wait for training job to complete"""
    print(f"Waiting for training job {job_name} to complete...")
    
    while True:
        response = sm_client.describe_training_job(TrainingJobName=job_name)
        status = response['TrainingJobStatus']
        
        if status == 'Completed':
            print(f"✓ Training job completed successfully")
            return response['ModelArtifacts']['S3ModelArtifacts']
        elif status == 'Failed':
            raise Exception(f"Training job failed: {response['FailureReason']}")
        elif status == 'Stopped':
            raise Exception("Training job was stopped")
        
        print(f"  Status: {status}...")
        time.sleep(30)

def create_model(sm_client, model_name, role_arn, model_data_url, region):
    """Create SageMaker model"""
    print(f"\nCreating model: {model_name}")
    
    account_mapping = {
        'us-east-1': '683313688378',
        'us-east-2': '257758044811',
        'us-west-2': '246618743249',
        'eu-west-1': '685385470294',
        'eu-west-2': '644912444149',
        'eu-central-1': '492215442770',
    }
    account = account_mapping.get(region, '683313688378')
    image_uri = f'{account}.dkr.ecr.{region}.amazonaws.com/sagemaker-scikit-learn:1.2-1-cpu-py3'
    
    response = sm_client.create_model(
        ModelName=model_name,
        PrimaryContainer={
            'Image': image_uri,
            'ModelDataUrl': model_data_url,
            'Environment': {
                'SAGEMAKER_PROGRAM': 'inference.py',
                'SAGEMAKER_SUBMIT_DIRECTORY': model_data_url  # Same tarball contains both scripts
            }
        },
        ExecutionRoleArn=role_arn
    )
    
    print(f"Model ARN: {response['ModelArn']}")
    return model_name

def create_endpoint_config(sm_client, config_name, model_name):
    """Create endpoint configuration"""
    print(f"\nCreating endpoint config: {config_name}")
    
    response = sm_client.create_endpoint_config(
        EndpointConfigName=config_name,
        ProductionVariants=[{
            'VariantName': 'AllTraffic',
            'ModelName': model_name,
            'InitialInstanceCount': 1,
            'InstanceType': 'ml.m5.large',
            'InitialVariantWeight': 1.0
        }]
    )
    
    print(f"Endpoint config ARN: {response['EndpointConfigArn']}")
    return config_name

def create_endpoint(sm_client, endpoint_name, config_name):
    """Create endpoint"""
    print(f"\nCreating endpoint: {endpoint_name}")
    
    response = sm_client.create_endpoint(
        EndpointName=endpoint_name,
        EndpointConfigName=config_name
    )
    
    print(f"Endpoint ARN: {response['EndpointArn']}")
    return endpoint_name

def wait_for_endpoint(sm_client, endpoint_name):
    """Wait for endpoint to be in service"""
    print(f"Waiting for endpoint {endpoint_name} to be in service...")
    
    while True:
        response = sm_client.describe_endpoint(EndpointName=endpoint_name)
        status = response['EndpointStatus']
        
        if status == 'InService':
            print(f"✓ Endpoint is in service")
            return
        elif status == 'Failed':
            raise Exception(f"Endpoint creation failed: {response.get('FailureReason', 'Unknown')}")
        
        print(f"  Status: {status}...")
        time.sleep(30)

def invoke_endpoint(region, endpoint_name, test_df):
    """Test the endpoint"""
    print(f"\nTesting endpoint...")
    runtime = boto3.client('sagemaker-runtime', region_name=region)
    
    # Get a test sample
    sample = test_df.drop('target', axis=1).iloc[0].values
    payload = ','.join(map(str, sample))
    
    response = runtime.invoke_endpoint(
        EndpointName=endpoint_name,
        ContentType='text/csv',
        Body=payload
    )
    
    result = json.loads(response['Body'].read().decode())
    actual = int(test_df.iloc[0]['target'])
    
    print(f"Prediction: {result}")
    print(f"Actual: {actual}")
    print(f"Match: {result['prediction'] == actual}")
    
    return result

def cleanup(sm_client, endpoint_name, config_name, model_name):
    """Delete created resources"""
    print(f"\n=== Cleanup ===")
    
    try:
        print(f"Deleting endpoint: {endpoint_name}")
        sm_client.delete_endpoint(EndpointName=endpoint_name)
    except Exception as e:
        print(f"  Error: {e}")
    
    try:
        print(f"Deleting endpoint config: {config_name}")
        sm_client.delete_endpoint_config(EndpointConfigName=config_name)
    except Exception as e:
        print(f"  Error: {e}")
    
    try:
        print(f"Deleting model: {model_name}")
        sm_client.delete_model(ModelName=model_name)
    except Exception as e:
        print(f"  Error: {e}")

def main():
    parser = argparse.ArgumentParser(description='SageMaker Demo')
    parser.add_argument('--region', default='eu-west-2', help='AWS region')
    parser.add_argument('--bucket', required=True, help='S3 bucket name')
    parser.add_argument('--role-arn', required=True, help='SageMaker execution role ARN')
    parser.add_argument('--skip-cleanup', action='store_true', help='Skip resource cleanup')
    args = parser.parse_args()
    
    sm_client = get_sagemaker_client(args.region)
    timestamp = int(time.time())
    
    # Generate and upload data
    train_df, test_df = generate_dataset()
    train_uri, test_uri = upload_data(
        args.bucket,
        'demo-classification',
        train_df,
        test_df
    )
    
    # Training job
    job_name = f'demo-training-{timestamp}'
    create_training_job(
        sm_client,
        job_name,
        args.role_arn,
        args.bucket,
        train_uri,
        hyperparameters={
            'n-estimators': 100,
            'max-depth': 5
        }
    )
    
    model_data_url = wait_for_training_job(sm_client, job_name)
    
    # Create model
    model_name = f'demo-model-{timestamp}'
    create_model(sm_client, model_name, args.role_arn, model_data_url, args.region)
    
    # Create endpoint config
    config_name = f'demo-config-{timestamp}'
    create_endpoint_config(sm_client, config_name, model_name)
    
    # Deploy endpoint
    endpoint_name = f'demo-endpoint-{timestamp}'
    create_endpoint(sm_client, endpoint_name, config_name)
    wait_for_endpoint(sm_client, endpoint_name)
    
    # Test endpoint
    invoke_endpoint(args.region, endpoint_name, test_df)
    
    # Cleanup
    if not args.skip_cleanup:
        input("\nPress Enter to cleanup resources...")
        cleanup(sm_client, endpoint_name, config_name, model_name)
    else:
        print(f"\nSkipping cleanup. To manually cleanup:")
        print(f"  aws sagemaker delete-endpoint --endpoint-name {endpoint_name}")
        print(f"  aws sagemaker delete-endpoint-config --endpoint-config-name {config_name}")
        print(f"  aws sagemaker delete-model --model-name {model_name}")

if __name__ == '__main__':
    main()
