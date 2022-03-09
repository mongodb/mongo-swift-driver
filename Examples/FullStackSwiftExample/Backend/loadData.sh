command -v mongosh > /dev/null || echo "Failed to locate mongosh; please follow instructions here to install it: https://docs.mongodb.com/mongodb-shell/install"; exit 1
mongosh $MONGODB_URI --eval "db.getSiblingDB('home').kittens.insertMany([{name:\"Roscoe\",color:\"orange\", favoriteFood: \"salmon\", lastUpdateTime: new Date()},{name:\"Chester\",color:\"tan\", favoriteFood: \"turkey\", lastUpdateTime: new Date()}]);"
