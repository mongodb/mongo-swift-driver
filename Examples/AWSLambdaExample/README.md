# AWSLambdaExample

This is a minimal working example of using the driver in AWS Lambda. 

## Building the example
The example code needs to be compiled for Amazon Linux 2 to be run in AWS Lambda.
You can use [Docker](https://docs.docker.com/desktop/) to achieve this.

First, run the following command to build a Docker image using the [`Dockerfile`](Dockerfile) in
this directory:
```
docker build -t swift-lambda .
```
This will install the dependencies necessary to build the driver on Linux.

Note that the `Dockerfile` uses Swift 5.6, the latest version at the time of writing. If you'd like
to use a different version, visit [DockerHub](https://hub.docker.com/_/swift) for a full list of
Swift Docker images.

Next, use the image you created to compile the example:
```
$ docker run \
    --rm \
    --volume "$(pwd)/:/src" \
    --workdir "/src/" \
    swift-lambda \
    swift build --product AWSLambdaExample -c release -Xswiftc -static-stdlib
```

Finally, run the [`package.sh`](package.sh) script in this directory to create a symlink called
`bootstrap` and zip the folder:
```
./package.sh AWSLambdaExample
```
Navigate to the Code section on the page for your AWS Lambda function in the AWS Console and upload
the `lambda.zip` file created.

## Acknowledgements
The instructions for using Docker to build the example were largely taken from
[this blog post](https://fabianfett.dev/getting-started-with-swift-aws-lambda-runtime) by
Fabian Fett. Feel free to read through the post for more detailed information on the Docker
commands used.

The `package.sh` script is copied from
[this example](https://github.com/swift-server/swift-aws-lambda-runtime/blob/main/Examples/Deployment/scripts/package.sh)
in the `swift-aws-lambda-runtime` repository.
