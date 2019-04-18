#!/bin/bash
mongo home --eval "db.kittens.insert([{\"name\":\"roscoe\",\"color\":\"orange\"},{\"name\":\"chester\",\"color\":\"tan\"}])"


