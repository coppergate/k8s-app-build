import io
from flask import Flask, request

app = Flask(__name__)

@app.route('/upload', methods=['POST'])
def upload():
    files = request.files.getlist('file')
    result = []
    for file in files:
        result.append(file.filename)
    return {"filenames": result}

if __name__ == '__main__':
    with app.test_client() as client:
        # Simulate a directory upload by providing filenames with paths
        # Note: In a real browser with webkitdirectory, the 'filename' in the multipart 
        # header might contain the relative path.
        data = {
            'file': [
                (io.BytesIO(b"content1"), 'dir1/file1.txt'),
                (io.BytesIO(b"content2"), 'dir1/subdir/file2.txt'),
            ]
        }
        response = client.post('/upload', data=data, content_type='multipart/form-data')
        print(response.json)
