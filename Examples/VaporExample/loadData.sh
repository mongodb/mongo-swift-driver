mongo home --eval "db.kittens.insert([{name:\"Roscoe\",color:\"orange\", favoriteFood: \"salmon\", lastUpdateTime: new Date()},{name:\"Chester\",color:\"tan\", favoriteFood: \"turkey\", lastUpdateTime: new Date()}])"
mongo home --eval "db.kittens.createIndex({name: 1}, {unique: true})"
