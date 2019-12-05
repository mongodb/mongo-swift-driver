require 'xcodeproj'

project = Xcodeproj::Project.open('MongoSwift.xcodeproj')
targets = project.native_targets

# make a file reference for the provided project with file at dirPath (relative)
def make_reference(project, path)
    fileRef = project.new(Xcodeproj::Project::Object::PBXFileReference)
    fileRef.path = path
    return fileRef
end

mongoswift_tests_target = targets.find { |t| t.uuid == "MongoSwift::MongoSwiftTests" }
crud = make_reference(project, "./Tests/Specs/crud")
cm = make_reference(project, "./Tests/Specs/command-monitoring")
read_write_concern = make_reference(project, "./Tests/Specs/read-write-concern")
retryable_writes = make_reference(project, "./Tests/Specs/retryable-writes")
retryable_reads = make_reference(project, "./Tests/Specs/retryable-reads")
change_streams = make_reference(project, "./Tests/Specs/change-streams")
dns_seedlist = make_reference(project, "./Tests/Specs/initial-dns-seedlist-discovery")
auth = make_reference(project, "./Tests/Specs/auth")
mongoswift_tests_target.add_resources([crud, cm, read_write_concern, retryable_writes, retryable_reads, change_streams, dns_seedlist, auth])

bson_tests_target = targets.find { |t| t.uuid == "MongoSwift::BSONTests" }
corpus = make_reference(project, "./Tests/Specs/bson-corpus")
bson_tests_target.add_resources([corpus])

project.save
