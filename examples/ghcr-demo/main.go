package main

import (
 "encoding/json"
 "log"
 "net/http"
 "os"
 "time"
)

func main() {
 mux := http.NewServeMux()
 mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
  w.Header().Set("Content-Type", "application/json")
  _ = json.NewEncoder(w).Encode(map[string]string{"service":"m3-devops-ghcr-demo","status":"running"})
 })
 mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK); _, _ = w.Write([]byte("ok\n")) })
 mux.HandleFunc("GET /ready", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK); _, _ = w.Write([]byte("ready\n")) })
 port := os.Getenv("PORT"); if port == "" { port = "8080" }
 server := &http.Server{Addr:":"+port,Handler:mux,ReadHeaderTimeout:5*time.Second}
 log.Printf("Listening on :%s",port)
 log.Fatal(server.ListenAndServe())
}
