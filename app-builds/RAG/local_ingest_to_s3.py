import boto3
import os
import sys
import threading

# S3 Configuration for Rook-Ceph
S3_ENDPOINT = "http://172.20.1.25"
ACCESS_KEY = "D00E5GBI7AE7BQ6T2ZH9"
SECRET_KEY = "00CbXwxUyYDbYdst21dk8ObhSx7JMkWE7fWn0A86"
BUCKET_NAME = "rag-codebase-14f3e890-f89c-4079-95f1-1dc4bd2105b7"

PROJECTS_ROOT = "/mnt/hegemon-share/code"
TARGET_PROJECTS = [
    "opentelemetry-dotnet-contrib",
    "TrafficSimulation",
    "yaml-handler",
    "kubernetes-app-setup",
    "kubernetes-server-build",
    "kubernetes-setup"
]

INCLUDED_EXTENSIONS = {'.cs', '.sh', '.yaml', '.yml', '.md', '.txt', '.proto', '.go', '.json'}
EXCLUDED_DIRS = {'bin', 'obj', '.git', 'node_modules', '__pycache__', '.idea', '.vscode'}

class ProgressPercentage(object):
    def __init__(self, filename):
        self._filename = filename
        self._size = float(os.path.getsize(filename))
        self._seen_so_far = 0
        self._lock = threading.Lock()

    def __call__(self, bytes_amount):
        with self._lock:
            self._seen_so_far += bytes_amount
            percentage = (self._seen_so_far / self._size) * 100
            sys.stdout.write(
                "\r%s  %s / %s  (%.2f%%)" % (
                    self._filename, self._seen_so_far, self._size,
                    percentage))
            sys.stdout.flush()

def upload_projects():
    print(f"Connecting to S3 at {S3_ENDPOINT}...")
    s3 = boto3.client(
        's3',
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        region_name="us-east-1"
    )

    # Get existing objects to skip duplicates
    print("Fetching existing objects from S3...")
    existing_files = {}
    try:
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=BUCKET_NAME):
            for obj in page.get('Contents', []):
                existing_files[obj['Key']] = obj['Size']
        print(f"Found {len(existing_files)} existing objects.")
    except Exception as e:
        print(f"Warning: Could not list existing objects: {e}")

    for project in TARGET_PROJECTS:
        project_path = os.path.join(PROJECTS_ROOT, project)
        if not os.path.exists(project_path):
            print(f"\nSkipping {project}: Path {project_path} not found")
            continue
        
        print(f"\n--- Processing project: {project} ---")
        count = 0
        skipped = 0
        for root, dirs, files in os.walk(project_path):
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
            
            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in INCLUDED_EXTENSIONS:
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, PROJECTS_ROOT)
                    file_size = os.path.getsize(full_path)

                    if rel_path in existing_files and existing_files[rel_path] == file_size:
                        skipped += 1
                        continue

                    try:
                        print(f"\n[UPLOAD] {rel_path}")
                        progress = ProgressPercentage(full_path)
                        s3.upload_file(
                            full_path, BUCKET_NAME, rel_path,
                            Callback=progress
                        )
                        count += 1
                    except Exception as e:
                        print(f"\n  Error uploading {rel_path}: {e}")
        
        print(f"\nFinished {project}: {count} files uploaded, {skipped} skipped.")

if __name__ == "__main__":
    upload_projects()
