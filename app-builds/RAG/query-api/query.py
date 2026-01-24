import os
import json
import requests
from qdrant_client import QdrantClient
from sentence_transformers import SentenceTransformer

# Configuration
QDRANT_HOST = os.getenv("QDRANT_HOST", "qdrant.rag-system.svc.cluster.local")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", 6333))
COLLECTION_NAME = "codebase"

LLM_URL = os.getenv("LLM_URL", "http://ollama.llms-ollama.svc.cluster.local:11434/v1/chat/completions")

class RAGQuery:
    def __init__(self):
        self.qdrant = QdrantClient(host=QDRANT_HOST, port=QDRANT_PORT)
        self.model = SentenceTransformer('all-MiniLM-L6-v2')

    def search(self, query, limit=5):
        vector = self.model.encode(query).tolist()
        results = self.qdrant.search(
            collection_name=COLLECTION_NAME,
            query_vector=vector,
            limit=limit
        )
        return results

    def query(self, question):
        # 1. Search for context
        search_results = self.search(question)
        context = "\n---\n".join([r.payload['text'] for r in search_results])
        
        # 2. Build prompt
        prompt = f"""Use the following pieces of context to answer the user's question. 
If you don't know the answer, just say that you don't know, don't try to make up an answer.

Context:
{context}

Question: {question}

Answer:"""

        # 3. Call Ollama (OpenAI compatible endpoint)
        payload = {
            "model": "llama3.1",
            "messages": [
                {"role": "system", "content": "You are a helpful assistant that answers questions based on the provided codebase context."},
                {"role": "user", "content": prompt}
            ],
            "max_tokens": 512,
            "temperature": 0.1
        }
        
        try:
            response = requests.post(LLM_URL, json=payload, timeout=60)
            response.raise_for_status()
            return response.json()['choices'][0]['message']['content'], search_results
        except Exception as e:
            return f"Error calling LLM: {str(e)}", search_results

if __name__ == "__main__":
    rag = RAGQuery()
    q = "How do I deploy Qdrant?"
    ans, sources = rag.query(q)
    print(f"Question: {q}")
    print(f"Answer: {ans}")
    print("\nSources:")
    for s in sources:
        print(f"- {s.payload['path']} (score: {s.score:.4f})")
