import os
import glob
from qdrant_client import QdrantClient
from qdrant_client.http import models
from sentence_transformers import SentenceTransformer

# Configuration
QDRANT_HOST = os.getenv("QDRANT_HOST", "qdrant.default.svc.cluster.local")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", 6333))
COLLECTION_NAME = "codebase"
DATA_PATH = "/mnt/codebase"
CHUNK_SIZE = 1000

# Allowed extensions
ALLOWED_EXTENSIONS = os.getenv("ALLOWED_EXTENSIONS", ".md,.sh,.yaml,.yml,.py,.txt,.c,.h,.cpp,.hpp,.cs,.json").split(",")

def get_files():
    files = []
    extensions = [f"*{ext}" for ext in ALLOWED_EXTENSIONS]
    for ext in extensions:
        files.extend(glob.glob(os.path.join(DATA_PATH, "**", ext), recursive=True))
    return files

def chunk_text(text, size):
    return [text[i:i + size] for i in range(0, len(text), size)]

def ingest():
    client = QdrantClient(host=QDRANT_HOST, port=QDRANT_PORT)
    model = SentenceTransformer('all-MiniLM-L6-v2')

    # Create collection if not exists
    collections = client.get_collections().collections
    exists = any(c.name == COLLECTION_NAME for c in collections)
    
    if not exists:
        client.recreate_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=models.VectorParams(size=384, distance=models.Distance.COSINE),
        )
        print(f"Created collection: {COLLECTION_NAME}")

    files = get_files()
    print(f"Found {len(files)} files to ingest.")

    points = []
    idx = 0
    for file_path in files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                chunks = chunk_text(content, CHUNK_SIZE)
                
                for i, chunk in enumerate(chunks):
                    vector = model.encode(chunk).tolist()
                    points.append(models.PointStruct(
                        id=idx,
                        vector=vector,
                        payload={
                            "path": file_path.replace(DATA_PATH, ""),
                            "chunk": i,
                            "text": chunk
                        }
                    ))
                    idx += 1
                    
                    if len(points) >= 100:
                        client.upsert(collection_name=COLLECTION_NAME, points=points)
                        points = []
                        print(f"Ingested {idx} chunks...")
        except Exception as e:
            print(f"Error reading {file_path}: {e}")

    if points:
        client.upsert(collection_name=COLLECTION_NAME, points=points)
    
    print(f"Finished! Ingested total {idx} chunks.")

if __name__ == "__main__":
    ingest()
