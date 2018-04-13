require 'xcodeproj'

project = Xcodeproj::Project.open('MongoSwift.xcodeproj')
targets = project.native_targets

# make a file reference for the provided project with file at dirPath (relative)
def make_reference(project, path)
	fileRef = project.new(Xcodeproj::Project::Object::PBXFileReference)
	fileRef.path = path
	return fileRef
end

benchmark_target = targets.find { |t| t.uuid == "MongoSwift::MongoSwiftBenchmarks" }
benchmarks = make_reference(project, "./Tests/Specs/benchmarking")
benchmark_target.add_resources([benchmarks])

tests_target = targets.find { |t| t.uuid == "MongoSwift::MongoSwiftTests" }
crud = make_reference(project, "./Tests/Specs/crud")
cm = make_reference(project, "./Tests/Specs/command-monitoring")
corpus = make_reference(project, "./Tests/Specs/bson-corpus")
tests_target.add_resources([crud, cm, corpus])

project.save
