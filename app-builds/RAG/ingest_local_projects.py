import boto3
import os
import sys

# S3 Credentials and Configuration
# We use the ClusterIP of the RGW service since we are running on hierophant
S3_ENDPOINT = "http://10.97.122.168"
ACCESS_KEY = "RDAwRTVHQkk3QUU3QlE2VDJaSDk=" # Decoded: 800E5GBI7AE7BQ6T2ZH9
SECRET_KEY = "MDBDYlh3eFV5WURiWWRzdDIxZGs4T2JoU3g3Sk1rV0U3ZlduMEE4Ng==" # Decoded: 00CbXwxUyYDbYdst21dk8ObhSx7JMkWE7fVn0A86
BUCKET_NAME = "rag-codebase-14f3e890-f89c-4079-95f1-1dc4bd2105b7"

# Projects to index
PROJECTS_ROOT = "/mnt/hegemon-share/share/code"
TARGET_PROJECTS = [
    "GrpcService1",
    "Helpers.Core",
    "k8s-test-app",
    "kubernetes-setup",
    "kubernetes-server-build",
    "kubernetes-app-setup"
]

# File extensions to include
INCLUDED_EXTENSIONS = {'.cs', '.sh', '.yaml', '.yml', '.md', '.txt', '.proto', '.go', '.json'}
EXCLUDED_DIRS = {'bin', 'obj', '.git', 'node_modules', '__pycache__'}

def upload_projects():
    # Note: Using base64 decoded values for the client
    import base64
    ak = base64.b64decode(ACCESS_KEY).decode('utf-8')
    sk = base64.b64decode(SECRET_KEY).decode('utf-8')
    
    # We use the internal DNS but we are running in the VM.
    # We might need to use the external IP if the VM cannot resolve internal K8s DNS.
    # However, hierophant usually has access.
    
    s3 = boto3.client(
        's3',
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=ak,
        aws_secret_access_key=sk,
        region_name="us-east-1"
    )

    for project in TARGET_PROJECTS:
        project_path = os.path.join(PROJECTS_ROOT, project)
        if not os.path.exists(project_path):
            print(f"Skipping {project}: Path not found")
            continue
        
        print(f"Uploading project: {project}")
        for root, dirs, files in os.walk(project_path):
            # Prune excluded directories
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
            
            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in INCLUDED_EXTENSIONS:
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, PROJECTS_ROOT)
                    
                    try:
                        with open(full_path, 'rb') as f:
                            s3.put_object(Bucket=BUCKET_NAME, Key=rel_path, Body=f)
                        print(f"  Uploaded: {rel_path}")
                    except Exception as e:
                        print(f"  Error uploading {rel_path}: {e}")

if __name__ == "__main__":
    upload_projects()
