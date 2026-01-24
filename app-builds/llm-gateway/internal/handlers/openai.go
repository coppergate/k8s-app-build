package handlers

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"app-builds/llm-gateway/internal/pulsar"
	"github.com/google/uuid"
)

type OpenAIHandler struct {
	Pulsar *pulsar.PulsarClient
	DB     *sql.DB
}

type ChatCompletionRequest struct {
	Model     string `json:"model"`
	SessionID string `json:"session_id,omitempty"` // Added for session tracking
	Messages  []struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"messages"`
}

func (h *OpenAIHandler) HandleChatCompletions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ChatCompletionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}

	// 1. Session tracking
	sessionID := req.SessionID
	if sessionID == "" {
		sessionID = uuid.New().String()
	}

	// Ensure session exists in the database
	_, err := h.DB.Exec("INSERT INTO chat_sessions (id, title) VALUES ($1, $2) ON CONFLICT (id) DO NOTHING",
		sessionID, "Chat Session "+sessionID[:8])
	if err != nil {
		log.Printf("Failed to ensure session exists: %v", err)
	}

	// Save user message to DB
	if len(req.Messages) > 0 {
		userMsg := req.Messages[len(req.Messages)-1].Content
		_, err := h.DB.Exec("INSERT INTO chat_messages (session_id, role, content) VALUES ($1, $2, $3)",
			sessionID, "user", userMsg)
		if err != nil {
			log.Printf("Failed to log user message: %v", err)
		}
	}

	correlationID := uuid.New().String()

	// Wrap the request for Pulsar
	pulsarPayload := map[string]interface{}{
		"id":         correlationID,
		"session_id": sessionID,
		"type":       "chat_completion",
		"payload":    req,
		"timestamp":  time.Now().Format(time.RFC3339),
	}

	result, err := h.Pulsar.SendRequest(r.Context(), correlationID, pulsarPayload)
	if err != nil {
		http.Error(w, "Service unavailable: "+err.Error(), http.StatusServiceUnavailable)
		return
	}

	// Save assistant response to DB
	_, err = h.DB.Exec("INSERT INTO chat_messages (session_id, role, content) VALUES ($1, $2, $3)",
		sessionID, "assistant", result)
	if err != nil {
		log.Printf("Failed to log assistant response: %v", err)
	}

	// For simplicity, we assume 'result' is already the raw content or a JSON we can proxy
	w.Header().Set("Content-Type", "application/json")

	// Minimal OpenAI-like response
	response := map[string]interface{}{
		"id":         "chatcmpl-" + correlationID,
		"object":     "chat.completion",
		"created":    time.Now().Unix(),
		"model":      req.Model,
		"session_id": sessionID,
		"choices": []map[string]interface{}{
			{
				"index": 0,
				"message": map[string]string{
					"role":    "assistant",
					"content": result,
				},
				"finish_reason": "stop",
			},
		},
	}
	json.NewEncoder(w).Encode(response)
}
