mongo home --eval "db.kittens.insert([{\"name\":\"Roscoe\",\"color\":\"orange\", \"favoriteFood\": \"salmon\"},{\"name\":\"Chester\",\"color\":\"tan\", \"favoriteFood\": \"turkey\"}])"
mongo home --eval "db.kittens.createIndex({\"name\": 1}, {\"unique\": true})"
