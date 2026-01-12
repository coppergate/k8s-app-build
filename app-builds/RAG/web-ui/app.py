import os
import boto3
from flask import Flask, render_template, request, redirect, url_for, flash
from botocore.client import Config
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "supersecretkey")

# S3 Configuration
S3_ENDPOINT = os.getenv("S3_ENDPOINT")
S3_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
S3_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
BUCKET_NAME = os.getenv("BUCKET_NAME")

def get_s3_client():
    return boto3.client(
        's3',
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=S3_ACCESS_KEY,
        aws_secret_access_key=S3_SECRET_KEY,
        config=Config(signature_version='s3v4'),
        region_name='us-east-1'
    )

@app.route('/')
def index():
    s3 = get_s3_client()
    try:
        response = s3.list_objects_v2(Bucket=BUCKET_NAME)
        files = []
        if 'Contents' in response:
            for obj in response['Contents']:
                files.append(obj['Key'])
        
        VERSION = "v1.0.1"
        BUILD_DATE = "2026-01-12"
        
        return f"""
        <html>
            <head>
                <title>RAG Object Store UI</title>
                <style>
                    footer {{ margin-top: 50px; font-size: 0.8em; color: #888; border-top: 1px solid #eee; padding-top: 10px; }}
                </style>
            </head>
            <body>
                <h1>RAG Object Store - File Upload</h1>
                <form action="/upload" method="post" enctype="multipart/form-data">
                    <div style="margin-bottom: 10px;">
                        <input type="file" name="file" id="directoryInput" multiple webkitdirectory directory mozdirectory>
                    </div>
                    <div id="fileStatus" style="margin-bottom: 10px; color: #666;">No directory selected</div>
                    <input type="submit" value="Upload Directory" id="uploadBtn" disabled>
                </form>

                <script>
                document.getElementById('directoryInput').addEventListener('change', function(e) {{
                    const files = e.target.files;
                    const status = document.getElementById('fileStatus');
                    const btn = document.getElementById('uploadBtn');
                    
                    console.log("File input changed. Number of files:", files.length);
                    
                    if (files.length > 0) {{
                        const firstPath = files[0].webkitRelativePath;
                        console.log("First file path:", firstPath);
                        const folderName = firstPath ? firstPath.split('/')[0] : "Selected Files";
                        status.innerText = "Selected: " + folderName + " (" + files.length + " files ready to upload)";
                        status.style.color = "green";
                        status.style.fontWeight = "bold";
                        btn.disabled = false;
                    }} else {{
                        status.innerText = "No directory selected";
                        status.style.color = "#666";
                        status.style.fontWeight = "normal";
                        btn.disabled = true;
                    }}
                }});
                </script>
                <hr>
                <h2>Current Files in S3</h2>
                <ul>
                    {"".join([f"<li>{f}</li>" for f in files])}
                </ul>
                <footer>
                    Version: {VERSION} | Build Date: {BUILD_DATE}
                </footer>
            </body>
        </html>
        """
    except Exception as e:
        return f"Error: {str(e)}"

@app.route('/upload', methods=['POST'])
def upload():
    if 'file' not in request.files:
        return redirect(request.url)
    
    files = request.files.getlist('file')
    s3 = get_s3_client()
    
    uploaded_count = 0
    for file in files:
        if file.filename == '':
            continue
        
        try:
            # S3 doesn't really have "directories", it just uses prefixes
            s3_key = file.filename
            s3.upload_fileobj(file, BUCKET_NAME, s3_key)
            uploaded_count += 1
        except Exception as e:
            print(f"Failed to upload {file.filename}: {e}")

    return f"Successfully uploaded {uploaded_count} files to S3. <a href='/'>Go back</a>"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
