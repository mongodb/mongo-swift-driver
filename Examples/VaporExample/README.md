# VaporExample

This is a minimal working example of using the driver in a Vapor application.

**Note**: Since the driver depends on SwiftNIO 2 as of the 1.0.0-rc0 release, it is only compatible with Vapor 4. 

To test it out, do the following:
1. Run `mongod` to start MongoDB running on `localhost:27017`.
1. Navigate to the `Examples/` directory (one level up from this one.)
1. Run `../loadExampleData.sh` to load sample data into the database.
1. Navigate to the root directory of this example.
1. Run `swift run`.
1. Navigate to `localhost:8080/kittens` to see the example data loaded on the web page.
