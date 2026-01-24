### Executive Summary: Production-Grade Event-Driven RAG Architecture

This project implements a high-performance, scalable **Retrieval-Augmented Generation (RAG)** system designed for local deployment within a Kubernetes environment. The architecture transitions from a traditional synchronous model to a robust **event-driven system** using **Apache Pulsar**, ensuring resilience and efficient resource utilization of local GPU assets.

#### 1. Technical Architecture & Components

The system is built on a modular "micro-services" foundation, utilizing the strengths of both **Go** for high-concurrency plumbing and **Python** for machine learning tasks.

*   **LLM Gateway (Go)**: A high-concurrency entry point that provides an **OpenAI-compatible API**. It decouples the user-facing interface from the back-end processing by publishing tasks to the Pulsar bus and managing request state using a `correlation_id` pattern.
*   **Apache Pulsar Orchestrator**: Acts as the central nervous system. It provides asynchronous task distribution, backpressure management (protecting GPUs from overload), and guaranteed message delivery for long-running inference tasks.
*   **RAG Worker (Go)**: The primary orchestrator of the RAG logic. It consumes tasks from Pulsar, coordinates with **Ollama** for vector embeddings (4096-d), performs semantic searches in **Qdrant**, and manages the final prompt augmentation before calling the LLM.
*   **Vector Database (Qdrant)**: High-performance vector store hosting code-chunk embeddings generated via the `all-MiniLM-L6-v2` model.
*   **Session & Timeline Store (TimescaleDB)**: A time-series optimized PostgreSQL database used to track multi-turn chat history, projects, and sessions. It utilizes **Hypertables** for efficient data retention and compression policies.
*   **Local Object Store (Rook-Ceph S3)**: A pure S3-native flow where the codebase is ingested directly from local buckets, eliminating host-path dependencies and ensuring portability.

#### 2. Key Technical Specifications

| Feature | Specification | Benefit |
| --- | --- | --- |
| Messaging | Apache Pulsar | Asynchronous coordination, horizontal scalability, and retry logic. |
| Logic (Plumbing) | Go 1.24 (Concurrent) | Instant startup, minimal memory footprint, and superior goroutine efficiency. |
| Logic (ML) | Python 3.9 / LlamaIndex | Access to best-in-class embedding and parsing libraries. |
| Database | TimescaleDB (PostgreSQL) | Automated data lifecycle management (Hot/Warm/Cold archiving). |
| Inference | Ollama (Llama 3.1) | Localized, privacy-first LLM execution with GPU acceleration. |
| Infrastructure | Kubernetes (Talos) | Declarative deployment, self-healing pods, and resource isolation. |

#### 3. Operational Highlights

*   **"Heat" Management Strategy**: Leveraging TimescaleDB's retention policies, the system automatically manages chat history "heat." Recent messages (Hot) are kept in high-performance storage, while older messages (Warm/Cold) are compressed or archived, balancing performance with long-term storage costs.
*   **GPU Optimization**: By using a Pulsar-backed gateway, the system can queue requests when the local GPUs are at capacity, preventing timeout failures and ensuring every compute cycle is utilized efficiently.
*   **Deterministic Testing**: Includes a specialized testing suite that runs "Heat 0" (Temperature 0) queries to verify that the LLM is accurately utilizing the injected context from the vector store, ensuring reliability in technical responses.
*   **Modular Extensibility**: The Gateway and Worker implementations are designed as standalone Go modules, allowing for easy swapping of the underlying LLM (e.g., from Ollama to vLLM) or the vector store without re-architecting the entire system.

#### 4. Conclusion

This implementation represents a transition from "scripts" to a "distributed system." By combining the performance of Go, the flexibility of Pulsar, and the power of TimescaleDB, we have created a RAG framework capable of supporting continuing development efforts over extended timeframes while remaining highly responsive to live user queries.
