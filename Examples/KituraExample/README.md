# KituraExample

This is a minimal working example of using the driver in a Kitura application.

To test it out, do the following:
1. Run `mongod` to start MongoDB running on `localhost:27017`.
1. Navigate to the `Examples/` directory (one level up from this one.)
1. Run `../loadExampleData.sh` to load sample data into the database.
1. Navigate to the root directory of this example.
1. Build with `export KITURA_NIO=1 && swift build` to enable using SwiftNIO for the networking layer.
1. Start the server with `swift run`.
1. Navigate to `localhost:8080/kittens` to see the example data loaded on the web page.
