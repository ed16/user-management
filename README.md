# user-management

How to test the app:

Create user:
curl -H "Content-Type: application/json" -X POST -d '{"UserID":"1","name":"Bob"}' http://localhost:8080/users

Get user:
curl http://localhost:8080/users/1