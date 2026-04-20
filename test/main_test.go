package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHomeHandler(t *testing.T) {
	req := httptest.NewRequest("GET", "/", nil)
	rr := httptest.NewRecorder()
	
	homeHandler(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}
	
	expected := "Hello from GitOps CI/CD Demo App!"
	if rr.Body.String()[:len(expected)] != expected {
		t.Errorf("handler returned unexpected body: got %v", rr.Body.String())
	}
}

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest("GET", "/health", nil)
	rr := httptest.NewRecorder()
	
	healthHandler(rr, req)
	
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
	}
	
	if rr.Body.String() != "OK" {
		t.Errorf("handler returned unexpected body: got %v want %v", rr.Body.String(), "OK")
	}
}
