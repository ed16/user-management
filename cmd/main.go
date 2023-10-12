package main

import (
	"context"
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type User struct {
	UserID string
	Name   string
}

type UserMongoDB struct {
	ObjectID primitive.ObjectID `bson:"_id,omitempty" json:"objectid,omitempty"`
	UserID   string             `bson:"userid,omitempty" json:"userid,omitempty"`
	Name     string             `bson:"name,omitempty" json:"name,omitempty"`
}

var (
	users  = make(map[string]User)
	usersM sync.RWMutex
)

var client *mongo.Client

func main() {
	var err error
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	client, err = mongo.Connect(ctx, options.Client().ApplyURI("mongodb://localhost:27017"))
	if err != nil {
		panic(err)
	}

	router := mux.NewRouter()
	router.HandleFunc("/users", createUser).Methods("POST")
	router.HandleFunc("/users/{id}", getUser).Methods("GET")

	http.ListenAndServe(":8080", router)
}

func createUser(w http.ResponseWriter, r *http.Request) {
	var user User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	usersM.Lock()
	users[user.UserID] = user
	usersM.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

func getUser(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)

	usersM.RLock()
	user, ok := users[params["id"]]
	usersM.RUnlock()

	if !ok {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

func createUserMongo(w http.ResponseWriter, r *http.Request) {
	var user User
	var userMongoDB UserMongoDB
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	collection := client.Database("user_management_service").Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	userMongoDB.ObjectID = primitive.NewObjectID()
	userMongoDB.UserID = user.UserID
	userMongoDB.Name = user.Name
	_, err := collection.InsertOne(ctx, userMongoDB)
	if err != nil {
		http.Error(w, "Could not create user", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

func getUserMongo(w http.ResponseWriter, r *http.Request) {
	params := mux.Vars(r)
	userID := params["id"]

	var user UserMongoDB
	collection := client.Database("user_management_service").Collection("users")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	err := collection.FindOne(ctx, UserMongoDB{UserID: userID}).Decode(&user)

	if err != nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}
