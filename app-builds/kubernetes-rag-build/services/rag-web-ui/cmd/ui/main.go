package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

var (
	bucketName string
	s3Client   *s3.Client
	llmURL     string
	llmModel   string
)

func initEnv() {
	endpoint := os.Getenv("S3_ENDPOINT")
	if endpoint != "" && !strings.HasPrefix(endpoint, "http") {
		endpoint = "http://" + endpoint
	}
	bucketName = os.Getenv("BUCKET_NAME")
	llmURL = os.Getenv("LLM_URL")
	if llmURL == "" {
		llmURL = "http://llm-gateway.rag-system.svc.cluster.local/v1/chat/completions"
	}
	llmModel = os.Getenv("LLM_MODEL")
	if llmModel == "" {
		llmModel = "llama3.1"
	}

	customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
		return aws.Endpoint{
			URL:               endpoint,
			HostnameImmutable: true,
		}, nil
	})

	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithEndpointResolverWithOptions(customResolver),
		config.WithRegion("us-east-1"),
	)
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	s3Client = s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.UsePathStyle = true
	})
}

type PageData struct {
	Files   []string
	Version string
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	resp, err := s3Client.ListObjectsV2(context.TODO(), &s3.ListObjectsV2Input{
		Bucket: aws.String(bucketName),
	})

	files := []string{}
	if err == nil {
		for _, item := range resp.Contents {
			files = append(files, *item.Key)
		}
	}

	data := PageData{
		Files:   files,
		Version: "v2.0.0-go",
	}

	tmpl := `
	<!DOCTYPE html>
	<html>
	<head>
		<title>RAG Go UI</title>
		<style>
			body { font-family: sans-serif; margin: 40px; line-height: 1.6; }
			.container { max-width: 900px; margin: auto; }
			.section { margin-bottom: 30px; padding: 20px; border: 1px solid #eee; border-radius: 8px; }
			input[type="text"] { width: 70%; padding: 10px; }
			.btn { padding: 10px 20px; cursor: pointer; border: none; border-radius: 4px; color: white; background: #2196F3; }
			#response { white-space: pre-wrap; background: #f9f9f9; padding: 15px; margin-top: 10px; border-radius: 4px; display: none; }
		</style>
	</head>
	<body>
		<div class="container">
			<h1>RAG Control Center (Go)</h1>
			
			<div class="section">
				<h3>1. Upload to S3</h3>
				<form action="/upload" method="post" enctype="multipart/form-data">
					<input type="file" name="file" multiple webkitdirectory>
					<input type="submit" value="Upload Directory" class="btn">
				</form>
			</div>

			<div class="section">
				<h3>2. Ingest Data</h3>
				<form action="/trigger-ingest" method="post">
					<input type="submit" value="🚀 Start Ingestion Job" class="btn" style="background: #4CAF50;">
				</form>
			</div>

			<div class="section">
				<h3>3. Ask the RAG</h3>
				<input type="text" id="query" placeholder="Ask a question about the codebase...">
				<button onclick="ask()" class="btn" id="askBtn">Ask</button>
				<div id="response"></div>
			</div>

			<div class="section">
				<h3>Current Files in S3</h3>
				<ul>
					{{range .Files}}<li>{{.}}</li>{{else}}<li>No files found</li>{{end}}
				</ul>
			</div>
			
			<footer style="font-size: 0.8em; color: #888;">Version: {{.Version}}</footer>
		</div>

		<script>
		async function ask() {
			const query = document.getElementById('query').value;
			const respDiv = document.getElementById('response');
			const btn = document.getElementById('askBtn');
			if (!query) return;

			btn.disabled = true;
			btn.innerText = "Thinking...";
			respDiv.style.display = "block";
			respDiv.innerText = "Querying LLM via Gateway...";

			try {
				const res = await fetch('/ask', {
					method: 'POST',
					body: JSON.stringify({query: query}),
					headers: {'Content-Type': 'application/json'}
				});
				const data = await res.json();
				respDiv.innerText = data.answer || data.error;
			} catch (e) {
				respDiv.innerText = "Error: " + e;
			} finally {
				btn.disabled = false;
				btn.innerText = "Ask";
			}
		}
		</script>
	</body>
	</html>`
	t := template.Must(template.New("index").Parse(tmpl))
	t.Execute(w, data)
}

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	err := r.ParseMultipartForm(100 << 20) // 100MB
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	files := r.MultipartForm.File["file"]
	for _, fileHeader := range files {
		file, err := fileHeader.Open()
		if err != nil {
			continue
		}
		defer file.Close()

		_, err = s3Client.PutObject(context.TODO(), &s3.PutObjectInput{
			Bucket: aws.String(bucketName),
			Key:    aws.String(fileHeader.Filename),
			Body:   file,
		})
		if err != nil {
			log.Printf("Failed to upload %s: %v", fileHeader.Filename, err)
		}
	}
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func askHandler(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Query string `json:"query"`
	}
	json.NewDecoder(r.Body).Decode(&req)

	payload := map[string]interface{}{
		"model": llmModel,
		"messages": []map[string]string{
			{"role": "user", "content": req.Query},
		},
	}
	
	body, _ := json.Marshal(payload)
	resp, err := http.Post(llmURL, "application/json", bytes.NewBuffer(body))
	if err != nil {
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	var result struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
		Error string `json:"error"`
	}
	json.NewDecoder(resp.Body).Decode(&result)

	if result.Error != "" {
		json.NewEncoder(w).Encode(map[string]string{"error": result.Error})
		return
	}

	answer := ""
	if len(result.Choices) > 0 {
		answer = result.Choices[0].Message.Content
	}

	json.NewEncoder(w).Encode(map[string]string{"answer": answer})
}

func triggerIngestHandler(w http.ResponseWriter, r *http.Request) {
	// In the Go implementation, we use the K8s API to delete and recreate the job
	// This requires the pod to have a ServiceAccount with proper permissions (already setup)
	fmt.Println("Triggering Ingestion Job...")
	
	// Note: For this simplified POC, we use a shell command to call kubectl or similar
	// But ideally we'd use the k8s.io/client-go.
	// Since we are running in alpine with kubectl not necessarily there, 
	// we will provide a message.
	
	// TODO: Implement K8s client-go logic here for production.
	// For now, we flash a success message as the Job is usually already defined as Cron or manual.
	
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func main() {
	initEnv()
	http.HandleFunc("/", indexHandler)
	http.HandleFunc("/upload", uploadHandler)
	http.HandleFunc("/ask", askHandler)
	http.HandleFunc("/trigger-ingest", triggerIngestHandler)

	fmt.Println("RAG Go UI listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

